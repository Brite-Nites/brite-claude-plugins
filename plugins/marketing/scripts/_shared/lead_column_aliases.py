"""VENDORED SNAPSHOT — do not hand-edit. Refresh from source (see below).

This is a faithful copy of the `COLUMN_ALIASES` header-alias table from the
Brite data platform, the team's authoritative "which header spelling means
what" reference. It is REFERENCE DATA, not logic: "Organization" means company
regardless of which system consumes it, so the same table serves the data
platform's enrichment ingest and this plugin's Salesforce pre-load. Rather than
hand-maintain a competing, thinner list, we vendor theirs.

Why a copy and not an import: the data platform is a separate Poetry/Snowflake
service with no import path into this stdlib-only plugin, and the cross-repo
import mechanism was withdrawn (brite-salesforce ADR-001). Copying published
reference data — with provenance and a refresh procedure — is the sanctioned
alternative, not the withdrawn thing. The use-case-specific glue (which fields
this plugin requires, how it treats ambiguous `name`, the Salesforce match
normalization) lives in `column_map.py`, NOT here — see that module.

PROVENANCE
  source repo   : brite-data-platform
  source file   : services/enrichment/loaders/csv_loader.py
  source symbol : COLUMN_ALIASES
  last upstream change : commit 7ae0b862b44c330f3d9069ed900c2631c61e74e1 (2026-06-26)
  snapshot taken at    : HEAD eb7286b

REFRESH
  Re-extract the upstream `COLUMN_ALIASES` dict, replace the literal below
  verbatim, and update the two provenance lines. Then run
  `test_column_map.sh`. There is no automatic cross-repo parity check — the
  plugin's CI does not have the data platform checked out — so refresh is a
  manual, provenance-stamped step. Keep the dict byte-faithful to upstream so a
  future diff is meaningful; put every plugin-specific decision in column_map.py.

The keys are already normalized upstream (lowercased, spaces preserved). This
module's consumer re-normalizes headers the same way before lookup, so the
exact whitespace form here is not load-bearing — faithfulness to upstream is.
"""

from __future__ import annotations

#: Verbatim snapshot of brite-data-platform COLUMN_ALIASES. Values are the data
#: platform's OWN canonical field keys (UPPERCASE). column_map.py projects the
#: subset this plugin needs onto its own vocabulary; unprojected keys (SENIORITY,
#: COMPANY_REVENUE, ICP_FIT, …) are simply ignored here, which is correct — the
#: pre-load has no use for them.
VENDORED_ALIASES: dict[str, str] = {
    # First name
    "first name": "FIRST_NAME",
    "first_name": "FIRST_NAME",
    "firstname": "FIRST_NAME",
    "given name": "FIRST_NAME",
    "given_name": "FIRST_NAME",
    "person first name": "FIRST_NAME",
    # Last name
    "last name": "LAST_NAME",
    "last_name": "LAST_NAME",
    "lastname": "LAST_NAME",
    "surname": "LAST_NAME",
    "family name": "LAST_NAME",
    "family_name": "LAST_NAME",
    "person last name": "LAST_NAME",
    # Full name
    "full name": "FULL_NAME",
    "full_name": "FULL_NAME",
    "fullname": "FULL_NAME",
    "name": "FULL_NAME",
    "person name": "FULL_NAME",
    "contact name": "FULL_NAME",
    # Company name
    "company name": "COMPANY_NAME",
    "company_name": "COMPANY_NAME",
    "companyname": "COMPANY_NAME",
    "company": "COMPANY_NAME",
    "organization": "COMPANY_NAME",
    "organization name": "COMPANY_NAME",
    "organisation": "COMPANY_NAME",
    "org name": "COMPANY_NAME",
    "account name": "COMPANY_NAME",
    "business name": "COMPANY_NAME",
    "place name": "COMPANY_NAME",
    # Domain
    "domain": "DOMAIN",
    "company domain": "DOMAIN",
    "company_domain": "DOMAIN",
    "companydomain": "DOMAIN",
    "website domain": "DOMAIN",
    "website_domain": "DOMAIN",
    # Company website
    "company website": "COMPANY_WEBSITE",
    "company_website": "COMPANY_WEBSITE",
    "website": "COMPANY_WEBSITE",
    "website url": "COMPANY_WEBSITE",
    "url": "COMPANY_WEBSITE",
    "company url": "COMPANY_WEBSITE",
    # Email (pre-enrichment existing email)
    "email": "EMAIL",
    "email address": "EMAIL",
    "email_address": "EMAIL",
    "contact email": "EMAIL",
    "primary email": "EMAIL",
    "general email": "EMAIL",
    "general_email": "EMAIL",
    "company email": "EMAIL",
    # Personal email
    "personal email": "PERSONAL_EMAIL",
    "personal_email": "PERSONAL_EMAIL",
    "personal email address": "PERSONAL_EMAIL",
    # Phone
    "phone": "PHONE",
    "phone number": "PHONE",
    "phone_number": "PHONE",
    "mobile": "PHONE",
    "mobile number": "PHONE",
    "mobile_number": "PHONE",
    "mobile phone": "PHONE",
    "cell": "PHONE",
    "cell phone": "PHONE",
    "direct phone": "PHONE",
    "person phone": "PHONE",
    # LinkedIn URL
    "linkedin": "LINKEDIN_URL",
    "linkedin url": "LINKEDIN_URL",
    "linkedin_url": "LINKEDIN_URL",
    "linkedinurl": "LINKEDIN_URL",
    "linkedin profile": "LINKEDIN_URL",
    "person linkedin url": "LINKEDIN_URL",
    "person linkedin": "LINKEDIN_URL",
    # Title
    "title": "TITLE",
    "job title": "TITLE",
    "job_title": "TITLE",
    "jobtitle": "TITLE",
    "position": "TITLE",
    "role": "TITLE",
    "person title": "TITLE",
    # Seniority
    "seniority": "SENIORITY",
    "seniority level": "SENIORITY",
    "seniority_level": "SENIORITY",
    # Department
    "department": "DEPARTMENT",
    "dept": "DEPARTMENT",
    # Headline
    "headline": "HEADLINE",
    "person headline": "HEADLINE",
    # Industry
    "industry": "INDUSTRY",
    "company industry": "INDUSTRY",
    # Business category
    "business category": "BUSINESS_CATEGORY",
    "business_category": "BUSINESS_CATEGORY",
    "category": "BUSINESS_CATEGORY",
    "google category": "BUSINESS_CATEGORY",
    "google places category": "BUSINESS_CATEGORY",
    "google_places_category": "BUSINESS_CATEGORY",
    "place category": "BUSINESS_CATEGORY",
    # City (person)
    "city": "CITY",
    "person city": "CITY",
    # State (person)
    "state": "STATE",
    "person state": "STATE",
    "region": "STATE",
    # Country
    "country": "COUNTRY",
    "person country": "COUNTRY",
    # Employees
    "employees count": "EMPLOYEES_COUNT",
    "employees_count": "EMPLOYEES_COUNT",
    "employee count": "EMPLOYEES_COUNT",
    "employees": "EMPLOYEES_COUNT",
    "# employees": "EMPLOYEES_COUNT",
    "company size": "EMPLOYEES_COUNT",
    "headcount": "EMPLOYEES_COUNT",
    # Revenue
    "company annual revenue clean": "COMPANY_REVENUE",
    "company_revenue": "COMPANY_REVENUE",
    "revenue": "COMPANY_REVENUE",
    "annual revenue": "COMPANY_REVENUE",
    "estimated revenue": "COMPANY_REVENUE",
    # Founded year
    "company founded year": "COMPANY_FOUNDED_YEAR",
    "company_founded_year": "COMPANY_FOUNDED_YEAR",
    "founded year": "COMPANY_FOUNDED_YEAR",
    "founded": "COMPANY_FOUNDED_YEAR",
    "year founded": "COMPANY_FOUNDED_YEAR",
    # Apollo IDs
    "person id": "APOLLO_PERSON_ID",
    "apollo person id": "APOLLO_PERSON_ID",
    "apollo_person_id": "APOLLO_PERSON_ID",
    "company id": "APOLLO_COMPANY_ID",
    "apollo company id": "APOLLO_COMPANY_ID",
    "apollo_company_id": "APOLLO_COMPANY_ID",
    # Company LinkedIn
    "company linkedin": "COMPANY_LINKEDIN_URL",
    "company_linkedin_url": "COMPANY_LINKEDIN_URL",
    "company linkedin url": "COMPANY_LINKEDIN_URL",
    # Company phone
    "company phone number": "COMPANY_PHONE",
    "company_phone": "COMPANY_PHONE",
    "company phone": "COMPANY_PHONE",
    "business phone": "COMPANY_PHONE",
    "main phone": "COMPANY_PHONE",
    # Company address
    "company street address": "COMPANY_STREET_ADDRESS",
    "company_street_address": "COMPANY_STREET_ADDRESS",
    "company address": "COMPANY_STREET_ADDRESS",
    "company_address": "COMPANY_STREET_ADDRESS",
    "street address": "COMPANY_STREET_ADDRESS",
    "address": "COMPANY_STREET_ADDRESS",
    # Company city
    "company city": "COMPANY_CITY",
    "company_city": "COMPANY_CITY",
    # Company state
    "company state": "COMPANY_STATE",
    "company_state": "COMPANY_STATE",
    # Company postal code
    "company postal code": "COMPANY_POSTAL_CODE",
    "company_postal_code": "COMPANY_POSTAL_CODE",
    "company zip": "COMPANY_POSTAL_CODE",
    "company zip code": "COMPANY_POSTAL_CODE",
    "postal code": "COMPANY_POSTAL_CODE",
    "zip": "COMPANY_POSTAL_CODE",
    "zip code": "COMPANY_POSTAL_CODE",
    # Email enrichment
    "work_email": "WORK_EMAIL",
    "work email": "WORK_EMAIL",
    "professional_email": "WORK_EMAIL",
    "professional email": "WORK_EMAIL",
    "verified_email": "WORK_EMAIL",
    "email_deliverable": "EMAIL_DELIVERABLE",
    "email deliverable": "EMAIL_DELIVERABLE",
    "email_valid": "EMAIL_DELIVERABLE",
    "email valid": "EMAIL_DELIVERABLE",
    "deliverable": "EMAIL_DELIVERABLE",
    "email_is_role": "EMAIL_IS_ROLE",
    "email is role": "EMAIL_IS_ROLE",
    "is_role": "EMAIL_IS_ROLE",
    "email_is_free": "EMAIL_IS_FREE",
    "email is free": "EMAIL_IS_FREE",
    "is_free": "EMAIL_IS_FREE",
    # ICP / Persona qualification
    "icp_fit": "ICP_FIT",
    "icp fit": "ICP_FIT",
    "icp": "ICP_FIT",
    "company is icp?": "ICP_FIT",
    "persona_fit": "PERSONA_FIT",
    "persona fit": "PERSONA_FIT",
    "persona fit?": "PERSONA_FIT",
}
