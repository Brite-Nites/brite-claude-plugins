"""Deterministic core for the salesforce-preload skill (BC-17213).

The skill (SKILL.md) drives the live Salesforce reads/writes and the operator
turns. THIS module is the pure, stdlib-only, testable logic underneath it — the
decisions that must be exactly right every time and would be dangerous to leave
to prose:

  - resolve_website  — what goes in Account.Website, and the hard guarantee it
    is NEVER a free-email domain
  - resolve_name     — the Contact name, with company-in-LastName when there is
    no person and NEVER a placeholder
  - company_match_key — the conservative key for "does this business already
    have an Account?" (never strips suffixes; favors a duplicate over a merge)
  - classify_rows    — the integration step: buckets each lead (net-new /
    matched / matched-seed / multiple / needs-review), derives the surviving EB
    set and the review sidecar, and holds unrepresentable rows out of BOTH SF and
    the campaign

Nothing here touches the network or the filesystem; the skill feeds it values
and acts on what it returns.
"""

from __future__ import annotations

import re
from collections import Counter
from typing import Dict, List, Mapping, NamedTuple, Optional, Sequence

# Salesforce standard-field length caps — truncate defensively so an over-long
# value can never fail the write.
_FIRST_NAME_MAX = 40
_LAST_NAME_MAX = 80

# --- free-email domains ------------------------------------------------------
#
# The one non-negotiable rule of this module: a free-email domain must NEVER
# become an Account website. Writing `gmail.com` as a website is BOTH the
# original OutboundSync failure this whole skill exists to prevent AND a trip of
# the `AccountTriggerHandler` free-email guard (which would roll the insert back).
#
# This set MUST stay a SUPERSET of Salesforce's own guard list
# (`FreeEmailDomains.cls`, 15 entries) — if it ever misses a domain the guard
# rejects, a row would sail past here and then fail at insert. It is the union
# of that guard list and `/marketing:launch-campaign`'s own free-mail list, so
# it is a superset by construction. (The data platform maintains a broader
# 93-domain seed; consolidating all of these into one shared source is future
# cleanup, tracked with the suppression-consolidation work.)
FREE_EMAIL_DOMAINS = frozenset({
    # FreeEmailDomains.cls (the Salesforce guard — the authority we must not trip)
    "gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "aol.com",
    "icloud.com", "me.com", "protonmail.com", "mail.com", "ymail.com",
    "live.com", "msn.com", "comcast.net", "att.net", "verizon.net",
    # launch-campaign's additions
    "googlemail.com", "mac.com",
})

# Strip a leading scheme (http://, https://, mailto:) and a leading www.
_SCHEME_RE = re.compile(r"^(?:https?://|mailto:)", re.IGNORECASE)
_WWW_RE = re.compile(r"^www\.", re.IGNORECASE)


def resolve_website(domain_value: Optional[str]) -> Optional[str]:
    """Return a clean Account website for a lead, or None when there is no safe one.

    Takes the lead's mapped domain/website value and returns a bare, lowercased
    domain suitable for `Account.Website` — or `None` (leave the website blank)
    when the value is missing or resolves to a free-email domain.

    Two guarantees, both load-bearing:

    - **Never returns a free-email domain.** `gmail.com`, `www.gmail.com`, and
      `joe@gmail.com` all resolve to `None`. This is the guarantee that keeps the
      loader from recreating the original failure or tripping the SF guard.
    - **Never derives a website from an email address in a dangerous way.** If
      the value is pasted as an email (`joe@acme.com`), the domain part is taken
      — but it still passes through the free-email check, so a corporate address
      yields the real company domain (`acme.com`) while a free address is
      rejected. Deriving the *company* domain is correct (it is what OutboundSync
      does right on the commercial side); deriving from a *free* address is the
      bug, and the free-email check is exactly what separates the two.

    A `None` return is not an error — it means "no website for this Account", and
    the caller falls back to a phone as the contact method (or, with neither,
    routes the row to needs-review).
    """
    if not domain_value:
        return None

    value = domain_value.strip().lower()
    value = _SCHEME_RE.sub("", value)

    # A pasted email → take the domain part. The free-email check below is what
    # makes this safe: joe@acme.com → acme.com (kept); joe@gmail.com → gmail.com
    # (rejected). Deriving the company domain is fine; deriving from free-mail
    # is the failure, and it is caught, not created.
    if "@" in value:
        value = value.rsplit("@", 1)[1]

    value = _WWW_RE.sub("", value)
    value = value.split("/", 1)[0]      # drop any path
    value = value.split("?", 1)[0]      # drop any query
    value = value.split("#", 1)[0]      # drop a bare #fragment (no leading slash)
    value = value.split(":", 1)[0]      # drop a :port (scheme was already stripped)
    value = value.strip().strip(".")    # tidy stray leading/trailing dots

    if not value:
        return None
    if value in FREE_EMAIL_DOMAINS:
        return None
    return value


# --- name convention ---------------------------------------------------------
#
# Salesforce requires a LastName; FirstName is optional. The convention (Q6):
# use a real first/last name when there is one; otherwise put the COMPANY in the
# required LastName with a blank FirstName (which reads as "a business inbox, no
# person yet"). NEVER write a placeholder like `-`, `Unknown`, or `last_name` —
# that placeholder pollution is exactly what this convention exists to end.
#
# This helper only decides the NAME. Whether a row with no company should be
# held back is the disposition classifier's job (a later step) — so a real
# person with no company still gets a valid person name here; it is the
# classifier that routes the no-company row to needs-review.

#: Values that are not real names — treated as absent. Compared lowercased.
_JUNK_NAMES = frozenset({
    "", "-", "--", "---", ".", "n/a", "na", "none", "null", "nil",
    "unknown", "unknown prospect", "no name", "noname",
    "first_name", "firstname", "first name",
    "last_name", "lastname", "last name",
})


class NameDecision(NamedTuple):
    """The name to write on a Contact.

    - `is_person=True`  → a real person: `last_name` is a genuine surname,
      `first_name` may be blank or real.
    - `is_person=False` → no usable person: `first_name` is blank and
      `last_name` is the company (or blank only when there is no company at all,
      which the disposition classifier routes to needs-review).

    `last_name` is never a placeholder and never junk.
    """

    first_name: str
    last_name: str
    is_person: bool


def _clean(value: Optional[str]) -> str:
    return (value or "").strip()


def _is_junk_name(value: str, company: str) -> bool:
    """A name value is junk if it is a known placeholder or just the company.

    The "equals the company" case matters: OutboundSync and the old upload
    script stuff the company into the name field, so a `last_name` that equals
    the company is not a real surname — it is the company wearing a person's
    slot, and must fall through to the company path (blank first, company last).
    """
    low = value.strip().lower()
    return low in _JUNK_NAMES or (bool(company) and low == company.strip().lower())


def resolve_name(
    first: Optional[str],
    last: Optional[str],
    full: Optional[str],
    company: Optional[str],
) -> NameDecision:
    """Decide the Contact name from a lead's mapped fields.

    Order: a real first/last (junk blanked out); else split a full name that has
    a surname; else the company in LastName with a blank FirstName. The result's
    `last_name` is always either a real surname, the company, or blank — never a
    placeholder.
    """
    company_c = _clean(company)
    # A junk company (a header token like "last_name", or a placeholder like
    # "Unknown") is not a real business — blank it so it can never land in the
    # required LastName. The classifier holds such rows for review; blanking here
    # keeps this function's "never a placeholder" guarantee true even in isolation.
    if company_c.lower() in _JUNK_NAMES:
        company_c = ""

    first_c = _clean(first)
    last_c = _clean(last)
    if _is_junk_name(first_c, company_c):
        first_c = ""
    if _is_junk_name(last_c, company_c):
        last_c = ""

    # No usable surname yet, but a full name might carry one.
    if not last_c and full:
        full_c = _clean(full)
        if not _is_junk_name(full_c, company_c):
            parts = full_c.split(None, 1)  # "Mary Jane Watson" -> ["Mary", "Jane Watson"]
            if len(parts) >= 2:
                first_c = first_c or parts[0]
                last_c = parts[1]

    if last_c:  # a usable surname → a real person
        return NameDecision(
            first_name=first_c[:_FIRST_NAME_MAX],
            last_name=last_c[:_LAST_NAME_MAX],
            is_person=True,
        )

    # No usable person → the company goes in the required LastName, blank first.
    return NameDecision(first_name="", last_name=company_c[:_LAST_NAME_MAX], is_person=False)


# --- company match key -------------------------------------------------------
#
# The key used to decide "does this business already have an Account?". It is
# deliberately the LEAST aggressive normalization that still bridges pure noise:
# lowercase + collapse whitespace + trim. It does NOT strip legal suffixes and
# does NOT remove punctuation. Two consequences, both intended:
#
#   - `Acme Inc` and `Acme LLC` get DIFFERENT keys → they are treated as
#     different companies. Good: the legal form can be the only thing separating
#     two real entities, and the settled rule is favor-a-duplicate-over-a-wrong-
#     merge — so when a token differs we do NOT match.
#   - `Acme, Inc.` and `Acme Inc` also get different keys (the comma) → a
#     duplicate, not a merge. That is the accepted trade: a stray duplicate is
#     cheap and remediable; a wrong merge reparents children irreversibly.
#
# This mirrors how the org itself behaves — its NameAddressNormalizer collapses
# whitespace and never re-cases, and its fuzzy dup rule is set to Allow, so the
# org already tolerates suffix/punctuation-variant Accounts as distinct. The key
# is applied to BOTH sides (the lead's company and each candidate Account.Name)
# and matched by equality; it is never written to an Account.

_WHITESPACE_RE = re.compile(r"\s+")


def company_match_key(name: Optional[str]) -> str:
    """Normalize a company name to its match key: lowercase, single-spaced, trimmed.

    Returns "" for a missing/blank name (an empty key never matches a real
    Account — a nameless company cannot be resolved and is the classifier's
    no-company case).
    """
    return _WHITESPACE_RE.sub(" ", (name or "").strip()).lower()


# --- disposition classifier --------------------------------------------------
#
# The integration step: given the mapped lead rows plus what Salesforce returned,
# decide each row's fate. Five dispositions, and the unifying test throughout is
# the scope doc's: "would emailing this row recreate the gmail-Account failure?"
#
#   NET_NEW           create a Contact (+ match or create its Account). Uploads.
#   MATCHED           the Contact already exists (1 on this email) and is already
#                     seeded (non-blank on stage or status) — leave it entirely
#                     alone, do not touch stage/status. Uploads.
#   MATCHED_SEED      the Contact already exists (1 on this email) and is null on
#                     BOTH governed fields — seed the floor (null -> Cold_Prospect/
#                     New) on it by Id. A forward null->floor write the opt-out
#                     permits (ADR-037 D1/D2). Uploads.
#   MULTIPLE_CONTACTS >1 Contact on this email — skip the SF write, flag for a
#                     dedup TODO. The contact already exists so OutboundSync
#                     matches it (no gmail risk) — so the row STILL uploads.
#   NEEDS_REVIEW      held from BOTH Salesforce AND the EB upload, because
#                     emailing it WOULD recreate the failure. Reasons:
#                       no_email          — nothing to match or send to
#                       no_company        — cannot build/parent an Account
#                       no_contact_method — no website and no phone (would need
#                         the Account_Contact_Method_Required VR bypass; the
#                         operator chose to enrich these first, not depend on it)
#
# The needs-review company/contact-method checks apply ONLY to net-new rows: if a
# Contact already exists (matched/multiple), OutboundSync matches it and no
# Account is created, so a missing company or website is harmless there.
#
# Precondition: input rows are already deduplicated by email (launch-campaign
# Phase 1 does this) — the classifier does not dedup within the batch.

NET_NEW = "net_new"
MATCHED = "matched"
MATCHED_SEED = "matched_seed"
MULTIPLE_CONTACTS = "multiple_contacts"
NEEDS_REVIEW = "needs_review"

# The lifecycle floor (ADR-037 Decision 1). Written on a net-new Contact AND on a
# matched Contact that is null on BOTH governed fields — never above the floor,
# never on a matched Contact with either field already set. Exposed as constants
# so the seed value is deterministic and the skill references it instead of
# re-hardcoding the strings in prose (where they would drift).
FLOOR_LIFECYCLE_STAGE = "Cold_Prospect"
FLOOR_LEAD_STATUS = "New"


class MatchedContact(NamedTuple):
    """One existing Contact matched on a lead's email (a Phase-2 SOQL row).

    Carries the Contact Id (to target a seed UPDATE) and the two governed
    lifecycle fields, so `classify_rows` can make the matched-both-null decision
    (ADR-037 D1) instead of seeing only a count. `contacts_by_email` maps a
    normalized email to the list of these — its length is the match count.
    """

    contact_id: str = ""
    lifecycle_stage: Optional[str] = None
    lead_status: Optional[str] = None


def _is_blank(value: Optional[str]) -> bool:
    """A governed field is 'unseeded' when null or empty/whitespace.

    Both-null is assessed on this predicate over BOTH fields together: a Contact
    is seed-eligible only when stage AND status are both blank. Every suppression
    value (`Do_Not_Prospect`, any advanced stage, any set status) is non-blank on
    at least one axis, so the opt-out holds structurally (ADR-037 D2).
    """
    return value is None or value.strip() == ""

#: Company values that cannot anchor an Account — identical to `_JUNK_NAMES` by
#: derivation so the two sets can never drift apart. A company cell holding a
#: header token like "last_name" or a placeholder like "Unknown" is not a real
#: business; it must be held for review, never written as an Account/LastName.
#: (BC-17213 review — the two sets had silently diverged, letting a header-token
#: company slip through as net-new.)
_JUNK_COMPANY = _JUNK_NAMES


def _is_usable_company(company: str) -> bool:
    return company.strip().lower() not in _JUNK_COMPANY


class RowPlan(NamedTuple):
    """One row's disposition and its resolved write payload.

    A net-new row carries the contact/account creation payload below; a
    matched-seed row carries only `contact_id` (the existing Contact to seed by
    Id); every other disposition writes nothing.
    """

    row: Mapping[str, str]        # the original mapped row (for the sidecar + write)
    email: str                    # normalized (lower, trimmed)
    disposition: str
    reason: str = ""              # set only for needs_review
    uploads_to_eb: bool = True    # False iff needs_review
    contact_id: str = ""          # existing Contact Id — set only for matched_seed
    # net-new payload (empty/default for every other disposition):
    contact_first: str = ""
    contact_last: str = ""
    is_person: bool = False
    account_key: str = ""
    account_matched: bool = False  # True → parent to an existing Account
    account_id: str = ""           # the existing Account Id when account_matched
    account_ambiguous: bool = False  # True → key hit >1 Account; created new (Q5)
    website: str = ""
    phone: str = ""


class PreloadPlan(NamedTuple):
    """The whole plan: every row's disposition, the two derived sets, and counts."""

    rows: List[RowPlan]            # every row, in input order
    eb_rows: List[RowPlan]         # the surviving set that proceeds to the EB upload
    sidecar_rows: List[RowPlan]    # rows the operator should see (needs_review + multiple)
    counts: Dict[str, int]


def classify_rows(
    rows: Sequence[Mapping[str, str]],
    contacts_by_email: Mapping[str, Sequence[MatchedContact]],
    accounts_by_key: Mapping[str, Sequence[str]],
) -> PreloadPlan:
    """Bucket each mapped lead row against the Salesforce lookups.

    - `contacts_by_email`: normalized-email → the list of existing `MatchedContact`
      records on it (from the Phase-2 SOQL). Its length is the match count; for a
      single match the record's governed-field values drive the ADR-037 matched-
      both-null seed decision (both blank → seed the floor; either set → leave it).
    - `accounts_by_key`: `company_match_key(name)` → the list of existing Account
      Ids whose name normalizes to that key, for the candidate Accounts Salesforce
      returned. A key with >1 Id is ambiguous — we attach only on an exact single
      match and create new otherwise (Q5: favor a duplicate over a wrong merge).

    Returns a `PreloadPlan`. The caller writes the net-new records, leaves matched
    ones alone, writes `sidecar_rows` to the review CSV, and uploads `eb_rows`.
    A held (needs_review) row is never in `eb_rows` — that is the invariant that
    keeps a row we could not safely represent out of the campaign.
    """
    results: List[RowPlan] = []

    for row in rows:
        email = (row.get("email") or "").strip().lower()
        company = (row.get("company") or "").strip()

        if not email:
            results.append(RowPlan(row=row, email="", disposition=NEEDS_REVIEW,
                                   reason="no_email", uploads_to_eb=False))
            continue

        matches = contacts_by_email.get(email, ())
        if len(matches) == 1:
            only = matches[0]
            # ADR-037 D1/D2: a matched Contact null on BOTH governed fields gets
            # the floor (a forward null→floor write); if EITHER is already set,
            # leave it entirely alone (opt-out — the two axes are assessed
            # together, never top up a single blank axis).
            # Fail-closed: require a real contact_id before seeding. A both-null
            # match with no Id would be a seed disposition with no write target —
            # a permissive default reaching the write branch (the BC-17336
            # fail-open shape). Without an Id, fall through to MATCHED (untouched)
            # — the safe direction. Real SOQL always carries an Id; this is defense.
            if (_is_blank(only.lifecycle_stage) and _is_blank(only.lead_status)
                    and not _is_blank(only.contact_id)):
                results.append(RowPlan(row=row, email=email, disposition=MATCHED_SEED,
                                       contact_id=only.contact_id))
            else:
                results.append(RowPlan(row=row, email=email, disposition=MATCHED))
            continue
        if len(matches) > 1:
            results.append(RowPlan(row=row, email=email, disposition=MULTIPLE_CONTACTS))
            continue

        # no match → net-new candidate: we would CREATE it, so it must be
        # representable without recreating the failure.
        if not _is_usable_company(company):
            results.append(RowPlan(row=row, email=email, disposition=NEEDS_REVIEW,
                                   reason="no_company", uploads_to_eb=False))
            continue

        website = resolve_website(row.get("domain")) or ""
        phone = (row.get("phone") or "").strip()
        if not website and not phone:
            results.append(RowPlan(row=row, email=email, disposition=NEEDS_REVIEW,
                                   reason="no_contact_method", uploads_to_eb=False))
            continue

        name = resolve_name(row.get("first_name"), row.get("last_name"),
                            row.get("full_name"), company)
        key = company_match_key(company)
        # Attach to an existing Account ONLY when the normalized name matches
        # EXACTLY ONE. Two-or-more candidates is an ambiguous key — attaching to
        # an arbitrary one is the wrong merge Q5 forbids, so create new instead
        # (favor a duplicate over a wrong merge). Zero candidates → create new.
        candidates = accounts_by_key.get(key, ())
        matched = len(candidates) == 1
        ambiguous = len(candidates) > 1
        results.append(RowPlan(
            row=row, email=email, disposition=NET_NEW,
            contact_first=name.first_name, contact_last=name.last_name, is_person=name.is_person,
            account_key=key, account_matched=matched,
            account_id=candidates[0] if matched else "",
            account_ambiguous=ambiguous,
            website=website, phone=phone,
        ))

    by_disp = Counter(rp.disposition for rp in results)
    review_by_reason = Counter(rp.reason for rp in results if rp.disposition == NEEDS_REVIEW)
    # Companies are counted DISTINCT by match key — many contacts can share one.
    matched_keys = {rp.account_key for rp in results if rp.disposition == NET_NEW and rp.account_matched}
    new_keys = {rp.account_key for rp in results if rp.disposition == NET_NEW and not rp.account_matched}
    ambiguous_keys = {rp.account_key for rp in results if rp.disposition == NET_NEW and rp.account_ambiguous}

    eb_rows = [rp for rp in results if rp.uploads_to_eb]
    sidecar_rows = [rp for rp in results if rp.disposition in (NEEDS_REVIEW, MULTIPLE_CONTACTS)]

    counts = {
        "total": len(results),
        "net_new": by_disp[NET_NEW],
        "matched": by_disp[MATCHED],
        "matched_seed": by_disp[MATCHED_SEED],
        "multiple_contacts": by_disp[MULTIPLE_CONTACTS],
        "needs_review": by_disp[NEEDS_REVIEW],
        "accounts_matched": len(matched_keys),
        "accounts_new": len(new_keys),
        "accounts_ambiguous": len(ambiguous_keys),
        "review_no_email": review_by_reason["no_email"],
        "review_no_company": review_by_reason["no_company"],
        "review_no_contact_method": review_by_reason["no_contact_method"],
        "eb_upload": len(eb_rows),
    }

    return PreloadPlan(rows=results, eb_rows=eb_rows, sidecar_rows=sidecar_rows, counts=counts)
