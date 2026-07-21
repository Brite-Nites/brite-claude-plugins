#!/usr/bin/env bash
# Behavioral tests for _shared/column_map.py (BC-17213).
#
# The cases are the REAL headers from the lead files in docs/campaigns/ — an
# Apollo export, a senior-living roster, a Serper scrape, the local-retail
# upload. A mapper that passes on invented headers and fails on the operator's
# actual files would be worse than useless.
#
# As of BC-17213 the alias coverage comes from the VENDORED data-platform table
# (_shared/lead_column_aliases.py); this module projects it onto the pre-load's
# fields and keeps `name` deliberately ambiguous. These tests pin both.
#
# Emits `RESULT pass=N fail=M` for validate.sh to grep.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$SCRIPT_DIR" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])

from _shared.column_map import (
    COMPANY, DOMAIN, EMAIL, FIRST_NAME, FULL_NAME, LAST_NAME, PHONE, TITLE,
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


# --- vendored-table coverage we did NOT have before -------------------------
# These spellings come free from adopting the data platform's table.
for header in ["Organization", "Organisation", "Org Name", "Account Name",
               "Business Name", "Place Name", "companyname"]:
    r = resolve(["email", "domain", header])
    check(f"vendored: {header!r} -> company", r.resolved.get(COMPANY), header)

# --- real file: local-retail Utah upload ------------------------------------
# Maps cleanly, zero questions. `role` here is a role-address flag (not a job
# title), so it is a documented ignore-deviation — `title` resolves from the
# `title` column and `role` is set aside rather than colliding with it.
LOCAL_RETAIL = "company,city,industry,domain,title,first_name,last_name,email,esp,accept_all,role,bb_score".split(",")
r = resolve(LOCAL_RETAIL)
check("local-retail: no questions", r.needs_operator, False)
check("local-retail: company", r.resolved.get(COMPANY), "company")
check("local-retail: domain", r.resolved.get(DOMAIN), "domain")
check("local-retail: email", r.resolved.get(EMAIL), "email")
check("local-retail: title resolves from `title`, not `role`", r.resolved.get(TITLE), "title")
truthy("local-retail: `role` set aside (ignore-deviation)", "role" in r.unmapped)
# city/industry are recognised-but-unused → ignored.
truthy("local-retail: `city` in unmapped", "city" in r.unmapped)
truthy("local-retail: `esp` in unmapped (unknown)", "esp" in r.unmapped)

# --- real file: senior-living roster ----------------------------------------
# The case that motivated the design: the business is called `name`, and no
# header tells you whether that's a company or a person.
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
# Noise reduction: recognised-but-unused columns are NOT offered as candidates.
truthy("senior-living: `city` NOT a candidate", "city" not in company_qs[0].candidates)
truthy("senior-living: `zip` NOT a candidate", "zip" not in company_qs[0].candidates)
# Never silently guess `name` -> company (or -> person).
truthy("senior-living: company NOT auto-resolved", COMPANY not in r.resolved)
truthy("senior-living: `name` not silently read as a person", FULL_NAME not in r.resolved)

# --- real file: Apollo export -----------------------------------------------
APOLLO = ("First Name,Last Name,Company Name,Company Website,Email,Mobile Number,Personal Email,"
          "Full Name,LinkedIn,Title,Industry,Company Phone Number,Company Domain").split(",")
r = resolve(APOLLO)
check("apollo: Company Name -> company", r.resolved.get(COMPANY), "Company Name")
check("apollo: First Name -> first_name", r.resolved.get(FIRST_NAME), "First Name")
check("apollo: Last Name -> last_name", r.resolved.get(LAST_NAME), "Last Name")
check("apollo: Title -> title", r.resolved.get(TITLE), "Title")
# `Full Name` now resolves (vendored table) instead of being dropped.
check("apollo: Full Name -> full_name", r.resolved.get(FULL_NAME), "Full Name")
# `Company Website` and `Company Domain` both project to `domain` → collision.
domain_qs = [a for a in r.ambiguities if a.field == DOMAIN]
check("apollo: domain collision raised", len(domain_qs), 1)
check("apollo: both domain headers offered",
      sorted(domain_qs[0].candidates), ["Company Domain", "Company Website"])
# `Mobile Number` (person phone) and `Company Phone Number` both project to phone.
phone_qs = [a for a in r.ambiguities if a.field == PHONE]
check("apollo: phone collision raised", len(phone_qs), 1)
# `Personal Email` is a DIFFERENT address; NOT projected to email.
check("apollo: Email wins, not Personal Email", r.resolved.get(EMAIL), "Email")
truthy("apollo: `Personal Email` left unmapped", "Personal Email" in r.unmapped)

# --- real file: multi-property apartments -----------------------------------
# Has no usable email column — `public_emails` is not an email header.
APARTMENTS = ("company_name,domain,qualification,nmhc_owner_rank,ceo,city,state,phone,"
              "employees,revenue_range,company_linkedin,public_emails").split(",")
r = resolve(APARTMENTS)
check("apartments: company_name -> company", r.resolved.get(COMPANY), "company_name")
check("apartments: domain", r.resolved.get(DOMAIN), "domain")
email_qs = [a for a in r.ambiguities if a.field == EMAIL]
check("apartments: asks about email", len(email_qs), 1)
truthy("apartments: `public_emails` offered as email candidate", "public_emails" in email_qs[0].candidates)
truthy("apartments: `employees` NOT a candidate (recognised-unused)", "employees" not in email_qs[0].candidates)

# --- real file: Serper scrape -----------------------------------------------
SERPER = "domain,company_name,state,city,district,industry,email,phone,address,zip,source".split(",")
r = resolve(SERPER)
check("serper: no questions", r.needs_operator, False)
check("serper: company_name -> company", r.resolved.get(COMPANY), "company_name")

# --- launch-campaign's own documented contract ------------------------------
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
check("normalize: `company` resolves, `name` does not", r.resolved.get(COMPANY), "company")
truthy("normalize: `name` stays unmapped when `company` exists", "name" in r.unmapped)

# --- contact method ---------------------------------------------------------
r = resolve(["email", "company", "first_name"])
truthy("no contact method: raises a question", r.needs_operator)
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
