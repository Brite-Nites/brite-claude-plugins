"""Resolve lead-CSV headers onto the canonical field vocabulary (BC-17213).

Lead lists arrive from many sources — Apollo exports, Serper scrapes, Clay
waterfalls, hand-built rosters — and no two spell their headers the same way.
The same concept appears as `Company Name`, `company_name`, `company`, or just
`name`. A fixed column contract does not survive that, so this module maps
whatever headers a file actually has onto the canonical fields its consumers
need.

Two consumers share this vocabulary: the Salesforce pre-load (which needs
`company` and a contact method to build a real Account) and the Email Bison
upload (which needs `title`). Mapping once, here, keeps them from each reaching
into the raw CSV with their own hardcoded guesses.

The rule this module exists to enforce: **recognised headers resolve
automatically; everything else is handed back to the operator, never guessed.**
A wrong guess writes the wrong company name into Salesforce, and a wrong
company name is a wrong Account — the one error the matching design spends all
its effort avoiding. Silence is cheaper than a confident mistake.

Pure and stdlib-only: `resolve(headers, samples)` takes what it is given and
returns a decision. It reads no files and asks no questions; the caller does
the I/O and owns the operator turn.
"""

from __future__ import annotations

import re
from typing import Dict, List, Mapping, NamedTuple, Sequence

# --- canonical fields -------------------------------------------------------

EMAIL = "email"
FIRST_NAME = "first_name"
LAST_NAME = "last_name"
COMPANY = "company"
DOMAIN = "domain"
PHONE = "phone"
TITLE = "title"

#: Fields the Salesforce pre-load cannot proceed without at all.
#: `email` is the Contact match key; `company` is the Account name AND the
#: LastName fallback when a row carries no person (never a placeholder).
REQUIRED = (EMAIL, COMPANY)

#: At least ONE of these must resolve, or every row fails Salesforce's
#: `Account_Contact_Method_Required` rule ("New accounts must have at least a
#: Phone or Website") and the whole run lands in needs-review. Not required
#: individually — the per-row cascade tries domain first, then phone.
CONTACT_METHOD = (DOMAIN, PHONE)

#: Header aliases, keyed by normalized form. Built from the real lead files in
#: docs/campaigns/ plus the column contract launch-campaign already documents.
#: Add to these freely; every addition is a header we stop asking about.
_ALIASES: Dict[str, str] = {}


def _register(field: str, *aliases: str) -> None:
    for alias in aliases:
        _ALIASES[_normalize(alias)] = field


def _normalize(header: str) -> str:
    """Fold a header to its comparison form: lowercase, alphanumerics only.

    Collapses the spelling variants that differ only in punctuation, so
    `Company Name`, `company_name`, and `company-name` all land on the same
    key. Deliberately does NOT stem or fuzzy-match — `company` and `name` stay
    distinct, because they mean different things.
    """
    return re.sub(r"[^a-z0-9]+", "", header.strip().lower())


_register(EMAIL, "email", "email address", "e-mail", "work email", "business email", "primary email")
# NOT "personal email": Apollo exports carry both `Email` and `Personal Email`,
# and they are different addresses. Mapping the personal one would silently
# retarget the campaign.
_register(FIRST_NAME, "first name", "firstname", "fname", "given name")
_register(LAST_NAME, "last name", "lastname", "lname", "surname", "family name")
_register(COMPANY, "company", "company name", "organization", "organisation",
          "business name", "account name", "employer")
_register(DOMAIN, "domain", "company domain", "website", "company website",
          "url", "web url", "website url", "homepage")
_register(PHONE, "phone", "phone number", "company phone", "company phone number",
          "telephone", "tel", "mobile", "mobile number", "mobile phone")
_register(TITLE, "title", "job title", "position", "job position")
# NOT "role": in the local-retail upload files `role` is a role-address boolean
# (is this info@/sales@?), not a job title. Mapping it would be nonsense.


class Ambiguity(NamedTuple):
    """One thing the operator must resolve before the run can proceed."""

    field: str
    #: Why we're asking. One of "unresolved" (nothing matched a required
    #: field) or "collision" (several headers matched the same field).
    reason: str
    #: Headers the operator can choose between, each with sample values so the
    #: question is answerable at a glance rather than by opening the file.
    candidates: List[str]


class Resolution(NamedTuple):
    """The outcome of resolving one file's headers."""

    #: field -> header, for everything settled without asking.
    resolved: Dict[str, str]
    #: Questions for the operator. Empty means the file mapped cleanly.
    ambiguities: List[Ambiguity]
    #: Headers we recognised nothing in. Reported for transparency, never
    #: guessed at; a lead file legitimately carries many columns we don't want.
    unmapped: List[str]

    @property
    def needs_operator(self) -> bool:
        return bool(self.ambiguities)


def resolve(headers: Sequence[str]) -> Resolution:
    """Map `headers` onto canonical fields, deferring anything ambiguous.

    Returns what resolved cleanly, what the operator must decide, and what was
    ignored. Never raises on a bad file — an unusable file comes back as
    ambiguities for the caller to surface, because "which column is the
    company?" is a better error than a stack trace.
    """
    claims: Dict[str, List[str]] = {}
    unmapped: List[str] = []

    for header in headers:
        field = _ALIASES.get(_normalize(header))
        if field is None:
            unmapped.append(header)
        else:
            claims.setdefault(field, []).append(header)

    resolved: Dict[str, str] = {}
    ambiguities: List[Ambiguity] = []

    for field, matched in claims.items():
        if len(matched) == 1:
            resolved[field] = matched[0]
        else:
            # Several headers claim one field — e.g. an Apollo export carrying
            # both `Company Website` and `Company Domain`. They are genuinely
            # different values (one has a protocol, one doesn't), so picking
            # one by position would be a coin flip on which lands in Salesforce.
            ambiguities.append(Ambiguity(field=field, reason="collision", candidates=list(matched)))

    for field in REQUIRED:
        if field not in resolved and field not in claims:
            # Nothing matched. The operator picks from what's left — this is
            # the `name` case, where a senior-living roster calls the business
            # `name` and we cannot tell it from a person's name by header alone.
            ambiguities.append(Ambiguity(field=field, reason="unresolved", candidates=list(unmapped)))

    if not any(f in claims for f in CONTACT_METHOD):
        ambiguities.append(
            Ambiguity(field=DOMAIN, reason="unresolved", candidates=list(unmapped))
        )

    ambiguities.sort(key=lambda a: (a.field, a.reason))
    return Resolution(resolved=resolved, ambiguities=ambiguities, unmapped=unmapped)


def samples_for(header: str, rows: Sequence[Mapping[str, str]], limit: int = 3) -> List[str]:
    """First `limit` non-empty values under `header` — the evidence for a question.

    An operator asked "is `name` the company?" answers instantly when shown
    "Sunrise of Bellevue, Brookdale Meridian" and cannot answer at all when
    shown nothing.
    """
    seen: List[str] = []
    for row in rows:
        value = (row.get(header) or "").strip()
        if value and value not in seen:
            seen.append(value)
            if len(seen) == limit:
                break
    return seen


def apply(resolution: Resolution, decisions: Mapping[str, str]) -> Dict[str, str]:
    """Fold the operator's answers into the resolved map.

    `decisions` is field -> chosen header. A field mapped to the empty string
    is the operator saying "ignore this one", and is dropped rather than
    recorded as a header named "".
    """
    merged = dict(resolution.resolved)
    for field, header in decisions.items():
        if header:
            merged[field] = header
        else:
            merged.pop(field, None)
    return merged
