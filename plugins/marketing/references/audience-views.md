# Audience views

Catalog of Snowflake views the marketing plugin's skills read from when assembling outbound lists. View design + refresh are owned by the **GTM Intelligence** Linear project (Corinne Brewer, lead); the marketing plugin is a **consumer**, not an author.

This catalog is the canonical answer to "what view should `list-building` point at?" Skills that pass `--audience-view-name <name>` (Source 2 manual export today; Source 4 direct query per [ADR-030](../../../docs/decisions/030-marketing-snowflake-access.md) tomorrow) MUST cite a view from this catalog.

## What is an audience view?

The `brite-data-platform` dbt project ([repo](https://github.com/Brite-Nites/brite-data-platform)) materializes two tiers in Snowflake that this plugin reads:

- **Golden records** (`dim_people`, `dim_companies`) — one row per unique person/company, built by the enrichment waterfall ([BC-1154](https://linear.app/brite-nites/issue/BC-1154)), survivorship rules, and quality scoring. Source of truth for "everything we know about this person/company." Wide schema, no opinion about who's ready for outbound.
- **Audience views** (`audience_*`) — segment-scoped, quality-gated, ready-to-send slices of the golden record. Each view encodes a campaign intent: "people we can send a commercial outreach to right now." Narrower schema (only the columns outbound needs), filtered by quality score + completeness + freshness rules per [BC-2311](https://linear.app/brite-nites/issue/BC-2311) (quality-gate thresholds).

`list-building` consumes both tiers, but for different reasons:

- An **audience view** is the right input when the campaign's segment matches a published view exactly (e.g., generic commercial outreach → `audience_commercial_outreach`). Filtering is already done in dbt; the skill just consumes.
- A **golden record** read (`dim_people` / `dim_companies`) is the right input when the campaign needs a one-off slice that no view yet covers, OR when the skill is doing its own quality gate (e.g., `prospect-temporal-gate` checking domain coverage). The skill applies its own WHERE predicate.

Per [ADR-030](../../../docs/decisions/030-marketing-snowflake-access.md), the marketing plugin reads Snowflake via a `snow` CLI wrapper (`plugins/marketing/scripts/snowflake/query_audience.py`) credentialed through `bw-run.sh`. The wrapper validates the view name against the **allowlist** below before issuing the query.

## Catalog

| Name | Tier | Status | Purpose | Owner | Refresh | Consumer skill |
|---|---|---|---|---|---|---|
| `dim_people` | Golden record | Live | Per-person canonical record with full enrichment | Corinne ([BC-1447](https://linear.app/brite-nites/issue/BC-1447)) | Daily (dbt) | `list-building` Source 2/4 (cost gate **requires explicit `--snowflake-limit`**), `prospect-temporal-gate` (future) |
| `dim_companies` | Golden record | Live | Per-company canonical record with firmographics + tech stack | Corinne ([BC-1446](https://linear.app/brite-nites/issue/BC-1446)) | Daily (dbt) | `list-building` Source 2/4 (cost gate **requires explicit `--snowflake-limit`**) |
| `audience_commercial_outreach` | Audience view | **Planned** ([BC-2314](https://linear.app/brite-nites/issue/BC-2314)) | Quality-gated, dedup'd commercial outreach list ready for EB | Corinne ([BC-2314](https://linear.app/brite-nites/issue/BC-2314)) | TBD when [BC-2314](https://linear.app/brite-nites/issue/BC-2314) lands | `list-building` Source 4 (after [BC-11929](https://linear.app/brite-nites/issue/BC-11929)); cost-gate default 5000 sufficient |

**Cost-gate note for golden records.** `dim_people` and `dim_companies` are full tables (100k+ rows each), so the default 5000-row cost gate (per [Source 4 design § 5](../../../docs/designs/source-4-list-building-snowflake.md)) will always halt without an explicit `--snowflake-limit`. This is the intended discipline: operators consuming golden records MUST decide upfront how many rows they need. Audience views (`audience_*`) are pre-filtered to outbound-ready slices, so the default gate is appropriate.

Future entries are appended as new views ship; the table is the allowlist.

## Live views — schema reference

### `dim_people`

Per-person golden record. One row per unique entity_id. Built from `int_people_enriched` (Apollo + HubSpot + Clay sources) deduplicated by `(domain, name, linkedin_url)`. Full source: [`models/marts/dim_people.sql`](https://github.com/Brite-Nites/brite-data-platform/blob/main/models/marts/dim_people.sql).

Load-bearing columns for outbound consumption:

| Column | Type | Notes |
|---|---|---|
| `person_id` | string (surrogate) | dbt-utils surrogate key over `entity_id` |
| `entity_id` | string | Stable upstream entity id |
| `company_id` | string | FK to `dim_companies.company_id` |
| `source_system` | string | `apollo` / `hubspot` / `clay` / etc. |
| `first_name`, `last_name`, `full_name` | string | Coalesced; full_name back-filled from first + last when missing |
| `existing_email` | string | Pre-enrichment email (Clay-imported) |
| `linkedin_url` | string | Coalesces enriched + raw |
| `title`, `seniority_level`, `headline` | string | Decision-maker classification |
| `company_name` | string | Substitutes canonical org name when person's company_name is a department label |
| `domain`, `company_website`, `company_phone`, `company_linkedin_url` | string | Employment context |
| `work_email` | string | **Per [BC-6898](https://linear.app/brite-nites/issue/BC-6898)**: coalesces `enriched_work_email > entity_work_email > existing_email`. Use this, not `existing_email`, when sending. |
| `work_email_status` | enum | `verified` / `enriched` / `scraped`. Only `verified` should bypass SMTP re-check. |

Quality / freshness columns (`data_quality_score`, `first_seen_at`, etc.) live further down the model — see source for the full surface.

### `dim_companies`

Per-company golden record. One row per unique entity_id. Built from `int_companies_deduped` with survivorship rules already applied. Full source: [`models/marts/dim_companies.sql`](https://github.com/Brite-Nites/brite-data-platform/blob/main/models/marts/dim_companies.sql).

Load-bearing columns:

| Column | Type | Notes |
|---|---|---|
| `company_id` | string (surrogate) | dbt-utils surrogate key over `entity_id` |
| `entity_id` | string | Stable upstream entity id |
| `company_name`, `domain`, `company_website` | string | Identity |
| `company_phone`, `company_phone_is_valid`, `company_phone_line_type`, `company_phone_is_textable` | string / bool | Per [BC-6897](https://linear.app/brite-nites/issue/BC-6897) general-email pattern |
| `general_email`, `general_email_is_role`, `general_email_is_free`, `general_email_deliverable` | string / bool | Fallback contact channel when no decision-maker is enriched |
| `street_address`, `city`, `state`, `postal_code` | string | Location |
| `industry`, `business_category` | string | Classification |
| `employees_count`, `revenue`, `founded_year` | int / string / int | Firmographics |
| `tech_stack_technologies`, `tech_stack_cms`, `tech_stack_email_provider` | string | NULL until [BRI-1458](https://linear.app/brite-nites/issue/BC-1458) |
| `data_quality_score` | int (0–100) | 10 core fields × 10 points. Use as a coarse filter; combine with persona-specific checks. |
| `source_record_count`, `source_systems` | int / array | Audit |

## Planned views — `audience_commercial_outreach`

Status: **not yet built.** Tracked at [BC-2314](https://linear.app/brite-nites/issue/BC-2314) under GTM Intelligence. The view will be the canonical input for commercial outbound — quality-gated, deduplicated, push-ready.

Specified intent (from [BC-2314](https://linear.app/brite-nites/issue/BC-2314) — subject to Corinne's implementation):

- Join `dim_people` × `dim_companies` on `dim_people.company_id`
- Apply quality-gate thresholds per [BC-2311](https://linear.app/brite-nites/issue/BC-2311) (`data_quality_score`, required fields per segment, per-channel completeness)
- Filter to `business_category` ∈ commercial set (excludes residential / SMB consumer)
- One row per (person, company) pair ready to push to Salesforce Leads / Email Bison
- Output schema: person identity + work email (verified) + company firmographics + territory + persona class

The output schema lands in this catalog when the view ships. Until then, `list-building` Source 2/4 callers wanting commercial outbound MUST:

- Use `dim_people` JOIN `dim_companies` directly, applying their own WHERE on `business_category` + `data_quality_score >= 70` + `work_email_status IN ('verified', 'enriched')`
- Suppress against EB workspaces + SF Leads in the skill (the audience view will eventually bake suppression in, but `dim_*` does not)

## Naming convention

New audience views are named `audience_<segment>_<motion>` where:

- `<segment>` identifies the customer slice (`commercial`, `residential`, `municipal`, `educational`, etc.)
- `<motion>` identifies the outbound motion (`outreach`, `retention`, `reactivation`, `nurture`, etc.)

Planned future entries that conform to this pattern (none built yet):

- `audience_residential_retention` — Nites repeat-customer touch
- `audience_supply_reactivation` — Supply lapsed-buyer wake-up
- `audience_municipal_outreach` — Labs municipal RFP-tracker outbound

A proposed view that doesn't fit the pattern is a signal that the schema needs a rethink — open a discussion with Corinne before naming.

## How to consume

- **Today (Source 2 — manual CSV export).** Operator runs `snow sql -q "SELECT ... FROM <view> WHERE ..."` out-of-band, exports rows to CSV, passes `--audience-csv` + `--audience-view-name <view_name>` to `list-building`. The view name MUST appear in the catalog above.
- **Tomorrow (Source 4 — direct query per [BC-11929](https://linear.app/brite-nites/issue/BC-11929)).** Operator passes `--snowflake-audience <view_name>` to `list-building`. The skill calls `plugins/marketing/scripts/snowflake/query_audience.py` (per [ADR-030](../../../docs/decisions/030-marketing-snowflake-access.md)) which validates the name against this catalog before issuing the SQL.

In both modes, the view name is validated; arbitrary view names or arbitrary SQL is rejected.

## Ownership

- **View design + refresh:** Corinne Brewer (GTM Intelligence project). Schema changes flow through that project's review process; the marketing plugin consumes whatever ships.
- **Catalog maintenance:** marketing plugin maintainers (this file). When a new audience view ships in `brite-data-platform`, append it to the catalog table; if no PR lands here, the view is not consumable by skills (the allowlist gates).
- **Schema-drift sync:** Corinne pings marketing plugin owners when a load-bearing column changes (rename, drop, type change) so downstream skills can adapt before the breaking change lands. Adds belong in the catalog when the view stabilizes.
