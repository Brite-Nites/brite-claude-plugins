---
description: Turn an enriched lead CSV + email-copywriting JSON artifact into an activated Email Bison campaign via an 11-phase flow with user confirmation gates at every mutating step. Consumes the BC-5825 copy artifact and the BC-2718 campaign-orchestration defaults. Default path creates campaigns in draft state; pass --activate to transition them to queued (starts real sending).
argument-hint: --csv <path> --workspace <emailbison-b2b|emailbison-personal> --copy-artifact <path> --campaign-name <base> [--entity <brite-nites|brite-labs>] [--no-segment] [--no-host-lookup] [--no-sequence] [--preview] [--activate] [--reference <campaign-id>] [--test-send <email>] [--test-send-sender <id>]
allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep, Bash, AskUserQuestion
---

# /marketing:launch-campaign

Execute the 11 phases below sequentially. Use `AskUserQuestion` at every numbered user gate — the user must explicitly approve before you proceed. If they answer anything other than the "proceed" option, halt the phase and help resolve the blocker before re-asking.

**Inputs:**

- **CSV** — enriched lead file at `--csv`. Required columns: `email`, `first_name`, `company_domain`. Optional columns: `last_name`, `job_title`, `company_name`.
- **Copy artifact** — a BC-5825 email-copywriting JSON at `--copy-artifact`. Schema: `plugins/marketing/skills/email-copywriting/SKILL.md` § JSON artifact schema. The artifact carries `step_1`, `step_2`, `custom_variables[]`, `entity`, `offer_tier`.
- **Workspace** — `emailbison-b2b` (send.outbase.so, workspace 55) or `emailbison-personal` (personal.outbase.so, workspace 13). Must match the entity per `plugins/marketing/tools/integrations/email-bison.md` § Auth.

**Outputs:**

- **Launch metadata JSON** at `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` — written progressively, one phase at a time. On partial failure, the metadata file IS the breadcrumb — re-run picks up from `last_completed_phase + 1` manually.
- **EB workspace state** — one or more campaigns in `Draft` (default) or `Queued` (with `--activate`).

**Precedent + upstream sources:**

- `plugins/marketing/tools/integrations/email-bison.md` § Common workflows / § MCP confirmation gates / § Known gotchas — ground truth for every tool name and call shape.
- `docs/precedents/BC-2707.md` — two-call MCP confirmation-gate semantics (turn structure, not vocabulary).
- `plugins/marketing/skills/email-copywriting/SKILL.md` — source of the copy artifact this command consumes.
- [Revgrowth1/ai-gtm-workflows workflow 10](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/10-campaign-launch) (MIT) — upstream 9-step launch flow; this command extends it with workspace disambiguation, Brite entity awareness, and BC-2707's two-call MCP gate precedent.

**Ground-truthing rule.** Before every mutating MCP call to an **extended-tier** tool in phases 3–11, run `search_api_spec` on the target endpoint to confirm the live tool name and request body shape. **Core-tier tools (enumerated below) may be called directly without per-session re-verification** — their names are stable and part of the official EB MCP contract. The ground-truth `email-bison.md` is the authoritative session reference; the vendor MCP is in Beta and extended-tier tool surface may drift. Never call an extended-tier tool whose endpoint you haven't confirmed this session. When running `search_api_spec`, prefer URL-path queries (`/api/custom-variables`) or short keywords (`custom-variables`, `schedule template`) over natural-language phrases — phrases like "custom variable list" return `not found` (Sx-1, BC-5906). The spec's "required" vs "optional" field markings are advisory only — EB silently accepts requests with documented-required fields omitted (verified for `last_name` on `/api/leads`); never gate logic on "the API will reject missing fields" (Sx-5, BC-5906).

---

## Tool tier map

The Email Bison MCP (both `emailbison-b2b` and `emailbison-personal` workspaces) exposes two tiers of tools. This command names the second tier by conceptual label throughout — the actual invocation pattern is different.

**Namespace note.** The EB MCP servers register at the **user level** (`~/.claude/settings.json`) because plugin-scoped HTTP MCP servers with `${ENV_VAR}` header substitution are broken in Claude Code v2.1.112+ (see `email-bison.md` § Known Claude Code limitation, BC-5551 verified 2026-04-19). As a consequence, their tool namespaces are `mcp__emailbison-b2b__*` and `mcp__emailbison-personal__*` — **no `plugin_marketing_` prefix**. By contrast the Salesforce MCP is plugin-scoped (stdio, no header substitution needed) and uses the canonical `mcp__plugin_marketing_salesforce__*` namespace. When the upstream HTTP-header bug is fixed and EB migrates to `plugins/marketing/.mcp.json`, this command's `allowed-tools` must be updated in lockstep.

**Core tier (directly callable as `mcp__emailbison-<workspace>__<tool>` — stable across sessions, no per-call `search_api_spec` required):**

`create_campaign`, `create_lead`, `list_leads`, `get_campaign`, `get_lead`, `list_campaigns`, `bulk_count`, `bulk_export`, `discover_tools`, `search_api_spec`, `get_active_workspace_info`, `get_account_details`, `set_active_workspace`, `reset_to_primary_workspace`, `validate_workspace_key`, `list_replies`, `send_reply`, `search_replies`, `get_reply`, `get_campaign_stats`, `get_campaign_analytics`, `get_leads_analytics`, `get_replies_analytics`, `export_leads_csv`, `export_replies_csv`, `update_lead`, `call_api`.

**Extended tier (NOT directly callable — invoke via `call_api` + `search_api_spec`):**

Every tool named in phases 3–11 that isn't in the core tier list above — e.g. `bulk_create_leads`, `create_custom_variable`, `list_custom_variables`, `import_leads_to_campaign`, `list_sender_emails`, `attach_sender_emails_to_campaign`, `get_schedule_templates`, `create_schedule_from_template`, `create_sequence_steps`, `resume_campaign`. These exist only as REST endpoints — `call_api` is the transport; `search_api_spec` produces the endpoint path + request body shape.

**Invocation pattern for every extended-tier tool:**

1. `search_api_spec` with a query describing the operation (e.g., `bulk create leads`, `attach sender emails`). Confirms the live endpoint path + HTTP method + request body shape this session.
2. `call_api` with the confirmed path + method + body. This is the mutating call.
3. When the phase specifies a two-call vendor confirmation gate (per BC-2707), steps 1–2 execute twice: first without `confirmation`, then — after a real operator turn on `AskUserQuestion` — with `confirmation: true`.

Tool names in phase narratives are conceptual labels for the operation, not directly-callable function names. When a phase says "call `bulk_create_leads`," read that as "invoke the ground-truthed bulk-create-leads endpoint via `call_api` following the pattern above."

**Allowed-tools breadth.** The frontmatter uses wildcards (`mcp__emailbison-b2b__*`, `mcp__emailbison-personal__*`) rather than an explicit tool list because every extended-tier operation flows through `call_api`, so narrowing the allowlist below `call_api` + `search_api_spec` + the ~10 core-tier tools this command reads from would still authorize every extended-tier operation via `call_api`. Explicit narrowing therefore buys no security — the real authorization boundary is `call_api`'s endpoint path + the operator gate. The workspace plugin has ~141 EB tools total; this command deliberately ignores the vast majority and relies on the phase-level user gates + `call_api`-only extended-tier contract for blast-radius control, not frontmatter narrowing.

---

## Input validation

Run this block before Phase 1. Every input that flows into `Bash`, the metadata write path, or the EB `call_api` body must pass the checks below. Halt with a clear error on any failure. No operator gate — these are mechanical safety invariants that fail closed.

**IV-1. `--csv` path — reject unsafe characters.** Before any `Bash` invocation (`head`, `wc`, `awk`, `dig`), validate the path is composed of `[A-Za-z0-9._/-]` only. Reject anything containing shell-metacharacters, quotes, whitespace, or backslashes. The subsequent Bash calls single-quote the path; this is defense-in-depth against interpolation escape. No auto-sanitization — if the path fails the check, the operator resubmits.

**IV-2. `--csv` path — normalize and confine to repo root.** Resolve the path via `realpath` (or `readlink -f`). The resolved path MUST begin with the output of `git rev-parse --show-toplevel`. This rejects any path that resolves outside the current repository via relative segments. Halt on any resolution mismatch.

**IV-3. Dogfood-path detection (tightened).** The § Launch metadata schema "Dogfood write path" auto-override uses the **normalized** path from IV-2, not the raw `--csv` string. Match the normalized path against `<repo-root>/.claude/worktrees/<worktree-name>/` followed by any sub-path, where `<worktree-name>` matches `[a-z0-9._-]+`. Extract `<worktree-name>` from the match, set metadata write directory to `<repo-root>/.claude/worktrees/<worktree-name>/dogfood/`. Any normalized path not matching this structured pattern uses the default `docs/campaigns/{entity}/` path. No prefix substring matching.

**IV-4. Extracted-domain safety (Phase 2 pre-dig filter).** Phase 2 parses the domain from each CSV email column. Before passing any domain value to `dig`, require it to match regex `^[A-Za-z0-9][A-Za-z0-9.-]{0,253}[A-Za-z0-9]$`. Drop anything that doesn't match with a warning logged per skipped row. Poisoned CSV rows whose email column contains characters outside this set cannot reach the `dig` invocation. Record dropped rows in Phase 2 metadata (`invalid_domain_rows: [<row-numbers>]`).

**IV-5. `--test-send <email>` validation (Phase 10 Mode 2 pre-call).** If `--test-send` is present, validate the email against regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`. Halt Mode 2 (not the whole Phase 10) on regex failure. The email then flows into the `call_api` body via **structured JSON construction** (the agent's JSON serializer), never via string concatenation. Additionally, the recipient domain MUST be on the Brite-internal test-send allowlist declared in `docs/marketing-context.md` § `test_send_allowlist` (authored per environment). If marketing-context lacks this block OR the domain isn't in it, Mode 2 halts — this command does not offer an `--allow-external-test-send` override. Rationale: typo-misdirection (operator intends their own inbox, types a customer inbox) would contradict Phase 10's "No lead is contacted" guarantee.

**IV-6. Operator-email SOQL interpolation (Phase 1 step 7.3).** Before interpolating the operator-email value into the SOQL `WHERE Email = '{operator-email}' LIMIT 1` clause, validate against the same email regex in IV-5. On regex failure, skip step 7.3 entirely and fall through to step 7.4 (operator-prompt fallback). The SOQL path is not the sole resolution path; failing closed here is cheap.

**IV-7. Metadata JSON — no credential values.** The metadata write path documented in § Launch metadata schema writes only workspace labels, campaign IDs, lead counts, timestamps, and resolution-method tags. It **never writes** tokens, keys, session IDs, or any value sourced from a credential env var. When a phase needs to record the **source** of a credential (e.g., "sender auth came from the b2b workspace token"), log the source **name** (e.g., `"sender_auth_source": "workspace-token-env"`), not the value. Enforcement is by construction — the schema enumerates permitted fields; any phase that would write a credential value is a bug.

---

## Argument parsing and defaults

| Arg / flag | Required | Default | What it does |
|---|---|---|---|
| `--csv <path>` | yes | — | Enriched lead CSV. Phase 1 validates schema + row count. |
| `--workspace <id>` | yes | — | `emailbison-b2b` or `emailbison-personal`. Phase 1 cross-checks against entity. |
| `--copy-artifact <path>` | yes | — | Path to the BC-5825 JSON artifact. Phase 1 loads + validates against schema v1.0. |
| `--campaign-name <base>` | yes | — | Base name for created campaigns. Segmentation adds suffixes (`\| Google`, `\| Microsoft`, `\| Other`). |
| `--entity <id>` | no | from copy artifact | `brite-nites` or `brite-labs`. Overrides `entity` in copy artifact — use only when intentionally re-targeting. Brite Supply is intentionally absent: Supply's marketing verticals are deferred per handbook `marketing/go-to-market/verticals/README.md`, and upstream `email-copywriting/SKILL.md` § 4 / § 8 enforces the same exclusion in the copy artifact. Do not re-add without coordinating with the handbook canon update. |
| `--no-segment` | no | off (segmentation ON) | Skip Phase 2 ESP segmentation. One campaign with the base name. |
| `--no-host-lookup` | no | off (lookup ON) | Skip Phase 2 entirely. Implies `--no-segment`. |
| `--no-sequence` | no | off (sequence ON) | Skip Phase 9. Campaign has no sequence steps until added out-of-band. |
| `--preview` | no | off | Full dry-run. Sample 3 leads through Phase 1 + Phase 10 local render. No mutations. Phases 3–9, 11 all skipped. |
| `--activate` | no | off | Enable Phase 11 ACTIVATE. Without this flag, campaigns stop at Phase 10 in draft. |
| `--test-send <email>` | no | — | Phase 10 additive mode: after the local render, call EB's `test-email` endpoint to send a real email to the specified inbox (typically the operator's own). Requires Phases 4–9 to have run. Counts toward sender reputation + daily limits. No lead is contacted. |
| `--test-send-sender <id>` | no | first attached | Override the sender mailbox used for `--test-send`. Default: first attached sender from Phase 7. |
| `--reference <campaign-id>` | no | — | Clone variables + naming + sender plan + schedule from an existing campaign. Pre-fills Phase 3/5/7/8 defaults — user gates still fire. |

**Non-goals** (explicit — do NOT do these):

- Do NOT generate copy — that's BC-5825 email-copywriting. This command CONSUMES the copy artifact.
- Do NOT design sequences — that's BC-2718 campaign-orchestration. This command APPLIES the sequence as given.
- Do NOT handle reply routing — that's BC-2720 reply-processing.
- Do NOT split senders across multiple campaigns — invariant violation, explicitly forbidden in Phase 7 (Revgrowth 10 rule).
- Do NOT skip the two-call MCP gate on Phase 4 UPLOAD or Phase 11 ACTIVATE — these are load-bearing safety mechanisms.
- Do NOT default to `--activate`. Campaigns are created in draft unless the flag is explicit.
- Do NOT treat "preview" as an EB server-side render. Email Bison has no standalone preview endpoint — Phase 10's default mode is a client-side local render of the copy artifact, and the optional `--test-send` mode delivers a real test email. Neither is a non-sending server-side preview in the way the term typically implies. BC-5826 X17 dogfood confirmed (F13) that an EB preview endpoint does not exist; do not search for one.

---

## Launch metadata schema

The file at `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` is written progressively across the 11 phases. Each phase appends its result IDs when it completes. The partial JSON IS the breadcrumb on failure — re-running the command reads the file, shows `last_completed_phase`, and the operator picks up from the next phase manually.

```json
{
  "schema_version": "1.0",
  "entity": "brite-nites",
  "campaign_name_base": "denver-downtown-lighting",
  "workspace": "emailbison-b2b",
  "copy_artifact_path": "docs/campaigns/brite-nites/copy-denver-downtown-lighting-2026-04-20.json",
  "csv_path": "lists/denver-downtown-2026-04-20.csv",
  "lead_count": 127,
  "segmented": true,
  "esp_segments": {"Google": 84, "Microsoft": 31, "Other": 12},
  "custom_variables_created": ["RECENCY_ANCHOR", "PROOF_POINT_COMPANY"],
  "lead_ids_uploaded": 127,
  "campaign_ids": {"Google": 5551, "Microsoft": 5552, "Other": 5553},
  "plain_text_applied": true,
  "sender_ids_attached": [101, 102, 103],
  "sender_attach_counts": {"Google": 3, "Microsoft": 3, "Other": 3},
  "schedule_id": 42,
  "sequence_ids": {"Google": 8801, "Microsoft": 8802, "Other": 8803},
  "preview_rendered_at": "2026-04-20T14:32:00Z",
  "activated": false,
  "activated_at": null,
  "launched_at": "2026-04-20T14:30:00Z",
  "last_completed_phase": 10
}
```

`last_completed_phase` advances monotonically from 1 to 11. `activated` flips to `true` only on Phase 11 success; `activated_at` is the ISO-8601 timestamp of the second `resume_campaign` call (the post-confirmation one).

**Optional fields written by specific phases.** The example above shows the minimal shape. Individual phases also write these fields when applicable — consumers MUST accept their presence and SHOULD gracefully handle their absence:

- Phase 1 step 3 / step 10: `workspace_mismatch: {expected: "<id>", actual: "<id>"} | null`
- Phase 1 step 7 / step 10: `sender_resolution_method: "artifact-default" | "marketing-context" | "salesforce" | "operator-prompt"`
- Phase 1 step 9 / step 10: `unique_per_lead_enabled: <bool>`
- Phase 2 step 3 (F12 skip-empty): `skipped_buckets: [<bucket-label>, ...]`
- Phase 2 IV-4 (Input validation): `invalid_domain_rows: [<row-number>, ...]`
- Phase 5 step 7 / step 8: `plain_text_applied: <bool>` (true only if step 7 PATCH loop completed for ALL campaigns; false if partial)
- Phase 6 step 7: `lead_attach_counts: {<bucket>: <count>, ...}`
- Phase 10 Mode 1 step 8: `preview_method: "local-render" | "local-render + test-send"`, `preview_lead_email: "<email>"`
- Phase 10 Mode 2 step 6: `test_send_recipient: "<email>"`, `test_send_at: "<ISO-8601>"`

**Schema contract — no credential values.** This JSON writes labels, IDs, counts, timestamps, and resolution-method tags. It does NOT write credential values of any kind (tokens, keys, session IDs). When the resolution method is relevant (e.g., "sender resolved via workspace token"), log the source name, never the value. See Input validation § IV-7.

**Dogfood write path (F6 convention).** For any dogfood, staging, or testing run — typically a run against `emailbison-personal` with a synthetic test CSV — write the metadata JSON to `.claude/worktrees/<worktree-name>/dogfood/` (gitignored) instead of `docs/campaigns/{entity}/`. Production metadata lives under `docs/campaigns/` because downstream consumers (campaign-debrief skill, launch-history audits) read from there; dogfood metadata pollutes that directory and should never be committed. Detection is structured, not substring-matched — see Input validation § IV-3 for the pattern. The detection fires at Phase 1 step 3 (flagging the cross-mapping) AND Phase 1 step 10 (selecting the write path).

---

## Phase 1 — PRE-FLIGHT

**Purpose.** Validate every input before touching any EB state. This phase is read-only — no MCP mutations. Catch schema drift, missing variables, entity/workspace mismatch, and thin copy before any lead gets created.

**Steps:**

1. **CSV schema validation.** Read the first line of `--csv` via `Bash`: `head -1 "{csv}"`. Confirm it contains `email`, `first_name`, `company_domain` (case-insensitive). Halt with a clear error if any required column is missing. Report optional columns found (`last_name`, `job_title`, `company_name`) — absent-but-referenced-in-copy columns are flagged in step 4.
2. **Row count.** `wc -l "{csv}"` minus 1 for header. Store as `lead_count` for metadata.
3. **Workspace detection and cross-mapping flag (F2).** Load the copy artifact at `--copy-artifact` via `Read`. Extract `entity`. Map entity → expected workspace:
   - `brite-nites` → `emailbison-b2b` (workspace 55, `send.outbase.so`)
   - `brite-labs` → `emailbison-b2b` (workspace 55; Labs also runs b2b outreach)
   - Operator explicit override via `--workspace` is honored
   If `--workspace` disagrees with the entity→workspace mapping, **do NOT gate here.** Record a `workspace_mismatch` flag in scratch state with the expected and actual workspace IDs. The end-of-Phase-1 gate (the `AskUserQuestion` block labeled "User gate 1" — immediately after step 10's metadata write) surfaces this flag for acknowledgment alongside the rest of the pre-flight report — a single unified gate is easier to reason about than two mid-phase interrupts.

   Dogfood + staging runs legitimately cross-map (e.g., `--entity brite-labs --workspace emailbison-personal` for a dogfood against the personal workspace). The cross-mapping gate is **expected** in those cases, not a warning. Write path for metadata JSON also changes — see § Launch metadata schema "Dogfood write path" note.
4. **Copy artifact JSON schema validation.** Confirm the loaded JSON has `schema_version == "1.0"`, required fields `entity`, `offer_tier`, `step_1.subject`, `step_1.body`, `step_2.subject`, `step_2.body`, `custom_variables` (array). Halt on any missing field. See `plugins/marketing/skills/email-copywriting/SKILL.md` § JSON artifact schema for the full contract.
5. **Variable-presence check (F7).** Extract every `{VARIABLE}` from `step_1.subject`, `step_1.body`, `step_2.subject`, `step_2.body` via `Grep` (regex `\{[A-Z_]+\}`). For each variable, verify one of these resolution paths in priority order:
   - **EB-standard-variable allowlist (highest priority).** The variable is one of `FIRST_NAME`, `LAST_NAME`, `COMPANY`, `JOB_TITLE`, `EMAIL` — these resolve server-side via EB's render engine from EB's lead-body field names (`first_name`, `last_name`, `company`, `title`, `email`) that Phase 4 UPLOAD populates. No CSV-column string match is required — the render is field-based, not column-based. A lead object created via `bulk_create_leads` with `company: "Acme Corp"` will render `{COMPANY}` as `Acme Corp` even when the CSV column was named `company_name` — Phase 4 step 2 maps `csv.company_name → eb.company` (Sx-6, BC-5906). Note: `{COMPANY_DOMAIN}` is NOT EB-standard — EB has no native `company_domain` field. If a copy artifact references `{COMPANY_DOMAIN}`, the lead-body must stash it via `custom_variables` (per Phase 4 step 2). OR
   - The variable matches a CSV column (case-insensitive) populated for ≥95% of rows — for non-standard, per-lead variables that get written into `custom_variables[].value` at UPLOAD, OR
   - The variable appears in `custom_variables[]` with a non-empty default, OR
   - The variable is a `{SENDER_*}` variable (filled via the priority chain in step 7).
   Report any variable that fails all four checks. Operator can override ("proceed despite") via the end-of-Phase-1 gate. The EB-standard allowlist prevents the false-flagging pattern surfaced in BC-5826 X17 dogfood (F7): `{COMPANY}` vs CSV column `company_name` would have failed a naive case-insensitive string match even though EB's render engine handles it correctly.
6. **Messaging sanity checklist.** Self-check the copy artifact against these rules (all MUST pass — halt with specific error on any fail):
   - No `{{variable}}` double-brace tokens anywhere in step_1 or step_2 subject/body.
   - No `<p>` or `</p>` tags in bodies.
   - No em-dashes (`—`) in bodies.
   - No `{FIRST_NAME}` (or any merge variable) in either subject line.
   - Exactly 2 steps (step_1 + step_2 — no step_3).
   - `step_2.wait_in_days >= 3`; `step_1.wait_in_days >= 0` (step 1 typically 0 or 1).
   - Sign-off spintax present in both bodies (look for `{Best|Cheers|Thanks}` or similar).
7. **{SENDER_*} resolution priority chain (F4).** If any `{SENDER_*}` variable appears in the copy artifact, resolve it by walking the following ordered list and stopping at the first hit. Explicit authoring wins; operator prompt is last resort. Never fabricate.
   1. **Copy artifact `custom_variables[].default` (highest).** If the artifact declares `{"name": "SENDER_FIRST_NAME", "default": "Amanuel"}`, use `"Amanuel"`. This is where explicit per-campaign authoring lives — if an author took the time to set a sender value in the artifact, that intent overrides everything downstream.
   2. **`docs/marketing-context.md` sender-info block.** Read the file if it exists. Extract sender-info block (usually under a `## Sender` or `## Team` section). Apply per-field resolution — `{SENDER_FIRST_NAME}` maps to the block's first-name field, `{SENDER_EMAIL}` to the email, etc.
   3. **Salesforce User lookup via `run_soql_query`.** Run availability probe first: `SELECT Id FROM User LIMIT 1`. On success, validate the operator-email against IV-6 (regex check) then resolve per-operator: `SELECT Id, FirstName, Email, Title FROM User WHERE Email = '{operator-email}' LIMIT 1`. Availability probe + hard failure path follow the ADR 2c contract in `docs/designs/outbound-agent-architecture-adrs.md`. Two additional fall-through cases route to level 4: (a) probe-success + per-operator query returns **0 rows** (operator not in Salesforce), and (b) IV-6 regex fails (malformed `git config user.email`). Both count as "SF unreachable for this resolution" and drop to the next level, not halt.
   4. **`AskUserQuestion` prompt to operator (last resort).** Reached when SF is unreachable, the probe failed, the per-operator query returned 0 rows, OR marketing-context is absent. Before asking, surface the specific failure reason to the operator with a one-line diagnostic (per ADR 2c § Outcome clause 2): e.g., "Salesforce probe failed — check the Salesforce MCP credentials and the target-org alias, or update `docs/marketing-context.md` sender block to skip this lookup next run." Then ask for `{SENDER_FIRST_NAME}`, `{SENDER_EMAIL}`, `{SENDER_ROLE}` directly.
   Record which priority level resolved each `{SENDER_*}` variable in the metadata JSON (`sender_resolution_method: "artifact-default" | "marketing-context" | "salesforce" | "operator-prompt"`) for the Phase 10 preview and downstream audit.
8. **Lead spot check.** Pick 3 rows from the CSV (rows 2, middle, last). For each, render the step_1 body using the same local-render algorithm Phase 10 uses: substitute variables from CSV fields + `custom_variables[].default` + `{SENDER_*}` resolutions from step 7, then resolve spintax deterministically by picking the **first** option per `{opt1|opt2|…}` group, then replace `<br><br>` with paragraph breaks for display. Show rendered text to the operator. This catches spintax-rendering problems, missing CSV columns, and unbalanced `{` / `}` before any lead gets created. Call this out explicitly when rendering: "Spintax rendered with first-option pick for deterministic preview; actual sends will rotate options."
9. **Unique-per-lead auto-toggle.** If `lead_count < 500`, enable per-lead variable uniqueness (Josh Braun framework from Revgrowth 10 — each lead gets a slightly different variable value rendering). If `lead_count >= 500`, skip per-lead uniqueness for deliverability / sender-volume reasons. Log the decision.
10. **Write initial metadata JSON.** Determine write path per § Launch metadata schema "Dogfood write path" note:
    - Default: `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json`
    - Dogfood override (CSV path under `.claude/worktrees/`): `.claude/worktrees/<detected-worktree>/dogfood/{campaign-name}-{YYYY-MM-DD}.json`
    Populate `schema_version`, `entity`, `campaign_name_base`, `workspace`, `copy_artifact_path`, `csv_path`, `lead_count`, `launched_at`. Also record the scratch-state flags from steps 3–7: `workspace_mismatch` (if any), `sender_resolution_method`, `unique_per_lead_enabled`. Set `last_completed_phase: 1`. This is the first progressive write.

**User gate 1 (single end-of-Phase-1 gate, F8).** Ask via `AskUserQuestion`. Render the pre-flight summary; if a `workspace_mismatch` flag was recorded in step 3, fold its acknowledgment into the same prompt (do NOT ask twice):

> Pre-flight complete. Lead count: {N}. Workspace: {workspace}. Entity: {entity}. Variables OK: {count-passed}/{count-total}. Sanity checklist: all passed.
>
> {IF workspace_mismatch recorded:}
> ⚠️ Cross-mapping detected: entity `{entity}` normally routes to `{expected-workspace}`, but `--workspace {actual-workspace}` was explicit. Legitimate for dogfood / staging; flag for prod / real outreach. Metadata write path: `{metadata-path}` (dogfood path selected if CSV is under `.claude/worktrees/`).
> {END IF}
>
> Proceed to Phase 2?
>
> - Yes, proceed (acknowledges cross-mapping if flagged above)
> - Abort

**If Phase 1 fails:** the metadata JSON may or may not exist. If it does, it contains only the inputs — no EB state has changed. Fix the input (CSV, copy artifact, or marketing-context) and re-run.

---

## Phase 2 — HOST LOOKUP

**Purpose.** Tag each lead by email service provider (ESP) so campaigns can be segmented by sending infrastructure. Segmentation reduces cross-provider deliverability interference — a sender warmed on Google may perform differently into Microsoft inboxes, and mixing providers in one campaign can pollute the stats. This phase is read-only; no leads are mutated.

**Skip if** `--no-host-lookup` OR `--no-segment` is passed. If skipping, set `segmented: false` in metadata, record `esp_segments: null`, and proceed to Phase 3.

**Steps:**

1. **Resolve ESP per domain via Bash `dig` (F10 — primary path).** Email Bison has no lead-side ESP detection tool today (BC-5826 X17 dogfood confirmed: `search_api_spec` on `host lookup`, `ESP`, `domain detection`, `check-mx-records` returns only sender-side tools). Bash `dig` is the primary — and currently only — path. Extract domains, filter invalid ones (per Input validation § IV-4), resolve MX records in **parallel in one Bash invocation**, bucket client-side:
   - **Extract + filter + resolve in a single Bash call.** Do NOT loop the Bash tool per domain — that turns a 5k-unique-domain 10k-lead CSV into hours of round-trip latency. One invocation pipeline:

     ```
     awk -F',' 'NR>1 {split($1,a,"@"); print a[2]}' "{csv}" \
       | sort -u \
       | grep -E '^[A-Za-z0-9][A-Za-z0-9.-]{0,253}[A-Za-z0-9]$' \
       | xargs -P 20 -I {} sh -c 'printf "%s\t" "$1"; dig MX "$1" +short | tr "\n" "|"; printf "\n"' _ {}
     ```

     `grep -E` enforces IV-4 — any domain that wouldn't pass the regex is dropped before `dig` sees it. `xargs -P 20` resolves 20 domains in parallel; 5k domains complete in ~minutes, not hours. Output shape: one line per domain, `<domain>\t<mx-records-pipe-joined>`. Track domains dropped at the `grep` step by diffing pre- vs. post-filter line counts and record as `invalid_domain_rows` in Phase 2 metadata (map rejected domains back to CSV row numbers during parsing).
   - **Bucket by MX pattern** (Revgrowth 10 taxonomy):
     - `Google` — gmail.com, googlemail.com, and MX records matching `aspmx.l.google.com` or `*.googlemail.com`
     - `Microsoft` — outlook.com, hotmail.com, live.com, and MX records matching `*.outlook.com` / `*.protection.outlook.com` / `*.mail.protection.outlook.com`
     - `Proofpoint` — MX records matching `*.pphosted.com` / `*.ppe-hosted.com`
     - `Mimecast` — MX records matching `*.mimecast.com`
     - `Barracuda` — MX records matching `*.barracudanetworks.com`
     - `Cisco` — MX records matching `*.iphmx.com`
     - `Custom` — any MX record not in the above set (self-hosted, proxy)
     - `Unknown` — `dig` returned nothing (NXDOMAIN or no MX record)

   **Future MCP-native path (F11, not yet unlocked).** If EB ever adds a server-side ESP inference tool callable via `get_lead` or a bulk-ESP-classify endpoint, this command's current phase ordering blocks it — leads don't exist in EB yet at Phase 2 timing (UPLOAD is Phase 4). Unlocking the MCP-native path would require moving Phase 2 HOST LOOKUP after Phase 4 UPLOAD. Keep current ordering for now (Bash `dig` works; reordering is a larger structural change with downstream campaign-create implications). Re-evaluate when an ESP inference tool lands in a vendor release.
2. **Count leads per bucket.** Aggregate the CSV rows by their domain's bucket. The three-bucket simplification for segmentation is: `Google`, `Microsoft`, and `Other` (everything else collapsed). Surface the full 8-bucket detail in the user gate but use the 3-bucket plan for actual campaign segmentation — deliverability infra considers Google and Microsoft separately; the long tail stays one bucket.
3. **Skip empty buckets (F12).** If any bucket in the 3-bucket plan ends up with **0 leads**, drop it from the segmentation plan — do NOT create an empty campaign. Example: CSV resolves to `Google: 84, Microsoft: 0, Other: 12` → create 2 campaigns (`| Google`, `| Other`), skip Microsoft entirely. Record the skipped buckets in scratch state so the user gate + metadata JSON reflect the actual (pruned) plan. If ALL buckets are empty, halt — the CSV has zero resolvable domains and Phase 3 cannot proceed.
4. **Render the segmentation plan.** Show the operator:

   > Segmentation plan for campaign `{base}`:
   > - `{base} | Google` — N leads ({% of total}%)
   > - `{base} | Microsoft` — N leads ({% of total}%)
   > - `{base} | Other` — N leads ({% of total}%)
   >
   > {IF any bucket skipped:}
   > Skipped (0 leads): {skipped-bucket-list}. No campaign will be created for these.
   > {END IF}
   >
   > Detailed ESP breakdown: Google N, Microsoft N, Proofpoint N, Mimecast N, Barracuda N, Cisco N, Custom N, Unknown N.
5. **Append to metadata JSON.** Set `segmented: true`, `esp_segments: {<only non-empty buckets>}`, `last_completed_phase: 2`. Empty buckets are absent from the object entirely (not `0` values) — downstream phases iterate over the keys and the absence means "skip".

**User gate 2.** Ask via `AskUserQuestion`:

> Approve the 3-bucket segmentation above? Or disable ESP segmentation for this run?
>
> - Approve — proceed with the {bucket-list} split (dynamically rendered from the non-empty buckets after F12 skip-empty filtering; e.g., "Google / Microsoft / Other" or "Google / Other" if Microsoft is empty)
> - Disable — run as a single `{base}` campaign (treats the run as `--no-segment`)
> - Abort

**If Phase 2 fails:** the failure is almost always a DNS lookup error on a stale or typo'd domain. Halt and surface the failing domain. Operator fixes the CSV or accepts "Unknown" bucket leaks and re-runs. No EB state has changed.

---

## Phase 3 — VARIABLES

**Purpose.** Create the `custom_variables` defined in the copy artifact in the EB workspace. These are merge-field definitions — values are attached per-lead in Phase 4. Running this before UPLOAD is required because `bulk_create_leads` will reject lead-level custom-variable values for variables that don't exist yet.

**With `--reference <campaign-id>` set:** call `get_campaign` (ground-truth the tool name via `search_api_spec`) on the reference campaign to fetch its variable set. Pre-fill the Phase 3 user gate with `{reference-variables}` as defaults. Operator still confirms — doesn't re-enter.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `custom variable create` — locate the exact tool (likely `create_custom_variable`). Also identify the `list_custom_variables` tool to check for pre-existing variables with the same name.
2. **Load variables from copy artifact.** From the parsed artifact (Phase 1 step 4), read `custom_variables[]`. Each entry has `{name, default}`. Example: `[{"name": "RECENCY_ANCHOR", "default": ""}, {"name": "PROOF_POINT_COMPANY", "default": ""}]`. The `default` is consumed in Phase 4 as the per-lead fill-in value when the CSV row lacks a column for this variable (see Phase 4 step 2 line 364) — it is NOT a workspace-scoped property of the variable in EB (per Sx-2, BC-6299 — EB's `POST /api/custom-variables` accepts only `{name}`).
3. **Check for existing variables.** Call `list_custom_variables` in the target workspace. For each artifact variable, classify:
   - **New** — not present in the workspace. Will create.
   - **Existing** — name matches; will NOT re-create (EB returns 422 on duplicate `POST /api/custom-variables`). Reuse as-is.
4. **Render the create plan.** Show the operator:

   > Variables to create in workspace `{workspace}`:
   > - `{RECENCY_ANCHOR}` (new) — will register name only; per-lead values applied at Phase 4
   > - `{PROOF_POINT_COMPANY}` (new)
   > - `{FREE_ASSET_NOUN}` (existing — will reuse name registration)
5. **User gate 3.** Ask via `AskUserQuestion`:

   > Create {N-new} new variables in `{workspace}`? Existing ones will be reused as-is (EB rejects duplicate POSTs).
   >
   > - Yes, create new + reuse existing (Recommended)
   > - Abort — fix the artifact or workspace state
6. **Execute creates.** For each new variable, call `create_custom_variable` with `{name}` only (per Sx-2, BC-6299 — EB's `POST /api/custom-variables` accepts only `name`; sending `default` is silently ignored). Collect the variable IDs returned by the API. If the tool returns a confirmation-gated response (unlikely for variable creation, but verify), follow the two-call pattern per BC-2707.
7. **Append to metadata JSON.** Persist `custom_variables_created: [{id, name}]` from each create response (response body is `{id, name, created_at, updated_at}` — no `default` field). Set `last_completed_phase: 3`. **Note (Sx-3, BC-6299):** EB silently lowercases names on store (`RECENCY_ANCHOR` → `recency_anchor`). Render-engine case-sensitivity is unverified — flagged for verification at BC-6308 round-3 Phase 4 lead spot-check.

**If Phase 3 fails:** the workspace has some, none, or all of the variables created depending on where in the loop the failure happened. The metadata JSON's `custom_variables_created` list is authoritative for what's on the vendor side. **Note (Sx-4, BC-6299):** there is no `DELETE /api/custom-variables/{id}` endpoint. Custom variables persist workspace-scoped indefinitely; only the EB UI can remove them. Operator inspects the workspace and either retains the partial set (recommended for next re-run, since duplicate POSTs return 422) or manually removes via the UI; then re-runs the phase from scratch or patches the artifact to skip already-created names.

---

## Phase 4 — UPLOAD

**Purpose.** Create lead records in the EB workspace with per-lead `custom_variables` values. Leads exist as workspace-level records first; Phase 6 attaches them to specific campaigns. This is the first destructive phase in the flow — leads in EB carry tracking history and touch quota, so creating them is not free.

**Two-call MCP confirmation gate required** per BC-2707 precedent. `bulk_create_leads` may or may not be vendor-gated — treat it as gated regardless. Pattern:

1. First call with no `confirmation` parameter — returns a prompt describing what will happen.
2. Relay the prompt verbatim to the operator via `AskUserQuestion`.
3. Wait for the operator's response. If clear affirmative scoped to the operation ("yes", "approved", "go ahead", "proceed", "do it"), make the second call with `confirmation: true`. If ambiguous ("maybe", silence, off-topic), stop and re-ask.
4. **Never** issue both calls in the same turn. The anti-pattern this gate blocks is the skill issuing both calls without a real user turn between them — not the wording of the affirmative (see `docs/precedents/BC-2707.md` for the turn-structure rationale).

**Gate cadence for chunked uploads.** At >500 leads the upload runs in N chunks of ≤500. Re-prompting a semantic "Are you sure?" per chunk trains gate-fatigue: the operator reflexively approves chunks 2..N and the gate stops being a real safety check. Separate the two concerns:

- **Semantic approval (operator-intent) — once**, via User gate 4 below, covering the entire batch. The operator sees the chunk count, sample rows, and lead-count total; approves the full run.
- **Turn-structure preservation (BC-2707) — per chunk**, via a minimal pass-through prompt that re-renders the vendor's per-chunk prompt verbatim. The prompt is deliberately thin ("Chunk i/N — vendor prompt: '{verbatim}'. Continue?") because the semantic gate already fired once; this prompt exists solely to create the user turn between call-1 and call-2 per BC-2707's turn-structure contract.

The turn-structure prompt IS an `AskUserQuestion` — it must be, to create a real user turn between the two vendor calls. Rapid-fire affirmatives ("y" / "yes" / "do it") from the operator are expected and valid — they preserve BC-2707 turn structure without burning semantic attention. Abort at any chunk halts the remaining chunks; chunks already committed stay.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `bulk create leads`. Per `email-bison.md` § Common workflows the verified endpoint path is `POST /api/leads/multiple` (NOT `/api/leads/bulk` — that's the CSV-upload variant). The conceptual label `bulk_create_leads` in this spec maps to that endpoint via `call_api`. Variant endpoints: `upsert_multiple_leads` (for merging against existing leads), `bulk_create_leads_csv` (CSV-upload variant, `POST /api/leads/bulk`). Default to `/api/leads/multiple` unless the artifact or operator instructs otherwise.
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

   The per-row custom_variables values come from CSV columns matching each variable name (case-insensitive), plus fallbacks from the copy artifact's `custom_variables[].default` for any variable the CSV doesn't cover.
3. **Chunk to the 500-lead limit.** `bulk_create_leads` and `upsert_multiple_leads` both accept 500 leads per call (verified in `email-bison.md` § Rate limits). If `lead_count > 500`, split into chunks of 500. Per the "Gate cadence for chunked uploads" note above, User gate 4 fires ONCE for the full batch; each chunk subsequently fires only a minimal turn-structure prompt.
4. **Show sample.** Before User gate 4, show the operator a sample of 3 leads (rows 2, middle, last) with full `custom_variables` rendered:

   > Sample of 3 leads from chunk 1 of {M}:
   >
   > 1. email: `alex@denvergov.org`, first_name: `Alex`, custom_variables: [RECENCY_ANCHOR: "the Denver downtown master plan announcement last month"]
   > 2. ...
   > 3. ...
5. **User gate 4 (semantic approval — once, covers all chunks).** Ask via `AskUserQuestion`:

   > About to create **{lead_count} leads in {M} chunks of ≤500** in workspace `{workspace}`. Sample (3 leads from chunk 1) shown above. Each chunk will vendor-gate with a minimal turn-structure prompt; semantic approval lives here.
   >
   > - Yes, create all {lead_count} leads across {M} chunks
   > - Abort the upload
6. **Per-chunk two-call loop with turn-structure preservation.** For each chunk `i` in 1..M:
   a. **First vendor call** — invoke `bulk_create_leads` without `confirmation`. Vendor returns the per-chunk prompt (typically: "This will create {N} lead records in workspace {W}. Proceed?").
   b. **Turn-structure prompt** (thin, fires per chunk to preserve BC-2707 turn structure — not a re-approval):

      > Chunk {i}/{M} — vendor prompt: "{verbatim vendor text}"
      >
      > - Continue
      > - Abort remaining chunks (chunks 1..{i-1} stay committed)

      Operator rapid-fire affirmatives are expected. The prompt exists solely to create the user turn required by the two-call gate.
   c. **Second vendor call — execute.** On "Continue", invoke `bulk_create_leads` again with `confirmation: true`. Capture the returned lead IDs. Loop to the next chunk.
7. **Abort handling.** On any chunk's "Abort remaining chunks" response, HALT — do not start the next chunk. Chunks 1..{i-1} remain committed (their leads exist in EB); `lead_ids_uploaded` in metadata reflects only committed chunks. Operator re-runs with a delta CSV if they want to resume.
8. **Verify lead count.** Sum the lead IDs across all chunks. Confirm `sum == lead_count` from Phase 1. If a chunk returned HTTP 422 the **whole chunk** rejected — bulk-POST is all-or-nothing on validation failure (Sx-8, BC-5906). The `call_api` wrapper surfaces only `{"error": "HTTP 422 Error"}` with no per-lead detail; per-row diagnostics require inspecting the EB UI for which rows tripped the batch. HALT with the body summary and the chunk's lead-row range; operator inspects EB UI, removes the offending row(s) from the CSV, and re-runs from Phase 4.
9. **Append to metadata JSON.** Set `lead_ids_uploaded: <total>`, `last_completed_phase: 4`.

**If Phase 4 fails mid-chunk:** some chunks have succeeded, others haven't. `lead_ids_uploaded` in the metadata is authoritative. Re-run reads the metadata, identifies that not all leads uploaded, and operator chooses to (a) delete the partial set via EB UI and re-upload from scratch, or (b) delta the CSV to only the unuploaded leads and re-run. The command does NOT auto-delta.

---

## Phase 5 — CAMPAIGN CREATE

**Purpose.** Create one empty campaign shell per ESP segment (or one total if `--no-segment`). Campaigns at this point have no leads, senders, schedule, or sequence — those come in phases 6–9.

**With `--reference <campaign-id>` set:** call `get_campaign` on the reference campaign to fetch its name template, offer metadata, and other config. Pre-fill the naming convention + description in the Phase 5 user gate.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `create campaign`. Per `email-bison.md` § Common workflows the name is `create_campaign` with path `POST /api/campaigns`. Returns a campaign ID.
2. **Determine campaign names.** If `--no-segment`: one campaign named `{campaign-name}`. Otherwise: one campaign per ESP bucket from Phase 2 (`esp_segments`). Default naming convention from the copy artifact's preset (if preset supplies one) or the Brite default:
   - `{Niche} | {Target} | {Source} | {Region} | {Size} | {Offer}` — full convention per issue spec
   - Short form (default): `{campaign-name-base} | {ESP}` — e.g., `Denver Downtown Lighting | Google`
   Operator can override the suffix format in the user gate.
3. **Render the create plan.** Show the operator each proposed campaign:

   > Campaigns to create in workspace `{workspace}`:
   > 1. `Denver Downtown Lighting | Google` — 84 leads
   > 2. `Denver Downtown Lighting | Microsoft` — 31 leads
   > 3. `Denver Downtown Lighting | Other` — 12 leads
4. **User gate 5.** Ask via `AskUserQuestion`:

   > Create {N} empty campaigns with the names above? Campaigns start in `Draft` state — no sends until Phase 11. After create, each campaign will be PATCHed with `plain_text: true` (cold-outreach deliverability default — no opt-out).
   >
   > - Yes, create these campaigns (Recommended)
   > - Rename — I'll supply a different suffix convention
   > - Abort
5. **Execute creates.** For each name in the plan, call `create_campaign`. Capture the returned campaign ID. Map bucket → ID.
6. **Verify IDs.** Confirm every bucket has a returned ID. If any campaign create fails, halt and surface the specific bucket + error. Do NOT retry automatically — a partial campaign set is easier to audit than a silently-retried one.
7. **Apply plain_text deliverability default.** For each campaign ID confirmed in step 6, call `update_campaign` (path `PATCH /api/campaigns/{id}/update` per `email-bison.md` § Tool inventory + verified via `search_api_spec`) with `plain_text: true`. This PATCH is **always** applied — it is a deliverability invariant for cold outreach (the only use case `/marketing:launch-campaign` serves) and has no operator opt-out. EB defaults `plain_text` to `false` on create, which sends emails as HTML; HTML mode for cold B2B carries tracking pixels, link rewrites, and image references that signal "automated marketing" to spam filters. The copy artifacts produced by `email-copywriting` use `<br><br>` for paragraph breaks and contain spintax — both assume plain-text rendering. Note: `update_campaign` is NOT on `email-bison.md` § MCP confirmation gates list; this is a single MCP call per campaign, no two-call cycle. PATCH is idempotent (re-asserting `plain_text: true` against an already-plain-text campaign is a no-op), so resume can re-run this loop blindly without harm. Track per-campaign PATCH success in scratch state for step 8's metadata write.
8. **Append to metadata JSON.** Set `campaign_ids: {"Google": 5551, "Microsoft": 5552, "Other": 5553}` (adjust keys per actual segmentation), `plain_text_applied: true` (only if step 7 PATCH succeeded for ALL campaigns; else `false`), `last_completed_phase: 5`.

**If Phase 5 fails mid-loop:** partial campaigns exist in the workspace. Metadata JSON lists the ones that succeeded and records `plain_text_applied: true` only if the step 7 PATCH loop completed for ALL campaigns. If `last_completed_phase: 5` was written but `plain_text_applied: false`, partial-PATCH state may exist (some campaigns plain-text, others HTML). Operator inspects EB UI, decides whether to delete the partial campaigns or resume by running a reduced version of Phase 5 that creates only the missing ones. On resume after partial-PATCH, the spec re-runs the step 7 PATCH loop on every campaign in `campaign_ids` regardless of prior state — PATCH is idempotent, so already-plain-text campaigns are no-ops. No automatic partial-resume.

---

## Phase 6 — ATTACH LEADS

**Purpose.** Attach the lead IDs created in Phase 4 to the campaign IDs created in Phase 5, bucketed by ESP segment. This is the join step between the lead pool and per-segment campaigns.

**Two-call MCP gate applies** per `email-bison.md` § MCP confirmation gates + `docs/precedents/BC-2707.md` (turn structure, not vocabulary) — `import_leads_to_campaign` is listed as vendor-gated.

**Gate cadence for multi-campaign attach (same pattern as Phase 4).** User gate 6 is the **semantic operator-intent gate** and fires ONCE for the full per-campaign batch. Per-campaign vendor gates fire a **minimal turn-structure prompt** — not a semantic re-approval. Rapid-fire affirmatives per campaign are expected; the prompt's only job is to create the user turn required by BC-2707's two-call contract.

**`allow_parallel_sending` alert** per `email-bison.md` § Known gotchas: if any lead being attached is already in another campaign's active sequence, the tool refuses and returns a prompt asking whether to enable parallel sending. **Never auto-enable this.** Surface the prompt verbatim to the operator via `AskUserQuestion` — parallel sending can over-contact a prospect across campaigns and is a deliverability risk. This is a genuine semantic gate (not turn-structure filler) because the decision materially changes who gets emailed.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `attach leads` or `import leads to campaign`. Per `email-bison.md` § Common workflows the name is `import_leads_to_campaign` with path `POST /api/campaigns/{id}/leads/attach-leads`.
2. **Bucket the lead IDs by ESP segment.** From the CSV + Phase 2 bucket assignments, build a map `{ESP bucket → [lead_id, lead_id, ...]}`. Each lead belongs to exactly one bucket.
3. **Show attach plan.** Render per-campaign counts:

   > Attach plan:
   > - `{campaign_ids.Google}` ← 84 leads
   > - `{campaign_ids.Microsoft}` ← 31 leads
   > - `{campaign_ids.Other}` ← 12 leads
   > Total: 127 leads attached across 3 campaigns.
4. **User gate 6 (semantic approval — once, covers all campaigns).** Ask via `AskUserQuestion`:

   > Attach {total} leads to {N} campaigns per the plan above? Per-campaign vendor gates fire with minimal turn-structure prompts after this one semantic approval.
   >
   > - Yes, proceed with attach across all {N} campaigns
   > - Abort
5. **Per-campaign two-call loop with turn-structure preservation.** For each campaign in the bucket map:
   a. **First vendor call** — invoke `import_leads_to_campaign` with campaign ID + lead IDs array, no `confirmation`.
   b. **Turn-structure prompt** (thin — per-campaign, preserves BC-2707 turn structure, not semantic re-approval):

      > Campaign `{id}` — vendor prompt: "{verbatim vendor text}"
      >
      > - Continue
      > - Abort remaining campaigns

   c. **Second vendor call — execute.** On "Continue", invoke again with `confirmation: true`.
   d. **`allow_parallel_sending` branch** (semantic, not turn-structure): if the vendor returns this prompt instead of the normal confirmation, treat it as a real semantic gate. Relay verbatim and ask the operator to either (a) decline (default) — delta the leads already in other campaigns, attach only the delta, list the skipped leads at the end, or (b) approve parallel sending — explicitly documented as a deliverability risk. Never auto-approve.
6. **Verify per-campaign counts.** After each attach, re-query the campaign's lead count (via `get_campaign` or equivalent) and confirm it matches the attached count. If mismatch, halt and surface the discrepancy.
7. **Append to metadata JSON.** The `campaign_ids` already list the per-campaign mapping. Add a sibling `lead_attach_counts` object mirroring `esp_segments`. Set `last_completed_phase: 6`.

**If Phase 6 fails mid-campaign:** some campaigns have attached leads, others don't. Metadata indicates which ran (`last_completed_phase`). Operator inspects EB UI per campaign and re-runs Phase 6 scoped to the unattached campaigns.

---

## Phase 7 — ATTACH SENDERS (CRITICAL INVARIANT)

**Purpose.** Attach every connected sender inbox to every campaign. This is the single most consequential phase of the flow, and the invariant it enforces is load-bearing for deliverability.

### The invariant

> **Attach ALL connected senders to ALL campaigns. Never split senders across campaigns.**

Why: sender warmup and reputation are per-inbox, not per-campaign. Splitting the sender pool across per-ESP campaigns concentrates volume on a subset of inboxes, which burns reputation unevenly and produces asymmetric deliverability across campaigns for no analytical benefit. Revgrowth 10's upstream `launch.py` encodes this as an explicit rule; Brite inherits it verbatim. **Any deviation from this invariant is a hard failure and must be surfaced to the operator — the command does not offer a split-sender flag.**

### Pagination is mandatory

**Note: `?per_page=N` is silently ignored** — EB hardcodes `per_page: 15` regardless of the parameter (Sx-10, BC-5906). For 500 connected senders that's ~34 pages; for 772 senders it's 52. Pagination is N/15 pages and not operator-configurable. Plan loop iteration counts accordingly.

Workspaces can have 500+ connected senders. `list_sender_emails` is cursor-paginated. The `while True` / cursor-loop pattern from Revgrowth 10:

```
senders = []
cursor = None
while True:
    response = list_sender_emails(cursor=cursor, filter={"status": "connected"})
    senders.extend(response.data)
    cursor = response.next_cursor
    if not cursor:
        break
```

Pagination applies at two points: (a) enumerating senders before attach, (b) re-querying post-attach for verification. Both loops must exhaust the cursor — never truncate after the first page.

### Steps

1. **Ground-truth the tool names.** `search_api_spec` with queries `list sender emails`, `attach sender emails`. Per `email-bison.md` § Common workflows the names are `list_sender_emails` (GET) and `attach_sender_emails_to_campaign` (POST `/api/campaigns/{id}/attach-sender-emails`). Request body: `{"sender_email_ids": [1, 2, 3]}`.
2. **Enumerate connected senders.** Run the `while True` pagination loop against `list_sender_emails` with filter `?status=connected` (lowercase). EB's status filter is case-sensitive in a non-obvious way: `?status=Connected` (matching the response `status: "Connected"` data field) returns 422 (Sx-11, BC-5906) — operators copying from response payloads will hit a 422 with no diagnostic. Always pass the lowercase form. Exhaust the cursor. Record the full list. If the workspace returns zero connected senders, HALT — no campaign can send without a sender, and silently proceeding would create campaigns that queue forever.
3. **With `--reference <campaign-id>` set:** call the reference campaign's `get_campaign` (or equivalent sender-list endpoint) to fetch its attached sender IDs. Pre-fill the gate to show "reference campaign had these senders attached — they are a subset of the current connected list." The invariant still applies — we still attach ALL connected senders from this workspace, not just the reference's subset. `--reference` pre-fills the display, not the attach payload.
4. **Render the attach plan.** Show the operator:

   > Sender pool for workspace `{workspace}`: {N-senders} connected senders.
   >
   > Attach plan (per-campaign count must match):
   > - `{campaign_ids.Google}` ← {N-senders} senders
   > - `{campaign_ids.Microsoft}` ← {N-senders} senders
   > - `{campaign_ids.Other}` ← {N-senders} senders
   >
   > Sender list preview (first 5): sender@brite.co, ops@brite.co, intro@brite.co, …
5. **User gate 7.** Ask via `AskUserQuestion`:

   > Attach ALL {N-senders} senders to ALL {N-campaigns} campaigns? This is the sender invariant — splitting is forbidden. Proceed?
   >
   > - Yes, attach full pool to every campaign (Recommended)
   > - Abort
6. **Execute attach per campaign.** For each campaign ID in `campaign_ids`:
   - Call `attach_sender_emails_to_campaign` with `{"sender_email_ids": [<all connected IDs>]}`.
   - If the vendor returns a confirmation-gated response (unlikely for sender attach, but verify), follow the two-call pattern.
7. **Post-attach verification (count-scalar first; paginate on mismatch).** The invariant enforcement step. For each campaign ID:
   - **Scalar check first** — call `get_campaign` and read the `attached_senders_count` (or equivalent count field returned without paginating). Compare to the pre-attach connected-sender count. The 99% case (clean attach, no drift) returns a count match and validates without paginating anything — 1 MCP call per campaign instead of the full sender-list pagination.
   - **If count scalar is absent OR mismatches** — THEN re-query the campaign's full attached-sender list via `get_campaign` + the `while True` pagination loop, diff the sender ID set against the pre-attach enumeration, and identify the specific missing/extra sender IDs. Pagination runs only when diagnostic detail is actually needed.
   - **If count mismatches by even one sender, HALT.** Surface the campaign ID, the expected count, the actual count, and the specific missing/extra sender IDs. Do not advance `last_completed_phase`.
   - **Ground-truth fallback** — if `get_campaign`'s schema doesn't expose a scalar count field this session (verify via `search_api_spec` once up-front), fall back to pagination-first on every campaign. Record the chosen verification mode in metadata: `sender_verify_mode: "scalar" | "paginated"`.
8. **Append to metadata JSON.** Set `sender_ids_attached: [<full list>]`, `sender_attach_counts: {"Google": N, "Microsoft": N, "Other": N}` — all three values MUST be equal (that's the invariant). `last_completed_phase: 7`.

### Forbidden patterns (hard failures)

- Splitting senders across campaigns (e.g., senders 1–10 to Google, 11–20 to Microsoft). Explicit anti-pattern — never shipped, never offered as an option.
- Truncating the pagination loop after the first page of `list_sender_emails`. The `while True` loop must exhaust the cursor.
- Skipping post-attach verification because the attach call returned 200. The vendor occasionally drops senders silently at high pool sizes; verification is the only authoritative check.

**If Phase 7 fails count verification:** the vendor's attached-sender set does not match the pre-attach enumeration. This is almost always a vendor-side transient — wait 30 seconds and re-query before declaring failure. If the discrepancy persists, HALT and surface the specific sender IDs that failed to attach. Operator manually attaches via EB UI and then re-runs from Phase 8.

---

## Phase 8 — SCHEDULE

**Purpose.** Apply a sending schedule to each campaign. Without a schedule a campaign cannot transition from Draft to Queued, so this phase is a prerequisite for Phase 11 ACTIVATE.

**Default schedule.** Mon–Fri 08:00–17:00 local timezone. Captures business-hour sending across most US time zones. Rendered at the operator's tz unless specified.

**With `--reference <campaign-id>` set:** call the reference campaign's endpoint to fetch its attached schedule template ID. Pre-fill the Phase 8 gate with the reference schedule — operator confirms re-use or picks an alternative.

**Steps:**

1. **Ground-truth the tool names.** `search_api_spec` with queries `schedule template list`, `create schedule from template`. Per `email-bison.md` § Common workflows the names are `get_schedule_templates` (list) and `create_schedule_from_template` (POST `/api/campaigns/{id}/create-schedule-from-template`). Request body: `{"schedule_id": N}`.
2. **List available schedule templates.** Call `get_schedule_templates`. Identify the template matching the Brite default (Mon–Fri 08:00–17:00). If no matching template exists, surface the full list and ask the operator to pick one — do NOT create a new template inline (that's a separate concern outside this command).
3. **Show schedule plan.** Render:

   > Schedule template selected: `{template-name}` (ID {schedule_id})
   > - Monday–Friday
   > - 08:00–17:00 (local timezone: {tz})
   > - Applies to all {N} campaigns.
4. **User gate 8.** Ask via `AskUserQuestion`:

   > Apply schedule `{template-name}` to all {N} campaigns? (All campaigns share the same schedule — per-campaign schedule override not supported in this command.)
   >
   > - Yes, apply (Recommended)
   > - Pick a different template — I'll show the full list
   > - Abort
5. **Execute apply per campaign.** For each campaign ID, call `create_schedule_from_template` with `{"schedule_id": N}`.
6. **Verify per campaign.** Re-read the campaign via `get_campaign` and confirm the schedule is attached. Halt on first mismatch.
7. **Append to metadata JSON.** Set `schedule_id: N`, `last_completed_phase: 8`.

**If Phase 8 fails mid-loop:** partial schedule application. Metadata records `last_completed_phase: 7`. Operator inspects the unscheduled campaigns via EB UI and re-runs Phase 8 scoped to those.

---

## Phase 9 — SEQUENCE

**Purpose.** Add the 2-step email sequence to each campaign. The step content comes from the copy artifact's `step_1` and `step_2` objects. This phase translates the copy artifact's schema into EB's sequence-step format.

**Skip if** `--no-sequence` is passed — campaigns will have empty sequences and cannot be activated until sequences are added out-of-band.

**Non-negotiable rules** (from `email-bison.md` § Known gotchas + copy artifact schema):

- Prefer v1.1 endpoint. Path `/api/campaigns/v1.1/{id}/sequence-steps` — the legacy `/api/campaigns/{id}/sequence-steps` is marked deprecated in the spec. Verify via `search_api_spec` this session.
- Field name `wait_in_days` (NOT `wait_days`). Deprecated name silently ignored by newer endpoints.
- Field name `email_subject` (NOT `subject`). Vendor requirement.
- Step 1 `wait_in_days >= 1`. Step 2 `wait_in_days >= 3`. These are enforced here regardless of what the copy artifact carries — the copy artifact may be used in testing with 0-day waits, but production sequences never ship with sub-day delays.
- Exactly 2 steps. 3+ is a hard failure — copy artifact schema enforces 2, but this phase re-checks in case of tampering.

**With `--reference <campaign-id>` set:** the reference campaign's sequence is NOT copied — the sequence comes from the copy artifact every time. `--reference` pre-fills sender/schedule/variables only.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `sequence steps create`. Per `email-bison.md` § Common workflows the v1.1 name is `create_sequence_steps` with path `POST /api/campaigns/v1.1/{campaign_id}/sequence-steps`. Request body: `{"title": ..., "sequence_steps": [{"email_subject", "email_body", "wait_in_days", "order", "variant", "thread_reply"}, ...]}`.
2. **Validate copy artifact step fields.** Reload the copy artifact (already in memory from Phase 1). Confirm:
   - `step_1.subject` present, no `{FIRST_NAME}` or merge variables in it.
   - `step_1.body` present, `<br><br>` paragraph breaks, no `<p>` tags, no em-dashes, no `{{` double-brace.
   - `step_2.subject` does NOT start with `Re:` — EB auto-prepends `Re: ` when `thread_reply: true`. HARD FAIL if the artifact's step_2.subject starts with `Re:` (would produce double-prefix `"Re: Re: ..."` in delivery — verified BC-5906 round-2 Sx-14).
   - `step_2.body` follows same format constraints.
   - `step_1.wait_in_days >= 0` (step 1 is typically 0 — sends immediately once the campaign resumes), but per production rule apply `max(1, artifact.step_1.wait_in_days)` for the actual API call. Document the override if the artifact had 0.
   - `step_2.wait_in_days >= 3` — HARD FAIL if the artifact has <3. Operator patches the artifact and re-runs.
3. **Build the request body.** For each campaign:

   ```json
   {
     "title": "{campaign-name-suffix}",
     "sequence_steps": [
       {
         "email_subject": "<copy artifact step_1.subject>",
         "email_body": "<copy artifact step_1.body>",
         "wait_in_days": <max(1, artifact.step_1.wait_in_days)>,
         "order": 1,
         "variant": false,
         "thread_reply": false
       },
       {
         "email_subject": "<copy artifact step_2.subject>",
         "email_body": "<copy artifact step_2.body>",
         "wait_in_days": <artifact.step_2.wait_in_days>,
         "order": 2,
         "variant": false,
         "thread_reply": true
       }
     ]
   }
   ```

   `thread_reply: true` on step 2 ensures it threads under step 1 in the recipient's inbox AND triggers EB to auto-prepend `Re: ` to `email_subject` at delivery. The artifact's bare step_2.subject becomes `"Re: <subject>"` in the recipient's inbox — do NOT include `Re:` in the artifact value.
4. **Show sequence plan.** Render the step 1 + step 2 subjects + body first-line-snippets for operator review.
5. **User gate 9.** Ask via `AskUserQuestion`:

   > Create 2-step sequences on all {N} campaigns? Step 1 wait: {X} days. Step 2 wait: {Y} days.
   >
   > - Yes, create sequences (Recommended)
   > - Abort
6. **Execute create per campaign.** For each campaign ID, call `create_sequence_steps` with the request body above. Capture returned sequence IDs.
7. **Verify per campaign.** Re-read via `get_campaign` or `get_sequence_steps`. Confirm 2 steps present with correct `wait_in_days` and `email_subject` fields. Halt on first mismatch.
8. **Append to metadata JSON.** Set `sequence_ids: {"Google": 8801, "Microsoft": 8802, "Other": 8803}`, `last_completed_phase: 9`.

**If Phase 9 fails mid-campaign:** partial sequence creation. Metadata lists completed campaigns. Operator inspects EB UI, deletes the partial sequences if desired, and re-runs scoped to unsequenced campaigns.

---

## Phase 10 — PREVIEW

**Purpose.** Produce a final rendered-email preview so the operator can visually confirm variable substitution, spintax resolution, and format compliance before Phase 11 ACTIVATE. This is the last sanity check before sending becomes possible.

**Critical correction from BC-5826 X17 dogfood (F13):** Email Bison does **not** expose a standalone preview endpoint. `search_api_spec` on `preview email`, `sequence preview`, `render` returns no matches. The only preview-adjacent endpoint is `POST /api/campaigns/sequence-steps/{sequence_step_id}/test-email`, which requires Phases 4–9 to have completed (for the sequence step to exist) AND actually sends a real email to a specified recipient. That's a test-send, not a preview.

Phase 10 therefore has two modes:

1. **Default mode: local render.** Client-side render from the copy artifact + one representative lead's CSV data. No EB call. No email sent. Always runs.
2. **Optional mode: real EB test-send.** Only if `--test-send <email>` is passed. Calls `POST /api/campaigns/sequence-steps/{sequence_step_id}/test-email` with the operator's inbox as the recipient. Real email delivered. Additive — runs after the local render.

### Mode 1 — Local render (default)

**Steps:**

1. **Pick a preview lead.** Prefer the first lead in the largest ESP bucket. Fall back to row 2 of the CSV. Read the lead's CSV row.
2. **Build the variable values map.** For each `{VARIABLE}` extracted from step_1/step_2 subject+body:
   - EB-standard variables (`FIRST_NAME`, `LAST_NAME`, `COMPANY`) resolve from the lead's CSV fields (`first_name`, `last_name`, `company_name`).
   - All other variables resolve from `custom_variables[].default` in the copy artifact.
   - `{SENDER_*}` variables resolve per Phase 1 step 7 priority chain.
3. **Substitute variables.** For each `{VARIABLE}` key found in subject or body, replace with the resolved value from step 2.
4. **Resolve spintax deterministically.** For each `{option1|option2|option3}` group, pick the **first** option. Deterministic so the preview is reproducible. Document this explicitly to the operator: "Spintax rendered with first-option pick for deterministic preview; actual sends will rotate options."
5. **Apply format substitutions.** Replace `<br><br>` with paragraph breaks (`\n\n`), `<br>` with single newlines, for display.
6. **Sanity checks on rendered output.** These MUST all pass; if any fails, HALT and surface the specific issue:
   - No unresolved `{VARIABLE}` tokens remain (regex `\{[A-Z_]+\}` matches nothing)
   - No unresolved spintax remains (regex `\{[^{}]*\|[^{}]*\}` matches nothing)
   - No em-dash (`—`) in body
   - No `<p>` or `</p>` in body
   - No `{{` double-brace
7. **Display to operator.** Render both step_1 and step_2 with clear section headers:

   > **Preview — campaign `{campaign-name} | Google`, lead `alex@gmail.com`:**
   >
   > **STEP 1**
   > Subject: Quick question
   >
   > Saw the downtown master-plan announcement at Test Denver City Alex, and it lined up with a pattern we've been watching across municipalities.
   >
   > Most municipalities teams we work with run into downtown lighting specs getting stuck at design review, and one that solved it was Boulder Pearl Street, who ran 38% higher evening foot traffic in 2024.
   >
   > …
   >
   > **STEP 2** (wait 4 days)
   > Subject: Quick question  *(EB auto-prepends `Re: ` at delivery — recipient sees `"Re: Quick question"`)*
   >
   > Circling back in case it got buried. Still happy to send the architectural lighting preview whenever it's useful.
   >
   > …

   Also surface "what to look for" prompts: unnatural subject lengths, awkward variable juxtaposition, missing greeting merge, any spintax option that reads oddly when rendered.

8. **Append to metadata JSON.** Set `preview_rendered_at: "<ISO-8601>"`, `preview_method: "local-render"`, `preview_lead_email: "<email>"`, `last_completed_phase: 10`.

### Mode 2 — Optional real EB test-send (`--test-send <email>`)

Additive to Mode 1 — Mode 1 always runs first. Mode 2 only fires if `--test-send <email>` was passed AND Mode 1 passed all sanity checks AND the `--test-send` value passed Input validation § IV-5 (regex + Brite-internal domain allowlist). Any IV-5 failure skips Mode 2 with an informative message — does NOT error the whole Phase 10.

**Preconditions:** Phases 4–9 completed (sequence step exists in EB, lead attached to campaign). If any precondition fails, skip Mode 2 with an informative message — do NOT error the whole Phase 10.

**Steps:**

1. **Ground-truth the endpoint.** `search_api_spec` for `POST /api/campaigns/sequence-steps/{sequence_step_id}/test-email` — confirm path + required body fields (`sender_email_id`, `to_email`). Build the `call_api` body via **structured JSON construction** per IV-5 (never string concatenation of the email value).
2. **Pick a sender.** Default to the first attached sender from Phase 7. Operator can override with `--test-send-sender <id>` if they want a specific mailbox to send from.
3. **Safety surface to operator** — this mode SENDS A REAL EMAIL. Before the call, make the blast radius explicit:

   > **Mode 2 — real test-send.** This will deliver a real email to `{--test-send email}` via sender `{sender_id}`, using sequence step `{step_1_id}` from campaign `{campaign_name | Google}`. The email counts toward sender reputation and daily limits. No lead is contacted.
4. **User gate 10b** (real-send confirm):

   > Send real test email to `{test-send email}`?
   >
   > - Yes, send test to my inbox
   > - Skip test-send (Mode 1 local render is already complete)
5. **Execute test-send.** Call `call_api` with `POST /api/campaigns/sequence-steps/{step_1_id}/test-email` and body `{"sender_email_id": N, "to_email": "<test-send email>", "use_dedicated_ips": false}`. Record the response.
6. **Append to metadata JSON.** Extend `preview_method` to `"local-render + test-send"`, add `test_send_recipient: "<email>"`, `test_send_at: "<ISO-8601>"`.
7. **Prompt operator to check inbox.** Ask them to visually confirm the email rendered correctly in a real mail client (plus or beyond what local render showed).

### User gate 10 (single gate, both modes)

After Mode 1 completes (and optionally Mode 2):

> Preview rendered above (local + optional real test-send). Everything look right? This is the last chance to catch render issues before activation.
>
> - Yes, preview looks clean
> - Problem — I'll describe it and abort

### Behavior when `--activate` is NOT set

After Phase 10 completes, surface the final summary message and exit:

> Launch flow complete at Phase 10. Campaigns created in `Draft` state:
> - `{campaign_ids.Google}` — 84 leads, 2-step sequence, ready to activate
> - `{campaign_ids.Microsoft}` — 31 leads, 2-step sequence, ready to activate
>
> Metadata: `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json`
>
> To activate, re-run this command with the same arguments plus `--activate`. Phases 1–10 are idempotent on re-run (read-only or detection-gated); Phase 11 only fires with the flag.

### If Phase 10 fails

- **Mode 1 sanity-check failure:** the local render surfaced an unresolved variable, unresolved spintax, em-dash, `<p>` tag, or double-brace. Fix the copy artifact at the source (re-run `email-copywriting` skill, or hand-patch the JSON) and re-run the command. Previous Phase 1–9 state persists; the command is idempotent through Phase 10.
- **Mode 2 test-send failure:** the vendor endpoint errored. Mode 1's local render remains valid for the operator's review. The operator can either (a) skip the test-send and proceed based on local render, or (b) manually spot-check via the EB UI's own preview feature before `--activate`. Do NOT auto-retry — test-sends count against quotas.

---

## Phase 11 — ACTIVATE (optional, `--activate` only)

**Purpose.** Transition every campaign from `Draft` to `Queued`. This is the single destructive, sending-real-emails step in the flow. The vendor MCP description for `resume_campaign` literally reads "STARTS SENDING REAL EMAILS" (per `email-bison.md` § MCP confirmation gates).

**This phase only runs if `--activate` was passed.** Without the flag, the command exits after Phase 10 with campaigns in `Draft`.

### Double-confirm gate

Phase 11 requires two distinct user confirmations per campaign:

1. **Operator-intent gate** (this phase, skill-level). An `AskUserQuestion` before any vendor call, surfacing the scope of what's about to happen and requiring explicit approval.
2. **Vendor MCP two-call gate** (per BC-2707). First call to `resume_campaign` returns a vendor prompt; the skill relays it verbatim; on operator affirmative turn, second call with `confirmation: true`.

The two gates are layered — the operator says "yes" twice per campaign, in two different contexts, with both gates' prompts rendered separately. The anti-pattern this layering blocks: the skill issuing both the intent gate and the vendor gate's second call in the same turn without real user turns between them. Per `docs/precedents/BC-2707.md` the guarantee being enforced is turn structure, not vocabulary — accept any clear affirmative ("yes", "approved", "go ahead", "proceed", "do it"); ambiguous or silent responses still halt.

### Steps

1. **Ground-truth the tool name.** `search_api_spec` with query `resume campaign`. Per `email-bison.md` § Common workflows the name is `resume_campaign` with path `PATCH /api/campaigns/{id}/resume`.
2. **Final summary to operator** (pre-first-gate):

   > Phase 11 ACTIVATE — this will transition {N} campaigns from `Draft` to `Queued` and begin sending real emails. Summary:
   > - `{campaign_ids.Google}` — 84 leads, step 1 sends on the campaign's next scheduled window
   > - `{campaign_ids.Microsoft}` — 31 leads, same
   > - `{campaign_ids.Other}` — 12 leads, same
   >
   > Sender pool: {N-senders} inboxes per campaign.
   > Schedule: Mon–Fri 08:00–17:00 {tz}.
   >
   > Metadata will update `activated: true` and `activated_at` on success.
3. **User gate 11a — operator intent.** Ask via `AskUserQuestion`:

   > Activate all {N} campaigns now? Each campaign gates separately at the vendor level too.
   >
   > - Yes, proceed to vendor gates
   > - Abort
4. **Per-campaign vendor gate loop.** For each campaign in the bucket map:
   - First call to `resume_campaign` with campaign ID, no `confirmation`. Vendor returns the prompt (typically: "This will transition campaign {id} from Draft to Queued and begin sending emails. Proceed?").
   - **User gate 11b — vendor confirmation.** Relay the vendor prompt verbatim via `AskUserQuestion`:

     > Vendor prompt for campaign `{campaign-name} | Google`: "{vendor-prompt-text}"
     >
     > - Yes, activate this campaign
     > - Abort the entire Phase 11 (already-activated campaigns stay activated)
   - On operator affirmative, second call with `confirmation: true`. Record the returned campaign state (should be `Queued`).
   - On operator abort, HALT the loop — do not continue to other campaigns. Already-activated campaigns in this loop remain activated; record them in metadata.
5. **Post-activate verification.** For each activated campaign, call `get_campaign_stats` (or equivalent) and confirm `status: "Queued"` as directed in `email-bison.md` § Common workflows. Capture the initial counters for the final report.
6. **Finalize metadata JSON.** Set `activated: true`, `activated_at: "<ISO-8601-of-final-resume-call>"`, `last_completed_phase: 11`.
7. **Final report to operator:**

   > Launch complete. {N} campaigns activated in workspace `{workspace}`:
   > - `{campaign-name} | Google` (id {id}) — Queued, 84 leads, first sends next scheduled window
   > - `{campaign-name} | Microsoft` (id {id}) — Queued, 31 leads, same
   > - `{campaign-name} | Other` (id {id}) — Queued, 12 leads, same
   >
   > Metadata written to `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json`.
   >
   > Monitor via `get_campaign_stats` or the Email Bison UI.

### Forbidden patterns in Phase 11 (hard failures)

- Issuing both `resume_campaign` calls in the same turn without a real operator turn between them. Defense-in-depth against same-turn auto-confirm per BC-2707.
- Skipping the operator-intent gate (11a) even when "yes" was implicit from the `--activate` flag being passed. The flag authorizes the phase to run; it does not authorize skipping the intent gate.
- Continuing the loop after an operator abort. The phase halts on the first abort — other campaigns wait for a future run.
- Auto-confirming the vendor gate because the vendor prompt text is predictable. The gate is the *structure*, not the text.

**If Phase 11 fails mid-loop:** some campaigns are activated, others are still in Draft. Metadata records the state. Operator re-runs with `--activate` and the command picks up at the first un-activated campaign — but note that re-running from scratch still executes Phases 1–10 as no-ops (all state detection-gated); this is intentional and keeps the re-run idempotent.

---

## Error recovery — overview

Each phase documents its own failure mode inline. This section is the meta-view: what state each phase leaves in the EB workspace and in the metadata JSON, and how to resume.

| Phase | EB workspace state if phase fails | Metadata JSON state | Resume strategy |
|---|---|---|---|
| 1 PRE-FLIGHT | Unchanged (read-only) | Partial or missing — only inputs populated | Fix input (CSV / copy artifact / marketing-context), re-run from scratch |
| 2 HOST LOOKUP | Unchanged (read-only) | `segmented`, `esp_segments` populated | Fix failing domain lookup, re-run from scratch |
| 3 VARIABLES | Some variables created, others not | `custom_variables_created` lists succeeded names | Inspect EB UI, delete partials OR delta artifact to skip created names, re-run |
| 4 UPLOAD | Some leads created (up to the chunk that failed) | `lead_ids_uploaded` = total actually created | Inspect EB UI; operator chooses to delete partials and re-upload OR delta CSV and re-run |
| 5 CAMPAIGN CREATE | Some campaigns exist, others don't | `campaign_ids` map populated with succeeded buckets | Delete partial campaigns OR manually create missing ones and patch metadata, re-run |
| 6 ATTACH LEADS | Some campaigns have leads attached | Nothing phase-6-specific in metadata — `last_completed_phase` is the check | Re-run scoped to unattached campaigns |
| 7 ATTACH SENDERS | Count mismatch on one or more campaigns (invariant violation) | `sender_ids_attached`, `sender_attach_counts` | Manual attach via EB UI + re-run from Phase 8, OR HALT and surface to operator |
| 8 SCHEDULE | Some campaigns have schedules, others don't | `schedule_id` set if Phase 8 ran at all | Re-run scoped to unscheduled campaigns |
| 9 SEQUENCE | Some campaigns have sequences, others don't | `sequence_ids` populated with succeeded buckets | Delete partial sequences OR manually patch missing ones, re-run scoped |
| 10 PREVIEW | Unchanged (read-only) | `preview_rendered_at` set if rendered | Skip preview and proceed, OR investigate render tool error |
| 11 ACTIVATE | Some campaigns Queued, others still Draft | `activated: true` only if ALL campaigns completed | Re-run with `--activate`; Phases 1–10 re-execute as no-ops; Phase 11 picks up at first un-activated campaign |

### General resume rules

- **Re-running the command is idempotent through Phase 10.** Phases 1–3 are read-only / detection-gated. Phases 4–6 do create state but re-running will either collide with existing IDs (prompting a gate to skip) or simply re-execute (in which case the operator declines at the gate). The command does not auto-skip previously-created state — operators are expected to read `last_completed_phase` in the metadata and decide manually whether to patch inputs, abort, or proceed.
- **Never re-activate a Queued campaign.** Phase 11 is NOT idempotent; calling `resume_campaign` on an already-Queued campaign may no-op or error depending on the vendor's current version. The command's Phase 11 loop skips campaigns whose metadata shows they're already activated.
- **Metadata JSON is authoritative for resume.** If the metadata file is missing after a failure, treat the entire run as lost and restart from Phase 1. The JSON is written progressively — any phase that completed should have left a trace.
- **When in doubt, inspect the EB UI.** Campaigns, sequences, leads, and senders are all visible in the workspace. The EB UI is the ground truth if the metadata JSON ever disagrees with vendor state.

---

## Verification checklist

Before marking this command shipped, confirm:

- [ ] File exists at `plugins/marketing/commands/launch-campaign.md` with valid frontmatter (description, argument-hint, allowed-tools).
- [ ] `allowed-tools` includes `mcp__emailbison-b2b__*`, `mcp__emailbison-personal__*`, `mcp__plugin_marketing_salesforce__*`, Read, Write, Glob, Grep, Bash, AskUserQuestion.
- [ ] All 11 phases named and ordered correctly (PRE-FLIGHT / HOST LOOKUP / VARIABLES / UPLOAD / CAMPAIGN CREATE / ATTACH LEADS / ATTACH SENDERS / SCHEDULE / SEQUENCE / PREVIEW / ACTIVATE).
- [ ] Every mutating phase (3/4/5/6/7/8/9/11) has an explicit semantic "USER CONFIRM" gate, and Phase 10 Mode 2 (`--test-send`) has its own intent gate (10b) before the real test-send.
- [ ] Phases 4 and 6 use **one semantic gate + minimal per-chunk/per-campaign turn-structure prompts** rather than re-prompting semantic approval per loop iteration (BC-2707 turn-structure preserved without gate fatigue).
- [ ] Phase 7 ATTACH SENDERS documents the paginated `while True` pattern AND post-attach count verification; sender-split pattern is explicitly forbidden.
- [ ] Phase 4 UPLOAD uses the two-call MCP confirmation gate (references BC-2707 precedent).
- [ ] Phase 11 ACTIVATE requires double-confirm (operator-intent + MCP two-call).
- [ ] Phase 9 SEQUENCE enforces: step 1 `wait_in_days >= 1`, step 2 `wait_in_days >= 3`, field name `wait_in_days` (not `wait_days`), field name `email_subject` (not `subject`), 2-step max.
- [ ] Phase 1 PRE-FLIGHT validation checklist includes variable check, messaging sanity, lead spot check, workspace guard, unique-per-lead auto-toggle at <500.
- [ ] All 4 required args + 9 flags documented (`--no-segment`, `--no-host-lookup`, `--no-sequence`, `--activate`, `--preview`, `--reference`, `--entity`, `--test-send`, `--test-send-sender`); `argument-hint` frontmatter lists all 9.
- [ ] § Input validation section present with IV-1..IV-7 covering CSV-path safety, path confinement, dogfood path detection, domain regex filter, --test-send validation, SOQL email regex, metadata-no-credentials.
- [ ] Error recovery documented per phase (partial state + resume procedure).
- [ ] Launch metadata write path `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` documented.
- [ ] Dogfood transcript (test campaign on `emailbison-personal`, 5–10 leads) attached to BC-5826 as a comment — activated or draft-only. Phase 10 Mode 1 (local render) MUST succeed with all 5 sanity checks passing. Phase 10 Mode 2 (`--test-send`) is optional and only validated if the flag was passed.
- [ ] `email-bison.md` §Consumed by / §Related skills lists this command as a consumer.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
