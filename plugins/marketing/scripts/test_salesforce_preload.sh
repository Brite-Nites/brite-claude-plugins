#!/usr/bin/env bash
# Behavioral tests for salesforce_preload.py (BC-17213) — the pre-load's
# deterministic core. Emits `RESULT pass=N fail=M` for validate.sh to grep.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$SCRIPT_DIR" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])

from salesforce_preload import (
    FREE_EMAIL_DOMAINS, MATCHED, MATCHED_SEED, MULTIPLE_CONTACTS, NEEDS_REVIEW,
    NET_NEW, MatchedContact, classify_rows, company_match_key, resolve_name,
    resolve_website,
)

_pass = _fail = 0


def same(name, a, b):
    """Assert two company names produce the SAME match key (would match)."""
    check(name, company_match_key(a), company_match_key(b))


def distinct(name, a, b):
    """Assert two company names produce DIFFERENT keys (would NOT match)."""
    global _pass, _fail
    ka, kb = company_match_key(a), company_match_key(b)
    if ka != kb:
        _pass += 1
        print(f"  ok   {name}")
    else:
        _fail += 1
        print(f"  FAIL {name}\n         both normalized to {ka!r} (should differ)")


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

# --- :port and #fragment must NOT let a free-email domain slip past ----------
# (BC-17213 Greptile: these forms bypassed the block-list before the fix.)
check("free-email with :port → blocked", resolve_website("gmail.com:8080"), None)
check("free-email with #fragment → blocked", resolve_website("gmail.com#inbox"), None)
check("free-email scheme+port+path → blocked", resolve_website("https://gmail.com:443/mail"), None)
check("real domain drops :port", resolve_website("acme.com:8080"), "acme.com")
check("real domain drops #fragment", resolve_website("acme.com#team"), "acme.com")

# --- missing / empty -> None (blank website, not an error) ------------------
check("None -> None", resolve_website(None), None)
check("empty -> None", resolve_website(""), None)
check("whitespace -> None", resolve_website("   "), None)
check("scheme only -> None", resolve_website("https://"), None)
check("bare www -> None", resolve_website("www."), None)

# --- name convention: real person ------------------------------------------
d = resolve_name("Joe", "Dubyk", None, "Dubyk Winery")
check("person: first", d.first_name, "Joe")
check("person: last", d.last_name, "Dubyk")
check("person: is_person", d.is_person, True)

# first name only, no surname → falls to company path (no valid person)
d = resolve_name("Joe", "", None, "Dubyk Winery")
check("lone first name → company path first blank", d.first_name, "")
check("lone first name → company in last", d.last_name, "Dubyk Winery")
check("lone first name → not a person", d.is_person, False)

# full name split when first/last absent
d = resolve_name(None, None, "Joe Dubyk", "Dubyk Winery")
check("full name split: first", d.first_name, "Joe")
check("full name split: last", d.last_name, "Dubyk")
check("full name split: is_person", d.is_person, True)
d = resolve_name(None, None, "Mary Jane Watson", "Acme")
check("full name multi-token: first", d.first_name, "Mary")
check("full name multi-token: last", d.last_name, "Jane Watson")
# single-token full name has no surname → company path
d = resolve_name(None, None, "Cher", "Cher's Boutique")
check("single-token full name → company path", d.last_name, "Cher's Boutique")
check("single-token full name → not a person", d.is_person, False)

# --- name convention: no person → company in LastName -----------------------
d = resolve_name("", "", None, "Dubyk Winery")
check("no person: first blank", d.first_name, "")
check("no person: company in last", d.last_name, "Dubyk Winery")
check("no person: is_person False", d.is_person, False)

# --- name convention: NEVER a placeholder -----------------------------------
for junk in ["-", "last_name", "Unknown", "n/a", "None", "NULL", "unknown prospect"]:
    d = resolve_name("", junk, None, "Dubyk Winery")
    check(f"junk last {junk!r} → company, not placeholder", d.last_name, "Dubyk Winery")
    check(f"junk last {junk!r} → never the placeholder itself", d.last_name.lower() == junk.lower(), False)

# name field stuffed with the company (OutboundSync/old-script pattern)
d = resolve_name("Dubyk Winery", "Dubyk Winery", None, "Dubyk Winery")
check("name==company: first blanked", d.first_name, "")
check("name==company: company in last (once)", d.last_name, "Dubyk Winery")
check("name==company: not a person", d.is_person, False)

# junk first but real last → keep the person, blank the junk first
d = resolve_name("-", "Dubyk", None, "Dubyk Winery")
check("junk first, real last: first blanked", d.first_name, "")
check("junk first, real last: last kept", d.last_name, "Dubyk")
check("junk first, real last: is_person", d.is_person, True)

# junk in the COMPANY field must never become a LastName placeholder. The
# classifier normally holds these rows, but resolve_name refuses in isolation
# too (BC-17213 review — the guarantee must hold even when called directly).
for junk in ["last_name", "Unknown", "first_name", "noname", "n/a", "None", "-"]:
    d = resolve_name("", "", None, junk)
    check(f"junk company {junk!r} → blank last (no placeholder)", d.last_name, "")
    check(f"junk company {junk!r} → not a person", d.is_person, False)

# --- no company at all → blank last (classifier routes to needs-review) ------
d = resolve_name("", "", None, "")
check("no person, no company: blank last", d.last_name, "")
check("no person, no company: not a person", d.is_person, False)
# a real person with no company still gets a valid name (classifier holds the row)
d = resolve_name("Joe", "Dubyk", None, "")
check("person, no company: still a valid person name", (d.first_name, d.last_name, d.is_person),
      ("Joe", "Dubyk", True))

# --- length caps (SF FirstName 40 / LastName 80) ----------------------------
long_co = "A" * 100
check("company over 80 chars truncated", len(resolve_name("", "", None, long_co).last_name), 80)
check("first over 40 chars truncated", len(resolve_name("B" * 60, "Smith", None, "X").first_name), 40)

# --- casing preserved (SF trigger re-cases; we stay faithful) ---------------
d = resolve_name("joe", "dubyk", None, "dubyk winery LLC")
check("person casing preserved", (d.first_name, d.last_name), ("joe", "dubyk"))
check("company casing preserved", resolve_name("", "", None, "dubyk winery LLC").last_name, "dubyk winery LLC")

# --- company match key: bridges pure noise (WOULD match) --------------------
same("case-insensitive", "Dubyk Winery", "DUBYK WINERY")
same("mixed case", "Dubyk Winery", "dubyk winery")
same("double space collapsed", "Dubyk  Winery", "Dubyk Winery")
same("leading/trailing trimmed", "  Dubyk Winery  ", "Dubyk Winery")
same("tab vs space", "Dubyk\tWinery", "Dubyk Winery")
same("case + space together", "  DUBYK   WINERY ", "dubyk winery")

# --- company match key: does NOT bridge words (would NOT match) --------------
# The deliberate conservatism — favor a duplicate over a wrong merge.
distinct("suffix Inc not stripped", "Acme Inc", "Acme")
distinct("Inc vs LLC stay distinct", "Acme Inc", "Acme LLC")
distinct("suffix word kept", "Dubyk Winery Inc", "Dubyk Winery")
distinct("leading The kept", "The Winery", "Winery")
distinct("different company", "Dubyk Winery", "Sunrise Cellars")
# punctuation is NOT bridged → a duplicate, not a merge (accepted trade)
distinct("comma before suffix -> duplicate not merge", "Acme, Inc.", "Acme Inc")
distinct("ampersand vs word", "A&B Corp", "AB Corp")

# --- empty / missing --------------------------------------------------------
check("None -> empty key", company_match_key(None), "")
check("empty -> empty key", company_match_key(""), "")
check("whitespace -> empty key", company_match_key("   "), "")

# --- disposition classifier -------------------------------------------------
def R(**kw):
    return kw  # a mapped lead row

# A representative batch exercising every bucket at once.
rows = [
    R(email="joe@gmail.com",   company="Dubyk Winery",   domain="dubykwinery.com", first_name="Joe", last_name="Dubyk"),  # net-new, new account
    R(email="amy@gmail.com",   company="Dubyk Winery",   domain="dubykwinery.com", first_name="Amy", last_name="Lee"),    # net-new, SAME account
    R(email="sue@gmail.com",   company="Sunrise Cellars", domain="sunrisecellars.com"),                                    # net-new, matched existing account
    R(email="bob@gmail.com",   company="Existing Co",    domain="existingco.com"),                                        # matched contact — leave alone
    R(email="dup@gmail.com",   company="Twice Co",       domain="twiceco.com"),                                           # multiple contacts — flag, still upload
    R(email="nocomp@gmail.com", company="",               domain="whatever.com"),                                          # needs-review: no company
    R(email="nomethod@gmail.com", company="No Reach LLC", domain="", phone=""),                                            # needs-review: no contact method
    R(email="",                company="Ghost Co",       domain="ghostco.com"),                                           # needs-review: no email
]
# The lookup carries the matched Contacts' field values (BC-17347): a single
# match at MQL/Working is advanced, so it stays MATCHED (untouched); the >1 case
# is MULTIPLE regardless of field values.
contacts_by_email = {
    "bob@gmail.com": [MatchedContact("003BOB", "MQL", "Working")],
    "dup@gmail.com": [MatchedContact("003D1"), MatchedContact("003D2"), MatchedContact("003D3")],
}
accounts_by_key = {company_match_key("Sunrise Cellars"): ["001AAA"]}  # this company already has an Account

plan = classify_rows(rows, contacts_by_email, accounts_by_key)
disp = {rp.email: rp.disposition for rp in plan.rows if rp.email}

check("classify: net-new (new account)", disp.get("joe@gmail.com"), NET_NEW)
check("classify: matched contact", disp.get("bob@gmail.com"), MATCHED)
check("classify: multiple contacts", disp.get("dup@gmail.com"), MULTIPLE_CONTACTS)
check("classify: no-company -> needs_review", disp.get("nocomp@gmail.com"), NEEDS_REVIEW)
check("classify: no-contact-method -> needs_review", disp.get("nomethod@gmail.com"), NEEDS_REVIEW)

# counts
c = plan.counts
check("counts: net_new = 3", c["net_new"], 3)
check("counts: matched = 1", c["matched"], 1)
check("counts: matched_seed = 0 (the lone match is advanced)", c["matched_seed"], 0)
check("counts: multiple = 1", c["multiple_contacts"], 1)
check("counts: needs_review = 3", c["needs_review"], 3)
check("counts: review no_company = 1", c["review_no_company"], 1)
check("counts: review no_contact_method = 1", c["review_no_contact_method"], 1)
check("counts: review no_email = 1", c["review_no_email"], 1)
# Two net-new contacts share "Dubyk Winery" (new) → ONE new account, not two.
check("counts: accounts_new distinct = 1", c["accounts_new"], 1)
check("counts: accounts_matched = 1", c["accounts_matched"], 1)

# --- THE load-bearing invariant: held rows never reach the EB set -----------
eb_emails = {rp.email for rp in plan.eb_rows}
check("eb set excludes no-company", "nocomp@gmail.com" not in eb_emails, True)
check("eb set excludes no-contact-method", "nomethod@gmail.com" not in eb_emails, True)
check("eb set excludes no-email (empty)", all(rp.reason != "no_email" for rp in plan.eb_rows), True)
# net-new, matched, AND multiple all DO upload (the multiple row still sends)
check("eb set includes net-new", "joe@gmail.com" in eb_emails, True)
check("eb set includes matched", "bob@gmail.com" in eb_emails, True)
check("eb set includes multiple (still uploads)", "dup@gmail.com" in eb_emails, True)
check("eb count = total - needs_review", c["eb_upload"], c["total"] - c["needs_review"])
# every held row carries a reason; no uploads_to_eb row is needs_review
check("no needs_review row uploads", any(rp.uploads_to_eb and rp.disposition == NEEDS_REVIEW for rp in plan.rows), False)

# sidecar = needs_review + multiple (what the operator should look at)
sidecar_emails = {rp.email for rp in plan.sidecar_rows if rp.email}
check("sidecar includes the flagged multiple row", "dup@gmail.com" in sidecar_emails, True)
check("sidecar includes held rows", "nocomp@gmail.com" in sidecar_emails, True)
check("sidecar excludes clean net-new", "joe@gmail.com" not in sidecar_emails, True)

# --- net-new payload correctness --------------------------------------------
joe = next(rp for rp in plan.rows if rp.email == "joe@gmail.com")
check("net-new payload: person name", (joe.contact_first, joe.contact_last), ("Joe", "Dubyk"))
check("net-new payload: website cleaned, not free-email", joe.website, "dubykwinery.com")
check("net-new payload: account not matched (new)", joe.account_matched, False)
sue = next(rp for rp in plan.rows if rp.email == "sue@gmail.com")
check("net-new payload: account matched to existing", sue.account_matched, True)
check("net-new payload: matched account id", sue.account_id, "001AAA")
# a matched-contact row carries NO net-new payload (we leave it alone)
bob = next(rp for rp in plan.rows if rp.email == "bob@gmail.com")
check("matched row writes nothing", (bob.contact_last, bob.account_key, bob.website), ("", "", ""))

# --- a no-website row with a phone is NOT held (phone is a contact method) ---
plan2 = classify_rows([R(email="p@gmail.com", company="Phone Co", domain="", phone="801-555-1212")], {}, {})
check("phone alone → net-new, not held", plan2.rows[0].disposition, NET_NEW)
check("phone alone → phone carried", plan2.rows[0].phone, "801-555-1212")

# --- a net-new row whose COMPANY is a junk header token is HELD, not created --
# (BC-17213 review: _JUNK_COMPANY had drifted from _JUNK_NAMES, so "last_name"
# as a company slipped through as a NET_NEW row and would have been written.)
plan3 = classify_rows([R(email="hdr@gmail.com", company="last_name", domain="acme.com")], {}, {})
check("junk-company header token → needs_review, not net_new", plan3.rows[0].disposition, NEEDS_REVIEW)
check("junk-company header token → reason no_company", plan3.rows[0].reason, "no_company")
check("junk-company header token → held out of eb_rows",
      any(rp.email == "hdr@gmail.com" for rp in plan3.eb_rows), False)

# --- an ambiguous Account key (2+ existing) → create new, never a wrong merge --
# (BC-17213 Greptile: same-normalized-name collisions were silently reduced to
# one arbitrary Id; Q5 says an uncertain match creates new.)
amb_key = company_match_key("Ambi Co")
plan4 = classify_rows([R(email="a@gmail.com", company="Ambi Co", domain="ambico.com")],
                      {}, {amb_key: ["001AAA", "001BBB"]})
r4 = plan4.rows[0]
check("ambiguous account → net_new", r4.disposition, NET_NEW)
check("ambiguous account → not matched (create new)", r4.account_matched, False)
check("ambiguous account → no account_id attached", r4.account_id, "")
check("ambiguous account → flagged ambiguous", r4.account_ambiguous, True)
check("ambiguous account → counted, creates a new account", plan4.counts["accounts_ambiguous"], 1)
check("ambiguous account → still counted as a new account", plan4.counts["accounts_new"], 1)
# exactly-one match still attaches, and is not flagged ambiguous
plan5 = classify_rows([R(email="s@gmail.com", company="Single Co", domain="singleco.com")],
                      {}, {company_match_key("Single Co"): ["001CCC"]})
check("single match → attached", plan5.rows[0].account_matched, True)
check("single match → id carried", plan5.rows[0].account_id, "001CCC")
check("single match → not ambiguous", plan5.rows[0].account_ambiguous, False)

# --- matched-both-null seeding (BC-17347, ADR-037 D1/D2) --------------------
# A single matched Contact that is null on BOTH governed fields is seeded to the
# floor (null -> Cold_Prospect/New); if EITHER field is non-null it is left
# entirely untouched (opt-out safety, D2 — assessed together, never per-field).
# The lone match here is null on both -> MATCHED_SEED, carries its id, uploads.
plan_seed = classify_rows(
    [R(email="seed@gmail.com", company="Seed Co", domain="seedco.com")],
    {"seed@gmail.com": [MatchedContact("003SEED", None, None)]}, {})
rseed = plan_seed.rows[0]
check("both-null match -> MATCHED_SEED", rseed.disposition, MATCHED_SEED)
check("MATCHED_SEED carries the contact id (to target the UPDATE)", rseed.contact_id, "003SEED")
check("MATCHED_SEED still uploads to EB", rseed.uploads_to_eb, True)
check("MATCHED_SEED in eb_rows", any(rp.email == "seed@gmail.com" for rp in plan_seed.eb_rows), True)
check("MATCHED_SEED NOT in sidecar (clean write, not a review row)",
      any(rp.email == "seed@gmail.com" for rp in plan_seed.sidecar_rows), False)
check("counts: matched_seed = 1", plan_seed.counts["matched_seed"], 1)
check("counts: a seeded match is not counted as a plain match", plan_seed.counts["matched"], 0)
# blank strings (not just None) also read as unseeded
plan_blank = classify_rows(
    [R(email="blank@gmail.com", company="Blank Co", domain="blankco.com")],
    {"blank@gmail.com": [MatchedContact("003BLANK", "", "  ")]}, {})
check("blank-string both-null -> MATCHED_SEED", plan_blank.rows[0].disposition, MATCHED_SEED)

# Fail-closed (BC-17347 review): a both-null match with NO contact Id must NOT
# seed — an empty write target is a permissive default reaching the write branch
# (same shape as the BC-17336 fail-open). Falls through to MATCHED (untouched) =
# the safe direction. Can't arise from real SOQL (Id always present); defensive.
plan_noid = classify_rows(
    [R(email="noid@gmail.com", company="NoId Co", domain="noidco.com")],
    {"noid@gmail.com": [MatchedContact("", None, None)]}, {})
check("both-null but empty contact_id -> MATCHED (fail-closed, not seeded)",
      plan_noid.rows[0].disposition, MATCHED)
check("fail-closed row not counted as matched_seed", plan_noid.counts["matched_seed"], 0)

# --- THE suppression test the acceptance criterion requires (BC-17213) -------
# A matched Do_Not_Prospect (stage) + null status must be left ENTIRELY
# untouched: stamping New would re-enter the BDR queue (queues key on status) =
# opt-out breach. The two axes are assessed TOGETHER (stage non-null -> skip both).
plan_supp = classify_rows(
    [R(email="dnp@gmail.com", company="DNP Co", domain="dnpco.com")],
    {"dnp@gmail.com": [MatchedContact("003DNP", "Do_Not_Prospect", None)]}, {})
rsupp = plan_supp.rows[0]
check("suppressed (Do_Not_Prospect + null status) -> MATCHED, not seeded", rsupp.disposition, MATCHED)
check("suppressed row writes nothing (no contact id carried)", rsupp.contact_id, "")
check("suppressed row not counted as matched_seed", plan_supp.counts["matched_seed"], 0)

# --- one-axis-null is NOT seeded (never top up a single axis) ----------------
plan_stage_null = classify_rows(
    [R(email="a@gmail.com", company="A Co", domain="aco.com")],
    {"a@gmail.com": [MatchedContact("003A", None, "Working")]}, {})
check("stage-null / status-set -> MATCHED (no part-seed)", plan_stage_null.rows[0].disposition, MATCHED)
plan_status_null = classify_rows(
    [R(email="b@gmail.com", company="B Co", domain="bco.com")],
    {"b@gmail.com": [MatchedContact("003B", "MQL", None)]}, {})
check("status-null / stage-set -> MATCHED (no part-seed)", plan_status_null.rows[0].disposition, MATCHED)

# --- >1 match is MULTIPLE even when both-null (dedup first, never seed) -------
plan_multi_null = classify_rows(
    [R(email="m@gmail.com", company="M Co", domain="mco.com")],
    {"m@gmail.com": [MatchedContact("003M1", None, None), MatchedContact("003M2", None, None)]}, {})
check(">1 both-null match -> MULTIPLE_CONTACTS (not seeded)",
      plan_multi_null.rows[0].disposition, MULTIPLE_CONTACTS)


print(f"\nRESULT pass={_pass} fail={_fail}")
sys.exit(1 if _fail else 0)
PY
