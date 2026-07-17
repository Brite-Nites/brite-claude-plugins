#!/usr/bin/env bash
# Behavioral tests for salesforce_preload.py (BC-17213) — the pre-load's
# deterministic core. Emits `RESULT pass=N fail=M` for validate.sh to grep.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$SCRIPT_DIR" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])

from salesforce_preload import FREE_EMAIL_DOMAINS, resolve_website

_pass = _fail = 0


def check(name, got, want):
    global _pass, _fail
    if got == want:
        _pass += 1
        print(f"  ok   {name}")
    else:
        _fail += 1
        print(f"  FAIL {name}\n         got:  {got!r}\n         want: {want!r}")


# --- the safety guarantee: never a free-email website -----------------------
# Every domain the Salesforce guard (FreeEmailDomains.cls) rejects must resolve
# to None here, so a row can never sail past and then fail at insert.
SF_GUARD_DOMAINS = [
    "gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "aol.com",
    "icloud.com", "me.com", "protonmail.com", "mail.com", "ymail.com",
    "live.com", "msn.com", "comcast.net", "att.net", "verizon.net",
]
for d in SF_GUARD_DOMAINS:
    check(f"free-email rejected: {d}", resolve_website(d), None)
    check(f"superset invariant: {d} in FREE_EMAIL_DOMAINS", d in FREE_EMAIL_DOMAINS, True)

# free-email in disguise still rejected
check("www.gmail.com rejected", resolve_website("www.gmail.com"), None)
check("https://gmail.com rejected", resolve_website("https://gmail.com"), None)
check("GMAIL.COM (case) rejected", resolve_website("GMAIL.COM"), None)
check("email joe@gmail.com rejected", resolve_website("joe@gmail.com"), None)
check("mailto:joe@yahoo.com rejected", resolve_website("mailto:joe@yahoo.com"), None)

# --- real company domains survive + get cleaned -----------------------------
check("bare domain kept", resolve_website("dubykwinery.com"), "dubykwinery.com")
check("strip https + www", resolve_website("https://www.dubykwinery.com"), "dubykwinery.com")
check("strip path", resolve_website("https://www.dubykwinery.com/about-us"), "dubykwinery.com")
check("strip query", resolve_website("dubykwinery.com?utm=x"), "dubykwinery.com")
check("lowercase", resolve_website("DubykWinery.com"), "dubykwinery.com")
check("trim whitespace", resolve_website("  dubykwinery.com  "), "dubykwinery.com")
check("corporate email -> company domain", resolve_website("joe@dubykwinery.com"), "dubykwinery.com")
check("subdomain preserved", resolve_website("shop.dubykwinery.com"), "shop.dubykwinery.com")
check("multi-label domain preserved", resolve_website("www.brewery.co.uk"), "brewery.co.uk")

# --- missing / empty -> None (blank website, not an error) ------------------
check("None -> None", resolve_website(None), None)
check("empty -> None", resolve_website(""), None)
check("whitespace -> None", resolve_website("   "), None)
check("scheme only -> None", resolve_website("https://"), None)
check("bare www -> None", resolve_website("www."), None)

print(f"\nRESULT pass={_pass} fail={_fail}")
sys.exit(1 if _fail else 0)
PY
