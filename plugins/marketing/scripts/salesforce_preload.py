"""Deterministic core for the salesforce-preload skill (BC-17213).

The skill (SKILL.md) drives the live Salesforce reads/writes and the operator
turns. THIS module is the pure, stdlib-only, testable logic underneath it — the
decisions that must be exactly right every time and would be dangerous to leave
to prose:

  - resolve_website  — what goes in Account.Website, and the hard guarantee it
    is NEVER a free-email domain (this step)
  - (later steps append: the name convention, the company-name match key, and
    the disposition classifier)

Nothing here touches the network or the filesystem; the skill feeds it values
and acts on what it returns.
"""

from __future__ import annotations

import re
from typing import Optional

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
