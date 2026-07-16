#!/usr/bin/env bash
# Behavioral tests for _shared/column_map.py (BC-17213).
#
# The cases are the REAL headers from the lead files in docs/campaigns/ — an
# Apollo export, a senior-living roster, a Serper scrape, the local-retail
# upload. A mapper that passes on invented headers and fails on Corinne's
# actual files would be worse than useless.
#
# Emits `RESULT pass=N fail=M` for validate.sh to grep.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$SCRIPT_DIR" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])

from _shared.column_map import (
    COMPANY, DOMAIN, EMAIL, FIRST_NAME, LAST_NAME, PHONE, TITLE,
    apply, resolve, samples_for,
)

_pass = _fail = 0


def check(name, got, want):
    global _pass, _fail
    if got == want:
        _pass += 1
        print(f"  ok   {name}")
    else:
        _fail += 1
        print(f"  FAIL {name}\n         got:  {got!r}\n         want: {want!r}")


def truthy(name, cond):
    check(name, bool(cond), True)


# --- real file: local-retail Utah upload ------------------------------------
# The happy path. Every column recognised, operator asked nothing.
LOCAL_RETAIL = "company,city,industry,domain,title,first_name,last_name,email,esp,accept_all,role,bb_score".split(",")
r = resolve(LOCAL_RETAIL)
check("local-retail: no questions", r.needs_operator, False)
check("local-retail: company", r.resolved.get(COMPANY), "company")
check("local-retail: domain", r.resolved.get(DOMAIN), "domain")
check("local-retail: email", r.resolved.get(EMAIL), "email")
check("local-retail: title", r.resolved.get(TITLE), "title")
# `role` here is a role-address boolean, NOT a job title. Mapping it to title
# would put "TRUE" in the contact's job title.
truthy("local-retail: `role` left unmapped", "role" in r.unmapped)
truthy("local-retail: `bb_score` left unmapped", "bb_score" in r.unmapped)

# --- real file: senior-living roster ----------------------------------------
# The case that motivated the whole design: the business is called `name`, and
# no header tells you whether that's a company or a person.
SENIOR_LIVING = ("tier,lux_score,lux_why,name,city,state,zip,territory,addr,phone,email,admin,"
                 "beds,operator,lux_operator,brand_tier,ftype,is_ccrc,extra,median_home_value,"
                 "median_hh_income,rankings,n_rankings,website,sources").split(",")
r = resolve(SENIOR_LIVING)
truthy("senior-living: asks about company", r.needs_operator)
check("senior-living: email auto-resolves", r.resolved.get(EMAIL), "email")
check("senior-living: website -> domain", r.resolved.get(DOMAIN), "website")
check("senior-living: phone auto-resolves", r.resolved.get(PHONE), "phone")
company_qs = [a for a in r.ambiguities if a.field == COMPANY]
check("senior-living: exactly one company question", len(company_qs), 1)
check("senior-living: reason is unresolved", company_qs[0].reason, "unresolved")
truthy("senior-living: `name` offered as a candidate", "name" in company_qs[0].candidates)
truthy("senior-living: `admin` offered too", "admin" in company_qs[0].candidates)
# Never silently guess `name` -> company.
truthy("senior-living: company NOT auto-resolved", COMPANY not in r.resolved)

# --- real file: Apollo export -----------------------------------------------
# Carries two headers for the same concept, twice over.
APOLLO = ("First Name,Last Name,Company Name,Company Website,Email,Mobile Number,Personal Email,"
          "Full Name,LinkedIn,Title,Industry,Company Phone Number,Company Domain").split(",")
r = resolve(APOLLO)
check("apollo: Company Name -> company", r.resolved.get(COMPANY), "Company Name")
check("apollo: First Name -> first_name", r.resolved.get(FIRST_NAME), "First Name")
check("apollo: Last Name -> last_name", r.resolved.get(LAST_NAME), "Last Name")
check("apollo: Title -> title", r.resolved.get(TITLE), "Title")
# `Company Website` and `Company Domain` are different values (protocol, www).
# Picking one by position is a coin flip on what lands in Salesforce.
domain_qs = [a for a in r.ambiguities if a.field == DOMAIN]
check("apollo: domain collision raised", len(domain_qs), 1)
check("apollo: collision reason", domain_qs[0].reason, "collision")
check("apollo: both domain headers offered",
      sorted(domain_qs[0].candidates), ["Company Domain", "Company Website"])
phone_qs = [a for a in r.ambiguities if a.field == PHONE]
check("apollo: phone collision raised", len(phone_qs), 1)
# `Personal Email` is a DIFFERENT address from `Email`. Mapping it would
# silently retarget the campaign.
check("apollo: Email wins, not Personal Email", r.resolved.get(EMAIL), "Email")
truthy("apollo: `Personal Email` left unmapped", "Personal Email" in r.unmapped)
truthy("apollo: `Full Name` left unmapped", "Full Name" in r.unmapped)

# --- real file: multi-property apartments -----------------------------------
# Has no email column at all — `public_emails` is something else.
APARTMENTS = ("company_name,domain,qualification,nmhc_owner_rank,ceo,city,state,phone,"
              "employees,revenue_range,company_linkedin,public_emails").split(",")
r = resolve(APARTMENTS)
check("apartments: company_name -> company", r.resolved.get(COMPANY), "company_name")
check("apartments: domain", r.resolved.get(DOMAIN), "domain")
email_qs = [a for a in r.ambiguities if a.field == EMAIL]
check("apartments: asks about email", len(email_qs), 1)
truthy("apartments: `public_emails` NOT auto-mapped", "public_emails" in r.unmapped)

# --- real file: Serper scrape -----------------------------------------------
SERPER = "domain,company_name,state,city,district,industry,email,phone,address,zip,source".split(",")
r = resolve(SERPER)
check("serper: no questions", r.needs_operator, False)
check("serper: company_name -> company", r.resolved.get(COMPANY), "company_name")

# --- launch-campaign's own documented contract ------------------------------
# The column names Phase 1 currently demands must keep working.
LAUNCH_CONTRACT = "email,first_name,last_name,job_title,company_name,company_domain".split(",")
r = resolve(LAUNCH_CONTRACT)
check("launch contract: no questions", r.needs_operator, False)
check("launch contract: company_domain -> domain", r.resolved.get(DOMAIN), "company_domain")
check("launch contract: job_title -> title", r.resolved.get(TITLE), "job_title")

# --- normalization ----------------------------------------------------------
for spelling in ("Company Name", "company_name", "company-name", "COMPANY NAME", " Company  Name "):
    r = resolve(["email", "domain", spelling])
    check(f"normalize: {spelling!r} -> company", r.resolved.get(COMPANY), spelling)
# Folding punctuation must not collapse distinct concepts.
r = resolve(["email", "domain", "company", "name"])
check("normalize: `company` and `name` stay distinct", r.resolved.get(COMPANY), "company")
truthy("normalize: `name` stays unmapped when `company` exists", "name" in r.unmapped)

# --- contact method ---------------------------------------------------------
# Neither domain nor phone: every row would fail Salesforce's
# Account_Contact_Method_Required and land in needs-review. Say so up front.
r = resolve(["email", "company", "first_name"])
truthy("no contact method: raises a question", r.needs_operator)
# Either one alone is enough — the per-row cascade handles the rest.
r = resolve(["email", "company", "phone"])
check("phone alone satisfies contact method", r.needs_operator, False)
r = resolve(["email", "company", "website"])
check("domain alone satisfies contact method", r.needs_operator, False)

# --- samples_for ------------------------------------------------------------
rows = [
    {"name": "Sunrise of Bellevue"},
    {"name": ""},
    {"name": "Sunrise of Bellevue"},
    {"name": "  Brookdale Meridian  "},
    {"name": "The Gardens at Town Square"},
    {"name": "Legacy Village"},
]
check("samples: skips blanks + dupes, trims, caps at 3",
      samples_for("name", rows),
      ["Sunrise of Bellevue", "Brookdale Meridian", "The Gardens at Town Square"])
check("samples: missing column -> empty", samples_for("nope", rows), [])
check("samples: honors limit", len(samples_for("name", rows, limit=2)), 2)

# --- apply ------------------------------------------------------------------
r = resolve(SENIOR_LIVING)
merged = apply(r, {COMPANY: "name"})
check("apply: operator's choice lands", merged.get(COMPANY), "name")
check("apply: auto-resolved survive", merged.get(EMAIL), "email")
check("apply: empty choice means ignore", apply(r, {COMPANY: ""}).get(COMPANY), None)
check("apply: does not mutate the resolution", COMPANY in r.resolved, False)

print(f"\nRESULT pass={_pass} fail={_fail}")
sys.exit(1 if _fail else 0)
PY
