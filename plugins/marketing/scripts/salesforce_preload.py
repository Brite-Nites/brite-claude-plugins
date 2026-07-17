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
  - (a later step appends: the disposition classifier)

Nothing here touches the network or the filesystem; the skill feeds it values
and acts on what it returns.
"""

from __future__ import annotations

import re
from typing import NamedTuple, Optional

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
    value = value.split("/", 1)[0]      # drop any path/query/fragment
    value = value.split("?", 1)[0]
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
