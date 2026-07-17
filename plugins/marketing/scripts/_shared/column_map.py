"""Resolve lead-CSV headers onto the fields the Salesforce pre-load needs (BC-17213).

Lead lists arrive from Apollo, Serper, Clay, and hand-built rosters, and no two
spell their headers alike — `Company Name` / `company_name` / `company` /
`Organization` all mean the same thing. This module maps whatever headers a
file has onto a small canonical vocabulary.

WHAT IS REUSED VS. LOCAL (per the reuse-vs-duplicate research, 2026-07-17):

  - The header-alias table is REFERENCE DATA and is authority-independent —
    "Organization" means company no matter who reads the file. So we do NOT
    hand-maintain our own; we vendor the Brite data platform's table
    (`lead_column_aliases.py`) verbatim and PROJECT it onto our fields.

  - The use-case-specific glue is LOCAL and lives here: which fields the
    pre-load requires, how it treats an ambiguous `name` column, and the
    contact-method rule. This is the part that must NOT be shared, because it
    is shaped to Salesforce, not to the data platform's enrichment ingest.

The one deliberate DEVIATION from the vendored table: it maps bare `name` to a
person's full name (correct for people lists). But this plugin's Labs lists —
senior-living communities, retail storefronts, wineries — use `name` for the
BUSINESS. Silently reading it as a person would wreck the common case, so bare
`name` is held back as an operator question instead. Every other spelling
resolves per the vendored table.

The rule this module enforces: recognised headers resolve automatically;
anything genuinely ambiguous is handed back to the operator with sample values,
never guessed. A wrong guess writes the wrong company into Salesforce, and a
wrong company is a wrong Account.

Pure and stdlib-only: `resolve(headers)` returns a decision; the caller owns
the I/O and the operator turn.
"""

from __future__ import annotations

import re
from typing import Dict, List, Mapping, NamedTuple, Sequence

from _shared.lead_column_aliases import VENDORED_ALIASES

# --- canonical fields (this plugin's vocabulary) ----------------------------

EMAIL = "email"
FIRST_NAME = "first_name"
LAST_NAME = "last_name"
FULL_NAME = "full_name"
COMPANY = "company"
DOMAIN = "domain"
PHONE = "phone"
TITLE = "title"

#: The pre-load cannot proceed without these. `email` is the Contact match key;
#: `company` is the Account name AND the LastName fallback when a row carries no
#: person (never a placeholder).
REQUIRED = (EMAIL, COMPANY)

#: At least ONE must resolve, or every row fails Salesforce's
#: `Account_Contact_Method_Required` rule and lands in needs-review. Not
#: required individually — the per-row cascade tries domain first, then phone.
CONTACT_METHOD = (DOMAIN, PHONE)

#: The data platform's canonical keys → this plugin's fields. Keys absent here
#: (SENIORITY, INDUSTRY, PERSONAL_EMAIL, ICP_FIT, …) are recognised-but-ignored:
#: known to be something the pre-load doesn't use, so never offered as a
#: company candidate. Note PERSONAL_EMAIL is deliberately NOT projected to
#: EMAIL — it is a different address and mapping it would retarget the campaign.
_PROJECTION: Dict[str, str] = {
    "FIRST_NAME": FIRST_NAME,
    "LAST_NAME": LAST_NAME,
    "FULL_NAME": FULL_NAME,
    "COMPANY_NAME": COMPANY,
    "DOMAIN": DOMAIN,
    "COMPANY_WEBSITE": DOMAIN,  # a website is a domain source for the Account
    "EMAIL": EMAIL,
    "WORK_EMAIL": EMAIL,        # both are usable; both present → collision → ask
    "PHONE": PHONE,
    "COMPANY_PHONE": PHONE,     # the Account's contact-method fallback
    "TITLE": TITLE,
}

#: Header tokens the vendored table resolves, but which THIS plugin's inputs use
#: differently and must therefore hand back to the operator. Bare `name` is the
#: business in Labs venue lists but a person in people lists — genuinely
#: ambiguous here, so never auto-resolved. (Explicit `full name` / `person name`
#: / `contact name` stay resolved — only the bare, overloaded token is held.)
_AMBIGUOUS_TOKENS = frozenset({"name"})


def _normalize(header: str) -> str:
    """Fold a header to its comparison form: lowercase, alphanumerics only.

    Collapses spelling variants that differ only in punctuation, so
    `Company Name`, `company_name`, and `company-name` all land on one key.
    Deliberately does NOT stem or fuzzy-match.
    """
    return re.sub(r"[^a-z0-9]+", "", header.strip().lower())


def _build_index() -> Dict[str, str]:
    """Index the vendored table under this module's normalization.

    The vendored table enumerates space- and underscore- forms as separate
    keys; folding them under `_normalize` collapses each pair to one lookup and
    adds punctuation robustness (`company-name`) the vendored table lacks. Fails
    loudly if two upstream keys ever collapse to one normalized form with
    conflicting canonical values — that would be silent data loss, so it must
    break the build instead.
    """
    index: Dict[str, str] = {}
    for raw_key, canon in VENDORED_ALIASES.items():
        norm = _normalize(raw_key)
        prior = index.get(norm)
        if prior is not None and prior != canon:
            raise ValueError(
                f"vendored alias collision under normalization: {norm!r} maps to "
                f"both {prior!r} and {canon!r} — refresh introduced an ambiguity"
            )
        index[norm] = canon
    return index


#: normalized header -> the data platform's canonical key (ALL of them, projected or not).
_CANON_INDEX = _build_index()


class Ambiguity(NamedTuple):
    """One thing the operator must resolve before the run can proceed."""

    field: str
    #: "unresolved" (nothing matched a required field) or "collision" (several
    #: headers matched the same field).
    reason: str
    #: Headers the operator can choose between. Recognised-but-unused columns
    #: (city, seniority, …) are excluded — only plausible candidates appear.
    candidates: List[str]


class Resolution(NamedTuple):
    """The outcome of resolving one file's headers."""

    #: field -> header, for everything settled without asking.
    resolved: Dict[str, str]
    #: Questions for the operator. Empty means the file mapped cleanly.
    ambiguities: List[Ambiguity]
    #: Every header not resolved to a canonical field — recognised-but-unused
    #: AND unknown. Reported for transparency, never guessed at.
    unmapped: List[str]

    @property
    def needs_operator(self) -> bool:
        return bool(self.ambiguities)


def resolve(headers: Sequence[str]) -> Resolution:
    """Map `headers` onto canonical fields, deferring anything ambiguous.

    Returns what resolved cleanly, what the operator must decide, and what was
    ignored. Never raises on a bad file — an unusable file comes back as
    ambiguities for the caller to surface.
    """
    claims: Dict[str, List[str]] = {}
    plausible: List[str] = []   # unknown or ambiguous → could be a missing required field
    ignored: List[str] = []     # recognised, but not a field the pre-load uses

    for header in headers:
        norm = _normalize(header)
        if norm in _AMBIGUOUS_TOKENS:
            plausible.append(header)
            continue
        canon = _CANON_INDEX.get(norm)
        if canon is None:
            plausible.append(header)          # unknown header
        elif canon in _PROJECTION:
            claims.setdefault(_PROJECTION[canon], []).append(header)
        else:
            ignored.append(header)            # recognised but unused (seniority, city, …)

    resolved: Dict[str, str] = {}
    ambiguities: List[Ambiguity] = []

    for field, matched in claims.items():
        if len(matched) == 1:
            resolved[field] = matched[0]
        else:
            # Several headers claim one field — e.g. `Company Website` AND
            # `Company Domain` both project to `domain`, and they are genuinely
            # different values. Picking by position is a coin flip on what lands
            # in Salesforce, so ask.
            ambiguities.append(Ambiguity(field=field, reason="collision", candidates=list(matched)))

    for field in REQUIRED:
        if field not in resolved and field not in claims:
            ambiguities.append(Ambiguity(field=field, reason="unresolved", candidates=list(plausible)))

    if not any(f in claims for f in CONTACT_METHOD):
        ambiguities.append(Ambiguity(field=DOMAIN, reason="unresolved", candidates=list(plausible)))

    ambiguities.sort(key=lambda a: (a.field, a.reason))
    return Resolution(resolved=resolved, ambiguities=ambiguities, unmapped=ignored + plausible)


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

    `decisions` is field -> chosen header. A field mapped to the empty string is
    the operator saying "ignore this one".
    """
    merged = dict(resolution.resolved)
    for field, header in decisions.items():
        if header:
            merged[field] = header
        else:
            merged.pop(field, None)
    return merged
