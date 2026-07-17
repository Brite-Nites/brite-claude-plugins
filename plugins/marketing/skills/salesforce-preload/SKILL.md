---
name: salesforce-preload
description: Create Salesforce Contacts under real business Accounts for a cleaned cold-outbound lead set BEFORE the Email Bison upload, so OutboundSync matches an existing Contact by email instead of deriving a free-email (gmail.com) Account that the AccountTriggerHandler guard rejects. Personal instance only; the instance is an explicit operator-confirmed input. Reads via the read-only Salesforce MCP, writes via the sf CLI. Triggers "salesforce preload", "pre-load leads into salesforce", "preload contacts", "sf preload", "load leads before sending". Distinct from `list-building` (assembles the list) and `tam-mapping` (builds the TAM) — this skill assumes a cleaned list already exists and only mirrors it into Salesforce.
user-invocable: true
allowed-tools: mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep, Bash, AskUserQuestion
metadata:
  version: 0.1.0
  category: Outbound Lead Gen
---

# Salesforce Pre-Load

## Before Starting

**The problem this exists to solve.** OutboundSync builds a Contact's parent Account from the lead's **email domain**. Personal-instance leads are ~99% free-email, so the derived Account is literally `gmail.com` — which `AccountTriggerHandler`'s free-email guard rejects **unconditionally** (BC-4776 / BC-5574 deliberately severed that guard from the `Bypass_Validation_Rules` permset). The whole write rolls back, OutboundSync surfaces a blank error, and the lead never lands. The vendor confirmed (Apr 2026, ticket #974) the domain logic cannot change. So the fix is upstream data: **put the Contact in Salesforce first, under its real business, and OutboundSync matches by email instead of creating junk.**

**Never weaken the free-email guard.** It is correct. `gmail.com` is not a company website. Any change that makes the guard softer is the wrong fix and is out of scope permanently.

**Instance is explicit and never inferred.**

| Instance | Host | Pre-load? |
| --- | --- | --- |
| `personal` | `personal.outbase.so` | **Required** — free-email leads, this is the failure |
| `commercial` | `send.outbase.so` | **Skipped** — corporate emails resolve real domains; nothing to pre-load |

Resolve from an explicit `--instance` argument or the caller's workspace (`emailbison-personal` → personal, `emailbison-b2b` → commercial). **If it is absent or ambiguous, HALT** — do not default. A silently-mis-instanced run either writes thousands of unwanted Contacts or skips the population that needs it. Name the instance out loud in the write gate.

**Arguments.**

| Flag | Required | Default | Meaning |
| --- | --- | --- | --- |
| `--csv <path>` | yes | — | The cleaned lead file. Validate per the caller's IV-1/IV-2 (safe charset, `realpath`-confined to the repo). |
| `--instance <personal\|commercial>` | yes | — | No default. HALT if absent. |
| `--target-org <alias>` | no | `marketing-claude-prod` | See § Write identity. |
| `--dry-run` | no | off | Stop after the plan. Writes nothing. |
| `--canary <n>` | no | `20` | Rows in the first write batch. `0` disables. |

## Methodology

### Phase 1 — Map the file

Read the CSV header and resolve it against the canonical vocabulary via `${CLAUDE_PLUGIN_ROOT}/scripts/_shared/column_map.py`:

```
python3 -c "import sys; sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/scripts'); \
from _shared.column_map import resolve; print(resolve(HEADERS))"
```

Lead lists come from Apollo, Serper, Clay, and hand-built rosters; no two spell their headers alike. The alias coverage is the Brite data platform's own header table, vendored (`_shared/lead_column_aliases.py`, provenance-stamped) rather than re-invented — it is authority-independent reference data. Two documented deviations for this plugin's inputs: bare `name` is held as an operator question (Labs venue lists use it for the business, not a person), and `role` is ignored (the retail lists use it as a role-address flag, not a job title). Recognised headers resolve automatically. For each returned ambiguity, ask the operator **once**, via `AskUserQuestion`, with three sample values from that column attached — a question answerable at a glance:

> Column `name` — could be the business or the person.
> First values: `Sunrise of Bellevue`, `Brookdale Meridian`, `The Gardens at Town Square`
> - Yes, it's the business name
> - No, it's a person
> - Ignore this column

**Never guess a column.** A wrong guess writes the wrong company name into Salesforce, and a wrong company name is a wrong Account.

`email` and `company` must resolve or the run cannot proceed. At least one of `domain` / `phone` must resolve, or every row fails Salesforce's `Account_Contact_Method_Required` rule and the entire run lands in needs-review — say so up front rather than after the lookups.

### Phase 2 — Resolve against Salesforce (read-only)

Batch `IN()` queries via `mcp__plugin_marketing_salesforce__run_soql_query`. **Reads only — nothing is written in this phase.**

**Contacts, by exact email** (lowercased, trimmed — mirrors `WebFormDuplicateMatchService`'s key and the migration transform):

```sql
SELECT Id, Email, AccountId, Lifecycle_Stage__c, Lead_Status__c
FROM Contact WHERE Email IN ('a@x.com', 'b@y.com', ...)
```

| Matches | Disposition | Uploads to EB? |
| --- | --- | --- |
| 0 | **net-new** — create it | yes |
| 1 | **matched** — touch nothing at all | yes |
| >1 | **multiple_contacts** — skip the SF write, flag for dedup | **yes** |

The `>1` row still uploads: the contact already exists, so OutboundSync will match it and there is no gmail-Account risk. The flag is a downstream dedup TODO, not a campaign exclusion. The unifying test throughout: **would emailing this row recreate the failure?** No for multiple-match; yes for no-company.

**Accounts, by normalized name + website:**

```sql
SELECT Id, Name, Website FROM Account WHERE Name IN (...)
```

**Normalization is whitespace + case only.** Lowercase, collapse internal runs of whitespace, trim. **Do not strip legal suffixes** (`Inc`, `LLC`, `Ltd`, `GmbH`). Two reasons:

1. **Match the way the org actually stores names.** The org's own `NameAddressNormalizer` writes Account names whitespace-only and never re-cases (ADR-028), so all 6,602 existing Marketing-Admin-owned Accounts were deduped on that basis. A loader that normalized *harder* would find "matches" the org treats as distinct — and its standard duplicate rule (Fuzzy: Company, which *does* strip suffixes) is set to **Allow**, meaning the org has already decided to tolerate `Acme Inc.` and `Acme LLC` side by side. Conform to how the system of record actually behaves: whitespace-only. (Salesforce normalization is not one rule — it is method-dependent; the whitespace-only *exact* form is the one that matches the org's stored state.)
2. **The settled favor-a-duplicate rule (Q5) breaks the tie toward less-aggressive matching.** Stripping suffixes finds *more* matches, some of them wrong (`Acme Inc.` → an existing `Acme LLC` that is a different legal entity). Whitespace-only finds fewer, safer matches and creates a tolerated duplicate when unsure — which is exactly the risk preference Q5 chose. A stray duplicate is cheap; a wrong merge reparents children irreversibly.

Normalization is for **matching only**. Write the original value — the Account trigger collapses whitespace itself.

**When an Account match is uncertain, create new.** Favor a duplicate over a wrong merge: a stray duplicate is cheap and remediable, while a wrong merge reparents children irreversibly (restoring from the Recycle Bin returns an empty shell — Salesforce restores only lookup relationships that have not been replaced). No fuzzy matching, ever.

> **Note (BC-17213, open):** Salesforce's own standard Account rule never matches on name alone — every clause conjoins Name with a location or phone, and Website matches at threshold 100. Since a company domain is present on essentially every lead, **domain-first matching is likely stronger than name-first.** That is a change to a settled decision (scope doc Q5) and is recorded on the ticket, not taken here.

### Phase 3 — Plan and gate

Render the full plan, then gate. Nothing has been written yet — say so explicitly:

```
Checked 1,104 rows against Salesforce (read-only)

Contacts   net-new 967 · matched 128 · multiple-match 6 (flagged, untouched)
Companies  matched 212 · net-new 611
Needs review — held from Salesforce AND the campaign:
  no business name 3 · no website and no phone 0

Nothing is written yet.
```

**User gate — semantic, once, naming the instance out loud:**

> Create 967 contacts + 611 companies in Salesforce (`marketing-claude-prod`), owned by Marketing Admin, for the **personal** instance?
> - Yes, write to Salesforce
> - Show me a sample first
> - Abort

Compose the proposed action **agent-side**, relay it, and **wait for a real operator turn** before the first mutating call. Never fire the write in the same turn as the proposal. "Show me a sample" prints actual composed rows and re-gates.

Under `--dry-run`, stop here.

### Phase 4 — Write

Order matters: **Accounts first** (Contacts need the `AccountId`), then Contacts.

**Salesforce has no dry-run and Bulk API has no rollback.** The Phase-3 plan *is* the preview, and it is built from read-only queries, not a rehearsal. Insert is recoverable only via the success file — there is no server-side "records created by job X" query, and bulk job results are purged after 7 days. **Archive the results file before doing anything else with it.**

1. **Canary.** Write the first `--canary` rows, chosen for coverage rather than sample size: at minimum one net-new-with-person, one company-in-LastName row, one new Account, one matched Account. Verify, then continue. Salesforce publishes no canary size — its guidance is only "use a small test file first" — and a coverage-selected handful exercises more failure paths than a percentage of a homogeneous list.
2. **Load.** `sf data import bulk --sobject Account --file <csv> --target-org <org> --wait 30 --json`, then the same for Contact.
3. **Read the real counts.** `sf data bulk results --job-id <id> --target-org <org> --json`. **Never gate on job state or exit code**: a job reports `Completed` with a 100% failure rate, partial failures exit non-zero with no `result.jobInfo`, and DML commits per 200-record chunk — so `Failed` does not mean nothing happened. Count from the row-level `Success` field or the count is a guess.

**Field set.**

| | Contact | Account |
| --- | --- | --- |
| Identity | FirstName, LastName, Email | Name = company (original casing) |
| Link | AccountId | — |
| Contact method | — | Website ← domain (never a free-email one), else Phone |
| Seed (**net-new only**) | `Lifecycle_Stage__c = Cold_Prospect`, `Lead_Status__c = New` | — |
| Owner | Marketing Admin | Marketing Admin |
| **Never touch** | `OSLastCampaignId__c`, CampaignMember, `Segment__c`, `Referral_Source__c` | — |

**Name convention.** Real FirstName/LastName when present. When absent — or junk (`-`, `last_name`, `Unknown`, or equal to the company) — **FirstName blank, LastName = the company name**. Blank FirstName signals "generic business inbox, no person yet". Reject only when there is no company at all. **Never write a placeholder.** (Note the migration transform's `|| "Unknown"` fallback — mirror its structure, never that line.)

**The seed is floor-only, at creation only** (ADR-037). On a **matched** Contact, do not touch `Lifecycle_Stage__c` or `Lead_Status__c` at all — resetting an advanced contact (an `MQL`) back to the floor is a backward write, which the forward-only watermark forbids. Both values are also the picklist defaults, so an omitted field lands on the floor anyway; set them explicitly so the floor is deterministic rather than incidental. Race-safe because the reply pipeline is upgrade-only and its stage whitelist already accepts `Cold_Prospect` as an input.

### Phase 5 — Report

Write the needs-review sidecar: **original CSV columns verbatim, in order, plus a trailing `preload_status` column.** Apply the caller's IV-9 formula-injection neutralization (prepend `'` to any cell starting `=`, `+`, `-`, `@`, tab, CR) — the operator opens this in a spreadsheet.

Path: `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}-preload-review.csv`. **A written file must never have an unrecorded path** — return it to the caller alongside the counts.

`preload_status` values: `no_company` · `no_contact_method` · `multiple_contacts` · `write_failed`.

Report created/matched/held **and** the reconciliation gap. Planned 967, created 964 → say both numbers. A preview cannot predict a lock or a validation rule, so the gap is expected; hiding it is not.

**Return to the caller:** the surviving lead set (needs-review rows removed), the counts, and the sidecar path. Rows held back must not reach the Email Bison upload.

## Brite Implementation

### Tools this skill calls

| Purpose | Tool |
| --- | --- |
| Dedup reads | `mcp__plugin_marketing_salesforce__run_soql_query` |
| Writes | `sf data import bulk` / `sf data bulk results` via `Bash` |
| Column resolution | `${CLAUDE_PLUGIN_ROOT}/scripts/_shared/column_map.py` |
| Gates + column questions | `AskUserQuestion` |

The marketing Salesforce MCP registers the `data` toolset only — `run_soql_query`, `get_username`, `resume_tool_operation`. **There is no SF write tool available to this plugin**; that is why writes shell out.

### Write identity

Default `--target-org` is **`marketing-claude-prod`** — the `marketingadmin@britenites.com` auth alias. This is deliberate and load-bearing:

- It is the identity **OutboundSync already writes as**, so pre-loaded records match the pool rather than forming an island.
- Marketing Admin is the sanctioned outbound pool owner (BC-2745): it already owns 6,602 Accounts and 15,071 Contacts, and Queues cannot own Account or Contact, so a User is the only option.
- **`brite-prod` is a human's own login.** Writing through it would own thousands of cold contacts to that person.

`run_soql_query` rejects aliases — resolve to a literal username first via `sf org display --target-org <org> --json`, cached **once** per invocation.

<!-- guard:target-org -->
**Validate `--target-org` before the `sf org display` shell-out below (its earliest sink).** If `--target-org` was explicitly supplied, validate it against regex `^[a-zA-Z0-9._@-]+$`. On mismatch, **hard-fail (exit non-zero)** with: `ERROR: --target-org failed regex (^[a-zA-Z0-9._@-]+$); got '<value-truncated-to-80-chars-with-control-bytes-stripped>'.` The shell-out interpolates `--target-org` into a double-quoted `sf` argument, which blocks bare metacharacters but **not** `$(...)` / backtick command substitution — so this regex (which excludes `$`, `(`, `)`, backticks, whitespace) MUST run **before** that interpolation (guard-precedes-sink; BC-12638). Keep the regex byte-identical to `/marketing:portfolio-snapshot` and the revops σ3 siblings.

```bash
sf org display --target-org "<target-org>" --json
```

### Architectural rules that apply

- **ADR-037** — this skill is a *sanctioned writer of the lifecycle floor*: `Cold_Prospect`/`New` on net-new only, never on a matched Contact, never via a trigger. The reply pipeline remains the sole writer of every forward transition.
- **ADR-025 / ADR-032** — `Lifecycle_Stage__c` is a forward-only watermark; the Contact pre-sale band is pipeline-owned. This skill's carve-out is the floor and nothing above it.
- **ADR-028 (brite-salesforce)** — in-org normalization is whitespace-only. Match keys normalize harder; written values do not.
- The build PR owes an **S2 (Cold outbound → Contact-first)** row in `docs/artifacts/lifecycle-conformance.md`.

### Cross-skill boundaries

- **Upstream:** `tam-mapping` / `list-building` build and suppress the list. This skill assumes that already happened.
- **Caller:** `/marketing:launch-campaign` invokes this at Phase 1b — after PRE-FLIGHT, before UPLOAD (BC-17214). Phase order is the enforcement: if this halts, nothing is emailed.
- **Not this skill:** Salesforce suppression at launch (BC-17224). The pre-load asks "does this contact exist?" and answers *leave it alone, still mail*; suppression asks the same question and answers *don't mail*. They are different rules and this one must not silently become the other.
- **Downstream:** OutboundSync matches by email; the Outbase→CampaignMember flow creates CampaignMember. Never pre-empt either.

## Anti-Slop Guardrails

- ❌ Never weaken or bypass the free-email Account guard.
- ❌ Never overwrite `Lifecycle_Stage__c` / `Lead_Status__c` on a matched Contact.
- ❌ Never write a placeholder name (`-`, `last_name`, `Unknown`).
- ❌ Never infer the instance — HALT if unsure.
- ❌ Never guess a column — ask, with samples.
- ❌ Never strip legal suffixes when normalizing for a match.
- ❌ Never fuzzy-match. Uncertain Account → create new.
- ❌ Never trust a bulk job's state or exit code as a success signal.
- ❌ Never fire a mutating call in the same turn as its proposal.
- ✅ Idempotent: re-running matches what exists and seeds only net-new, so a second run picks up only repaired rows.

## Behavioral Tests

### Tier 1 — Free assertions

1. `--instance` absent → HALT, no queries issued.
2. `--instance commercial` → skip with a one-line note, zero writes.
3. A file whose company column is `name` → exactly one operator question, `name` among the candidates, no auto-resolution.
4. A row with no company → `no_company`, held from Salesforce **and** the campaign.
5. A row with >1 contact on its email → flagged, untouched in SF, **still in the returned lead set**.
6. A matched Contact at `MQL` → stage and status unchanged after the run.
7. `--dry-run` → plan rendered, zero writes.

### Tier 2 — Tool-assisted

8. Net-new Contact lands with `Cold_Prospect`/`New`, owned by Marketing Admin, parented to a non-free-email Account.
9. A no-person row lands with blank FirstName and LastName = the company; no `Unknown` anywhere in the org after the run.
10. Zero Accounts with a `FreeEmailDomains` name or website exist after the run.
11. Re-run over the same file → zero new records.
12. Planned vs created counts both reported when they differ.
13. **The point of the whole skill:** after the EB send, OutboundSync attaches activity to the pre-loaded Contact and creates **no** new Account.
