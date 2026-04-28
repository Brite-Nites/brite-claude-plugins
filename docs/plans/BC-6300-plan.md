# BC-6300 — launch-campaign Phase 4 lead-body field names wrong (Sx-6)

**Linear:** https://linear.app/brite-nites/issue/BC-6300
**Branch:** `corinne/bc-6300-bc-5906-follow-up-launch-campaign-phase-4-lead-body-field`
**Blocks:** BC-6308 (round-3 dogfood)

## Context

Surfaced by BC-5906 round-2 dogfood Phase 4 walk. The launch-campaign spec's lead-body example uses CSV column names instead of EB lead-object field names. Production-impact: an agent executing the spec verbatim would build leads with `job_title: "..."` and `company_name: "..."` — EB silently ignores those fields, and leads are created with `title: null` and `company: null`. Data loss disguised as success.

3rd application of the BC-6306 → BC-6298 dogfood-bundle pattern (procedural fix in spec + canonical bullet in `email-bison.md`). User declined CLAUDE.md promotion at this instance.

## Field-name mismatches

| Spec (wrong) | EB API (correct) | CSV column |
|---|---|---|
| `job_title` | `title` | `job_title` |
| `company_name` | `company` | `company_name` |
| `company_domain` | (no field; drop or stash as custom_variable) | `company_domain` |

CSV columns can stay named anything; the bug is specifically how the spec maps CSV → EB lead body.

## Files touched

- `plugins/marketing/commands/launch-campaign.md` — 3 in-place edits.
- `plugins/marketing/tools/integrations/email-bison.md` — 1 new § Known gotchas bullet + Last verified footer entry.
- `plugins/marketing/.claude-plugin/plugin.json` — version 0.3.10 → 0.3.11.
- `.claude-plugin/marketplace.json` — marketing entry version 0.3.10 → 0.3.11.

## Tasks

### Task 1 — Rewrite Phase 4 step 2 lead-body example

**File:** `plugins/marketing/commands/launch-campaign.md` (around line 334).
**Change:** Replace the lead-body JSON example with EB-correct field names; add a CSV→EB mapping note immediately after.

**Replace this block (current lines 334-349):**

```
2. **Prepare lead batches.** Read the CSV. For each row, build the lead object:

   ```json
   {
     "email": "<csv email>",
     "first_name": "<csv first_name>",
     "company_domain": "<csv company_domain>",
     "last_name": "<csv last_name — if column present>",
     "job_title": "<csv job_title — if column present>",
     "company_name": "<csv company_name — if column present>",
     "custom_variables": [
       {"name": "RECENCY_ANCHOR", "value": "<row-specific value>"},
       {"name": "PROOF_POINT_COMPANY", "value": "<row-specific value>"}
     ]
   }
   ```
```

**With:**

```
2. **Prepare lead batches.** Read the CSV. For each row, build the lead object using EB's lead-body field names (NOT the CSV column names — Sx-6, BC-5906):

   ```json
   {
     "email": "<csv email>",
     "first_name": "<csv first_name>",
     "last_name": "<csv last_name — if column present>",
     "title": "<csv job_title — if column present>",
     "company": "<csv company_name — if column present>",
     "custom_variables": [
       {"name": "RECENCY_ANCHOR", "value": "<row-specific value>"},
       {"name": "PROOF_POINT_COMPANY", "value": "<row-specific value>"},
       {"name": "COMPANY_DOMAIN", "value": "<csv company_domain>"}
     ]
   }
   ```

   **CSV → EB lead-body mapping:**

   | CSV column | EB lead-body field |
   |---|---|
   | `email` | `email` |
   | `first_name` | `first_name` |
   | `last_name` | `last_name` |
   | `job_title` | `title` *(renamed)* |
   | `company_name` | `company` *(renamed)* |
   | `company_domain` | (no native EB field — stash as a `custom_variable` named `COMPANY_DOMAIN`, or drop if unused by copy artifact) |

   `company_domain` is required in the CSV for Phase 2 HOST LOOKUP (Bash `dig` resolves ESP from the domain) — it does NOT have a native EB lead-body field. Stash as a custom variable if the copy artifact references `{COMPANY_DOMAIN}`; drop otherwise.
```

**Verification:** `grep -n "title.*csv job_title\|company.*csv company_name\|COMPANY_DOMAIN" plugins/marketing/commands/launch-campaign.md` returns the new lines; no stale `job_title` or `company_name` keys appear in the lead-body JSON example.

---

### Task 2 — Fix Phase 1 step 5 variable-presence example

**File:** `plugins/marketing/commands/launch-campaign.md` (line 177).
**Change:** Update the EB-standard-variable allowlist explanation to use EB's actual lead-body field names instead of CSV column names.

**Replace (line 177):**

> - **EB-standard-variable allowlist (highest priority).** The variable is one of `FIRST_NAME`, `LAST_NAME`, `COMPANY`, `COMPANY_DOMAIN`, `JOB_TITLE`, `EMAIL` — these resolve server-side via EB's render engine from the canonical lead fields (`first_name`, `last_name`, `company_name`, `company_domain`, `job_title`, `email`) that Phase 4 UPLOAD populates. No CSV-column string match is required — the render is field-based, not column-based. A lead object created via `bulk_create_leads` with `company_name: "Acme Corp"` will render `{COMPANY}` as `Acme Corp` even though the CSV column was `company_name`, not `company`. OR

**With:**

> - **EB-standard-variable allowlist (highest priority).** The variable is one of `FIRST_NAME`, `LAST_NAME`, `COMPANY`, `JOB_TITLE`, `EMAIL` — these resolve server-side via EB's render engine from EB's lead-body field names (`first_name`, `last_name`, `company`, `title`, `email`) that Phase 4 UPLOAD populates. No CSV-column string match is required — the render is field-based, not column-based. A lead object created via `bulk_create_leads` with `company: "Acme Corp"` will render `{COMPANY}` as `Acme Corp` even when the CSV column was named `company_name` — Phase 4 step 2 maps `csv.company_name → eb.company` (Sx-6, BC-5906). Note: `{COMPANY_DOMAIN}` is NOT EB-standard — EB has no native `company_domain` field. If a copy artifact references `{COMPANY_DOMAIN}`, the lead-body must stash it via `custom_variables` (per Phase 4 step 2). OR

**Verification:** Line 177 references `eb.company` (not `eb.company_name`), `eb.title` (not `eb.job_title`); `{COMPANY_DOMAIN}` correctly removed from EB-standard list and noted as custom-variable-only.

---

### Task 3 — Update Phase 4 step 1 endpoint reference

**File:** `plugins/marketing/commands/launch-campaign.md` (line 333).
**Change:** Replace the "via `bulk_create_leads`" rate-limits framing with the verified endpoint path `/api/leads/multiple`.

**Replace (line 333):**

> 1. **Ground-truth the tool name.** `search_api_spec` with query `bulk create leads`. Per `email-bison.md` § Rate limits the current name is `bulk_create_leads` (not `bulk_create`). Variant tools: `upsert_multiple_leads` (for merging against existing leads), `bulk_create_leads_csv` (CSV-upload variant). Default to `bulk_create_leads` unless the artifact or operator instructs otherwise.

**With:**

> 1. **Ground-truth the tool name.** `search_api_spec` with query `bulk create leads`. Per `email-bison.md` § Common workflows the verified endpoint path is `POST /api/leads/multiple` (NOT `/api/leads/bulk` — that's the CSV-upload variant). The conceptual label `bulk_create_leads` in this spec maps to that endpoint via `call_api`. Variant endpoints: `upsert_multiple_leads` (for merging against existing leads), `bulk_create_leads_csv` (CSV-upload variant, `POST /api/leads/bulk`). Default to `/api/leads/multiple` unless the artifact or operator instructs otherwise.

**Verification:** The endpoint path `/api/leads/multiple` appears in step 1; no claim that `bulk_create_leads` is "the current name" remains. Other `bulk_create_leads` references in the file stay (per line 53, they're conceptual labels).

---

### Task 4 — Append 1 bullet to email-bison.md § Known gotchas (Sx-6)

**File:** `plugins/marketing/tools/integrations/email-bison.md` (around line 274 — at the end of § Known gotchas, after the BC-6298 bullets).
**Change:** Add 1 new bullet for Sx-6 following BC-6298's format.

**Bullet to append:**

```
- **Lead-body field names diverge from common-CSV-column names.** EB's `/api/leads/multiple` endpoint expects `title` (not `job_title`), `company` (not `company_name`), and has NO `company_domain` field at all. CSV columns named `job_title`/`company_name`/`company_domain` must be remapped at lead-body construction time: `csv.job_title → eb.title`, `csv.company_name → eb.company`, `csv.company_domain → custom_variable` (or drop). Sending the CSV-column names verbatim silently creates leads with `title: null` / `company: null` — data loss disguised as success. Surfaced by BC-5906 round-2 (Sx-6); spec fix shipped in BC-6300.
```

**Also append a 2026-04-28 entry to the "Last verified" footer:**

```
`2026-04-28` — BC-6300: appended §Known gotchas bullet (Sx-6 lead-body field-name divergence) sourced from BC-5906 round-2 dogfood transcript + `search_api_spec` verification of `/api/leads/multiple` schema.
```

(Goes at the top of the footer; previous BC-6298 2026-04-28 entry becomes "Prior".)

**Verification:** `grep -c "BC-6300" plugins/marketing/tools/integrations/email-bison.md` returns ≥ 2 (1 bullet + 1 footer line).

---

### Task 5 — Bump marketing plugin version

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json` — `"0.3.10"` → `"0.3.11"`.
- `.claude-plugin/marketplace.json` — marketing entry `"0.3.10"` → `"0.3.11"`.

**Why:** Per CLAUDE.md cache-staleness gotcha (precedent BC-6000) — clients' plugin cache is keyed by version. Patch bump (pure docs correction).

**Verification:** `grep -E '"version"' plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json | grep marketing` shows both at 0.3.11.

---

### Task 6 — Run validation

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

Both must exit 0.

---

## Acceptance criteria (from BC-6300 issue body)

- [x] Phase 4 step 2 lead-body example uses `title` (not `job_title`), `company` (not `company_name`), drops/stashes `company_domain` (Task 1)
- [x] CSV-to-EB field mapping note exists (Task 1)
- [x] Phase 1 step 5 variable-presence example fixed (Task 2)
- [x] Phase 4 step 1 endpoint reference updated to `/api/leads/multiple` (Task 3)
- [x] `./scripts/validate.sh` exits 0 (Task 6)

## Out of scope

- Other 6 BC-5906 round-2 follow-ups (separate sessions, separate PRs per user direction).
- Live API re-verification of Sx-6 — round-3 (BC-6308) will re-walk and confirm the fix.
- CLAUDE.md promotion of the dogfood-bundle pattern — user declined at 3rd-instance threshold; the BC-6300 precedent file will record the decision.

## Sources

- BC-6300 issue body
- BC-5906 round-2 transcript at `docs/dogfood/bc-5906/round-2-transcript.md` § Phase 4 + § Spec-vs-reality findings (Sx-6)
- BC-6298 precedent at `docs/precedents/BC-6298.md` (task-2 promotion-candidate framework — declined at this instance)
- `plugins/marketing/commands/launch-campaign.md` (current state, post-BC-6298 merge)
- `plugins/marketing/tools/integrations/email-bison.md` (current state, post-BC-6298 merge)
