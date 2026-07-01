---
disable-model-invocation: true
description: Turn an enriched lead CSV + email-copywriting JSON artifact into an activated Email Bison campaign via an 11-phase flow with user confirmation gates at every mutating step. Consumes the BC-5825 copy artifact and the BC-2718 campaign-orchestration defaults. Default path creates campaigns in draft state; pass --activate to transition them to queued (starts real sending).
argument-hint: --csv <path> --workspace <emailbison-b2b|emailbison-personal> --copy-artifact <path> --campaign-name <base> [--entity <brite-nites|brite-labs>] [--identity <labs|supply|nites>] [--sender-match <identity|esp|both|all>] [--no-host-lookup] [--no-sequence] [--preview] [--activate] [--reference <campaign-id>] [--test-send <email>] [--test-send-sender <id>]
allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep, Bash, AskUserQuestion, Skill
---

<!-- eval-waiver: An eleven-phase Email Bison campaign launcher whose substance is LLM-driven: per-lead spintax and Liquid rendering checks, operator-gate narration, nine-cell segmentation prose, and live MX, SOQL, and EB round-trips; the deterministic fragments (input validators, the static role and free-mail classifier, ESP bucketing) are scattered helper checks woven into Bash and gate prose, not a single separable decide(inputs, injected_reads)-to-artifact core, and every consequential output depends on live EB workspace state and operator turns. -->

# /marketing:launch-campaign

Execute the 11 phases below sequentially. Use `AskUserQuestion` at every numbered user gate — the user must explicitly approve before you proceed. If they answer anything other than the "proceed" option, halt the phase and help resolve the blocker before re-asking.

**Inputs:**

- **CSV** — enriched lead file at `--csv`. Required columns: `email`, `first_name`, `company_domain`. Optional columns: `last_name`, `job_title`, `company_name`.
- **Copy artifact** — a BC-5825 email-copywriting JSON at `--copy-artifact`. Schema: `plugins/marketing/skills/email-copywriting/SKILL.md` § JSON artifact schema. The artifact carries `step_1`, `step_2`, `custom_variables[]`, `entity`, `offer_posture` (per ADR-017; legacy alias `offer_tier` accepted as a read-side backward-compat shim for one release cycle — 6-month deprecation window from PR-merge).
- **Workspace** — `emailbison-b2b` (send.outbase.so, workspace 55) or `emailbison-personal` (personal.outbase.so, workspace 13). Must match the entity per `plugins/marketing/tools/integrations/email-bison.md` § Auth.

**Outputs:**

- **Launch metadata JSON** at `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json` — written progressively, one phase at a time. On partial failure, the metadata file IS the breadcrumb — re-run picks up from `last_completed_phase + 1` manually.
- **EB workspace state** — one or more campaigns in `Draft` (default) or `Queued` (with `--activate`).

**Precedent + upstream sources:**

- `plugins/marketing/tools/integrations/email-bison.md` § Common workflows / § MCP confirmation gates / § Known gotchas — ground truth for every tool name and call shape.
- `docs/precedents/BC-2707.md` — two-call MCP confirmation-gate semantics (turn structure, not vocabulary).
- `plugins/marketing/skills/email-copywriting/SKILL.md` — source of the copy artifact this command consumes.
- [Revgrowth1/ai-gtm-workflows workflow 10](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/10-campaign-launch) (MIT) — upstream 9-step launch flow; this command extends it with workspace disambiguation, Brite entity awareness, and BC-2707's two-call MCP gate precedent.
- **BC-6514** — segmentation-axis architectural decision (multiplicative ESP × email-type as default; single `--no-host-lookup` opt-out; `--no-segment` removed). See `docs/designs/BC-6514-segmentation-axis-decision.md`.
- **BC-6654** — spec rewrite + metadata schema migration applying BC-6514's call to Phase 2 (9-cell grid + gate-2 prompt), Phase 5 (naming + multiplicative loop), and downstream phase 6/7/9/10/11 examples.

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
3. The two-call gate BC-2707 requires is a real operator turn *before* the mutating `call_api` (step 2) — **not** a second API call. For every extended-tier tool this command actually invokes (`bulk_create_leads`, `import_leads_to_campaign`, `resume_campaign`), step 2 fires **exactly once**, only after an `AskUserQuestion` turn: these endpoints have no `confirmation` parameter and no dry-run (see the **Vendor confirmation gates via `call_api`** note below), so issuing the request a second time would double-apply the mutation. A literal second `call_api` with `confirmation: true` applies **only** to a hypothetical tool that genuinely advertises a `confirmation` parameter — none of this command's do.

Tool names in phase narratives are conceptual labels for the operation, not directly-callable function names. When a phase says "call `bulk_create_leads`," read that as "invoke the ground-truthed bulk-create-leads endpoint via `call_api` following the pattern above."

**Vendor confirmation gates via `call_api` (Sx-9, BC-5906; BC-6439).** Extended-tier tools advertised by `discover_tools` may describe `confirmation` parameters and two-call vendor gates in their tool prose. **No runtime-enforced gate exists for these tools at any layer.** Round-2 dogfood verified: `/api/leads/multiple` POST and `/api/campaigns/{id}/leads/attach-leads` POST have no `confirmation` field at the API level; `/api/campaigns/{id}/resume` follows the same pattern. BC-6439 then verified that none of `resume_campaign`, `import_leads_to_campaign`, or `bulk_create_leads` appear as direct callables in the `mcp__emailbison-personal__*` namespace — they surface only as `tier: extended` description strings in `discover_tools`, with the explicit instruction to invoke via `search_api_spec` + `call_api`. The `confirmation` prose in those descriptions is documentation aimed at the agent's planning loop, not a wrapper-layer gate that's being routed around. The agent-side `AskUserQuestion` semantic gate is therefore **the sole safeguard** for every `call_api`-routed mutation. BC-2707's turn-structure rationale still applies to the operator-side gate (model must yield to the user between any two consequential calls); it just lives at the agent layer because no vendor layer is implemented. There is no future migration path to wrapper-tool invocation for these tools — closure of BC-6439 (2026-04-29).

**Allowed-tools breadth.** The frontmatter uses wildcards (`mcp__emailbison-b2b__*`, `mcp__emailbison-personal__*`) rather than an explicit tool list because every extended-tier operation flows through `call_api`, so narrowing the allowlist below `call_api` + `search_api_spec` + the ~10 core-tier tools this command reads from would still authorize every extended-tier operation via `call_api`. Explicit narrowing therefore buys no security — the real authorization boundary is `call_api`'s endpoint path + the operator gate. The workspace plugin has ~141 EB tools total; this command deliberately ignores the vast majority and relies on the phase-level user gates + `call_api`-only extended-tier contract for blast-radius control, not frontmatter narrowing.

---

## Input validation

Run this block before Phase 1. Every input that flows into `Bash`, the metadata write path, or the EB `call_api` body must pass the checks below. Halt with a clear error on any failure. No operator gate — these are mechanical safety invariants that fail closed.

**IV-1. `--csv` path — reject unsafe characters.** Before any `Bash` invocation (`head`, `wc`, `awk`, `dig`), validate the path is composed of `[A-Za-z0-9._/-]` only. Reject anything containing shell-metacharacters, quotes, whitespace, or backslashes. The subsequent Bash calls single-quote the path; this is defense-in-depth against interpolation escape. No auto-sanitization — if the path fails the check, the operator resubmits.

**IV-2. `--csv` path — normalize and confine to repo root.** Resolve the path via `realpath` (or `readlink -f`). The resolved path MUST begin with the output of `git rev-parse --show-toplevel`. This rejects any path that resolves outside the current repository via relative segments. Halt on any resolution mismatch.

**IV-3. Dogfood-path detection (tightened).** The § Launch metadata schema "Dogfood write path" auto-override uses the **normalized** path from IV-2, not the raw `--csv` string. Match the normalized path against `<repo-root>/.claude/worktrees/<worktree-name>/` followed by any sub-path, where `<worktree-name>` matches `[A-Za-z0-9._-]+`. Extract `<worktree-name>` from the match, set metadata write directory to `<repo-root>/.claude/worktrees/<worktree-name>/dogfood/`. Any normalized path not matching this structured pattern uses the default `docs/campaigns/{short_entity}/` path. No prefix substring matching.

**IV-4. Extracted-domain safety (Phase 2 pre-dig filter).** Phase 2 parses the domain from each CSV email column. Before passing any domain value to `dig`, require it to match regex `^[A-Za-z0-9][A-Za-z0-9.-]{0,253}[A-Za-z0-9]$`. Drop anything that doesn't match with a warning logged per skipped row. Poisoned CSV rows whose email column contains characters outside this set cannot reach the `dig` invocation. Record dropped rows in Phase 2 metadata (`invalid_domain_rows: [<row-numbers>]`).

**IV-5. `--test-send <email>` validation (Phase 10 Mode 2 pre-call).** If `--test-send` is present, validate the email against regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`. Halt Mode 2 (not the whole Phase 10) on regex failure. The email then flows into the `call_api` body via **structured JSON construction** (the agent's JSON serializer), never via string concatenation. Per-send safety is provided by the Phase 10 Mode 2 step 4 operator-confirmation prompt, which displays the exact recipient address and requires explicit Y/n affirmation before the `call_api` fires. See [ADR-011](../../../docs/decisions/011-launch-campaign-iv5-allowlist-removal.md) for the rationale behind removing the prior domain-allowlist layer.

**IV-6. Operator-email SOQL interpolation (Phase 1 step 7.3).** Before interpolating the operator-email value into the SOQL `WHERE Email = '{operator-email}' LIMIT 1` clause, validate against the same email regex in IV-5. On regex failure, skip step 7.3 entirely and fall through to step 7.4 (operator-prompt fallback). The SOQL path is not the sole resolution path; failing closed here is cheap.

**IV-7. Metadata JSON — no credential values.** The metadata write path documented in § Launch metadata schema writes only workspace labels, campaign IDs, lead counts, timestamps, and resolution-method tags. It **never writes** tokens, keys, session IDs, or any value sourced from a credential env var. When a phase needs to record the **source** of a credential (e.g., "sender auth came from the b2b workspace token"), log the source **name** (e.g., `"sender_auth_source": "workspace-token-env"`), not the value. Enforcement is by construction — the schema enumerates permitted fields; any phase that would write a credential value is a bug.

**IV-8. `--campaign-name` validation + write-path confinement.** `--campaign-name` flows into two on-disk paths: the metadata JSON path (`docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json`, written at Phase 1 step 10) and the Phase 2 sidecar CSV path (`docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}-skipped.csv`, written at Phase 2 step 4c). Both paths interpolate `{campaign-name}` directly. Without validation, a poisoned value like `../../../tmp/exfil` or `foo/../../etc/x` lets metadata + lead PII (sidecar) land outside the expected directory.

Two-step enforcement, applied once at Phase 1 pre-flight (before any path is interpolated):

1. **Regex validation.** `--campaign-name` MUST match `^[A-Za-z0-9][A-Za-z0-9 _.-]{0,79}$`. Allows letters, digits, space, underscore, period, hyphen; first char must be alphanumeric (no leading dot to prevent hidden-file paths); cap at 80 chars. Reject `/`, `\`, `..`, quotes, shell metacharacters, control chars. No auto-sanitization — operator resubmits.

2. **Realpath confinement of the resolved write path.** After constructing the metadata JSON path or sidecar CSV path, resolve via `realpath` (or `readlink -f`) and confirm the resolved absolute path begins with the resolved absolute path of the chosen write directory:
   - Default path: must begin with `<repo-root>/docs/campaigns/{short_entity}/`
   - Dogfood path: must begin with `<repo-root>/.claude/worktrees/<worktree>/dogfood/` (with `<worktree>` already validated by IV-3)

   On mismatch, halt with a clear error; do NOT auto-correct. This is defense-in-depth against the regex missing an edge case (e.g., Unicode lookalikes, NFC-vs-NFD normalization differences).

The two-step pattern mirrors IV-1 + IV-2 for `--csv`. Pre-existing exposure: prior to BC-6307 the metadata JSON path also interpolated `{campaign-name}` without validation; IV-8 closes that gap retroactively.

**IV-9. Sidecar CSV formula-injection neutralization (Phase 2 step 4c).** The sidecar CSV preserves "original CSV columns verbatim (preserve order)" — meaning whatever the upstream lead source put into a field like `first_name` or `company_name` lands in the sidecar verbatim. Hostile content from third-party enrichment vendors or operator-curated lists can include Excel/Sheets formula-injection payloads (`=cmd|'/c calc'!A0`, `@SUM(...)`, `+HYPERLINK(...)`, `-2+3`). When the operator opens the sidecar to spot-check skipped leads, those formulas execute in their spreadsheet client.

Before writing each cell value to the sidecar, neutralize formula-injection: if the cell's first character is `=`, `+`, `-`, `@`, tab (`\t`), or carriage return (`\r`), prepend a single quote (`'`) to the cell value. The single-quote prefix is a well-known Excel/Sheets convention: it signals "treat this as text, not a formula." The original cell value is preserved (the `'` is not stored as data; it's a display directive). For multi-line cells, neutralize each line that starts with one of the trigger characters.

Applies only to the sidecar CSV write at Phase 2 step 4c. The source CSV (`--csv`) is not mutated — IV-9 is a write-path mitigation, not an input filter, because the sidecar is a fresh artifact whose explicit purpose is operator review in a spreadsheet client. The trigger character set matches the OWASP CSV-injection guidance.

**IV-10. CSV row value Liquid-metacharacter rejection (Phase 1 + Phase 4 pre-upload).** EmailBison's substitution-order rule (verbatim from [article 184](https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates)) inlines lead values into the body BEFORE Liquid parses, so a CSV row whose `RECENCY_ANCHOR` value contains `{% for i in (1..1000000) %}{% endfor %}` would inject Liquid that runs at EB render time. Per-lead values from third-party enrichment (Apollo, Clay waterfall, ZoomInfo) are partially-trusted at best.

Detection regex applied to every per-lead value in the CSV: `\{\{|\}\}|\{%|%\}` (any Liquid metacharacter pair). Phase 1 step 1 + step 5 scan rows. Rows that match are rejected from UPLOAD and routed to the sidecar CSV (Phase 2 step 4c — same `skipped_leads_csv_path` mechanism), with the rejection reason logged as `liquid-metacharacter` in the sidecar. The source CSV is not mutated — rejection is at write-path, not input-filter.

This is fail-closed: the row never reaches Phase 4 UPLOAD, so EB never sees the injected Liquid. Operator can review the sidecar to decide whether to clean and re-upload. Threat model: enrichment-vendor data integrity boundary; not an attack-by-recipient (recipients can't write to the operator's CSV). Rationale parallels IV-9 — both invariants accept that CSV values come from partially-trusted sources, and the cost of a false-positive (a legitimate lead value containing literal `{%`) is operator review of the sidecar, not silent loss.

**IV-11. `--identity` value validation (Phase 1 pre-flight).** If `--identity` is provided, it MUST be exactly one of `labs`, `supply`, or `nites` (lowercase). Reject any other value with a clear error — no auto-correction; the operator resubmits. This is the Brite sending identity that Phase 5 tags onto every campaign created this run, so an invalid value must fail closed before any EB campaign is created or tagged. When `--identity` is absent, it is resolved by operator prompt at Phase 1 step 10 — this check only validates an explicitly-supplied value.

**IV-12. `--sender-match` value validation (Phase 1 pre-flight).** If `--sender-match` is provided, it MUST be exactly one of `identity`, `esp`, `both`, or `all` (lowercase). Reject any other value with a clear error — no auto-correction; the operator resubmits. This selects which connected senders Phase 7 attaches to each campaign (`identity` = the run's brand senders only, the redirect-safe default; `esp` = senders whose ESP matches each campaign's recipient ESP; `both` = identity ∩ ESP; `all` = every connected sender, redirect-*unsafe*). An invalid value must fail closed before any EB campaign is created. When `--sender-match` is absent, the mode is resolved by operator prompt at Phase 7 — this check only validates an explicitly-supplied value. **Incompatible with `--no-host-lookup`:** that flag produces a single combined campaign with no recipient-ESP split, so `esp` and `both` (which match senders to each cell's ESP) have no meaning. Reject `--no-host-lookup --sender-match esp|both` here at pre-flight — only `identity` and `all` are valid with `--no-host-lookup`.

---

## Argument parsing and defaults

| Arg / flag | Required | Default | What it does |
|---|---|---|---|
| `--csv <path>` | yes | — | Enriched lead CSV. Phase 1 validates schema + row count. |
| `--workspace <id>` | yes | — | `emailbison-b2b` or `emailbison-personal`. Phase 1 cross-checks against entity. |
| `--copy-artifact <path>` | yes | — | Path to the BC-5825 JSON artifact. Phase 1 loads + validates against schema v1.0. |
| `--campaign-name <base>` | yes | — | Base name for created campaigns. Segmentation adds compound suffixes (`\| Professional \| Google`, `\| Role \| Microsoft`, etc. — one per non-empty (email-type × ESP) cell). |
| `--entity <id>` | no | from copy artifact | `brite-nites` or `brite-labs` (long-form). Overrides `entity` in copy artifact — use only when intentionally re-targeting. **Path normalization (BC-8719):** every `docs/campaigns/{short_entity}/...` token in this document interpolates `{short_entity}` from `--entity` by stripping the `brite-` prefix (`brite-nites` → `nites`, `brite-labs` → `labs`) — this is the canonical short-form layout. The `entity` field inside the launch metadata JSON itself stays long-form (downstream consumers depend on the enum). Brite Supply is intentionally absent: Supply's marketing verticals are deferred per handbook `marketing/go-to-market/verticals/README.md`, and upstream `email-copywriting/SKILL.md` § 4 / § 8 enforces the same exclusion in the copy artifact. Do not re-add without coordinating with the handbook canon update. |
| `--no-host-lookup` | no | off (lookup ON) | Skip Phase 2 entirely. Single combined campaign with the base name. Sole opt-out from multiplicative segmentation — for tiny test launches where 9-cell setup overhead isn't justified. |
| `--no-sequence` | no | off (sequence ON) | Skip Phase 9. Campaign has no sequence steps until added out-of-band. |
| `--preview` | no | off | Full dry-run. Sample 3 leads through Phase 1 + Phase 10 local render. No mutations. Phases 3–9, 11 all skipped. |
| `--activate` | no | off | Enable Phase 11 ACTIVATE. Without this flag, campaigns stop at Phase 10 in draft. |
| `--test-send <email>` | no | — | Phase 10 additive mode: after the local render, call EB's `test-email` endpoint to send a real email to the specified inbox (typically the operator's own). Requires Phases 4–9 to have run. Counts toward sender reputation + daily limits. No lead is contacted. |
| `--test-send-sender <id>` | no | first attached | Override the sender mailbox used for `--test-send`. Default: first attached sender from Phase 7. |
| `--reference <campaign-id>` | no | — | Clone variables + naming + sender plan + schedule from an existing campaign. Pre-fills Phase 3/5/7/8 defaults — user gates still fire. |
| `--identity <id>` | no | prompt | `labs`, `supply`, or `nites` — the Brite sending identity tagged onto every campaign this run creates (Phase 5). Validated by IV-11. If omitted, Phase 1 prompts for it. Independent of `--entity` (do not derive one from the other). |
| `--sender-match <id>` | no | prompt | `identity`, `esp`, `both`, or `all` — which connected senders Phase 7 attaches per campaign. `identity` (redirect-safe default): the run's identity senders only. `esp`: senders whose ESP matches each campaign's recipient ESP. `both`: identity ∩ ESP. `all`: every connected sender (legacy, redirect-*unsafe* — warned at the Phase 7 prompt). Validated by IV-12 — under `--no-host-lookup` only `identity` / `all` apply (no ESP split to match). If omitted, Phase 7 prompts for it. |

**Non-goals** (explicit — do NOT do these):

- Do NOT generate copy — that's BC-5825 email-copywriting. This command CONSUMES the copy artifact.
- Do NOT design sequences — that's BC-2718 campaign-orchestration. This command APPLIES the sequence as given.
- Do NOT handle reply routing — that's BC-2720 reply-processing.
- Do NOT ration a single sender pool across campaigns to concentrate volume — invariant violation, explicitly forbidden in Phase 7 (Revgrowth 10 rule). Neither scoping the pool to the run's sending identity (BC-13864) nor the per-bucket modes giving each cell its own ESP-matched pool is a "split" — each campaign still gets its *whole* matched pool; only the rationing of one pool across campaigns is forbidden.
- Do NOT skip the agent-side two-call gate on Phase 4 UPLOAD or Phase 11 ACTIVATE — these are load-bearing safety mechanisms.
- Do NOT default to `--activate`. Campaigns are created in draft unless the flag is explicit.
- Do NOT treat "preview" as an EB server-side render. Email Bison has no standalone preview endpoint — Phase 10's default mode is a client-side local render of the copy artifact, and the optional `--test-send` mode delivers a real test email. Neither is a non-sending server-side preview in the way the term typically implies. BC-5826 X17 dogfood confirmed (F13) that an EB preview endpoint does not exist; do not search for one.

---

## Launch metadata schema

The file at `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json` is written progressively across the 11 phases. (`{short_entity}` derived from `--entity` by stripping the `brite-` prefix per BC-8719 path normalization.) Each phase appends its result IDs when it completes. The partial JSON IS the breadcrumb on failure — re-running the command reads the file, shows `last_completed_phase`, and the operator picks up from the next phase manually.

```json
{
  "schema_version": "1.0",
  "entity": "brite-nites",
  "sending_identity": "nites",
  "campaign_name_base": "denver-downtown-lighting",
  "workspace": "emailbison-b2b",
  "copy_artifact_path": "docs/campaigns/nites/copy-denver-downtown-lighting-2026-04-20.json",
  "csv_path": "lists/denver-downtown-2026-04-20.csv",
  "lead_count": 127,
  "segmented": true,
  "segments": {
    "professional|Google": {"email_type": "professional", "esp": "Google", "count": 84},
    "professional|Microsoft": {"email_type": "professional", "esp": "Microsoft", "count": 31},
    "professional|Other": {"email_type": "professional", "esp": "Other", "count": 12}
  },
  "custom_variables_created": ["RECENCY_ANCHOR", "PROOF_POINT_COMPANY"],
  "lead_ids_uploaded": 127,
  "lead_ids_by_bucket": {"professional|Google": [14706, 14707, 14708], "professional|Microsoft": [14709], "professional|Other": [14710, 14711]},
  "campaign_ids": {"professional|Google": 5551, "professional|Microsoft": 5552, "professional|Other": 5553},
  "plain_text_applied": true,
  "identity_tag_id": 102,
  "sender_ids_attached": [101, 102, 103],
  "sender_attach_counts": {"professional|Google": 3, "professional|Microsoft": 3, "professional|Other": 3},
  "schedule_template_id": 3,
  "campaign_schedule_ids": {"professional|Google": 4, "professional|Microsoft": 5, "professional|Other": 6},
  "sequence_ids": {"professional|Google": 8801, "professional|Microsoft": 8802, "professional|Other": 8803},
  "preview_rendered_at": "2026-04-20T14:32:00Z",
  "activated": false,
  "activated_at": null,
  "activated_per_campaign": {"professional|Google": null, "professional|Microsoft": null, "professional|Other": null},
  "launched_at": "2026-04-20T14:30:00Z",
  "last_completed_phase": 10
}
```

The worked example uses a single email-type (`professional`) only because the operator's gate-2 default skips role + personal — the cell shape is what's authoritative, not the example's column collapse. A run that included role addresses would produce additional keys like `role|Google`, `role|Microsoft`, etc.

`last_completed_phase` advances monotonically from 1 to 11. `activated` flips to `true` only when every entry in `activated_per_campaign` is non-null (Phase 11 finalization). `activated_at` is the ISO-8601 timestamp of the LAST successful per-campaign resume call.

`segments` records one entry per non-empty (email-type × ESP) cell post-gate-2 filter. Each entry carries the cell's `email_type`, `esp`, and `count`. Empty cells are absent from the object — F12 prune (Phase 2 step 4b) drops zero-lead cells before the metadata write. The operator's chosen email-type filter is recorded separately in `email_type_filter_applied` (see optional fields below). All downstream per-bucket fields (`lead_ids_by_bucket`, `campaign_ids`, `sender_attach_counts`, `campaign_schedule_ids`, `sequence_ids`, `activated_per_campaign`, plus the optional `lead_attach_counts` documented below) use the same `{email_type}|{esp}` key shape.

**Resume-breadcrumb compat (one-way break).** Pre-BC-6654 metadata files written with the old `esp_segments` / `email_type_segments` shape will not auto-resume — the per-phase resume code reads `segments` and won't find it. Manual recovery: open the legacy metadata, manually map each ESP bucket count into the corresponding (professional × ESP) cell of the new shape (assumes default email-type filter, which dropped role/personal pre-gate), then save and re-run from the next phase. Acceptable cost — schema migration is structural and resume from breadcrumb is a rare path.

**Optional fields written by specific phases.** The example above shows the minimal shape. Individual phases also write these fields when applicable — consumers MUST accept their presence and SHOULD gracefully handle their absence:

- Phase 1 step 3 / step 10: `workspace_mismatch: {expected: "<id>", actual: "<id>"} | null`
- Phase 1 step 7 / step 10: `sender_resolution_method: "artifact-default" | "marketing-context" | "salesforce" | "operator-prompt"`
- Phase 1 step 9 / step 10: `unique_per_lead_enabled: <bool>`
- Phase 1 step 10: `sending_identity: "labs" | "supply" | "nites"` (the Brite sending identity, chosen via `--identity` or operator prompt; tagged onto every campaign in Phase 5 step 9. Always written — absent only on a pre-Phase-1 abort. Independent of `entity`.)
- Phase 2 step 4b (F12 skip-empty, post-gate): `skipped_cells: [<cell-label>, ...]` keyed by `{email_type}|{esp}` (same shape as `segments` keys).
- Phase 2 IV-4 (Input validation): `invalid_domain_rows: [<row-number>, ...]`
- Phase 2 step 1 (malformed-email handling): `invalid_email_rows: [<row-number>, ...]`
- Phase 2 step 4d (post-gate metadata write): `email_type_filter_applied: "default" | "include_role" | "include_personal" | "include_all"` (records which option the operator picked at gate 2; `default` means skip role + personal). Set to `null` when `--no-host-lookup` skipped Phase 2 entirely.
- Phase 1 step 2d / Phase 2 step 4c / Phase 4 step 7d (consolidated skipped-contacts write, BC-14044): `skipped_leads_csv_path: <path> | null` (path to the single skipped-contacts CSV; carries `skip_reason` rows from input-list dedup, deliverability, role/personal, liquid-metacharacter, and workspace_collision. `null` ONLY when no row was set aside anywhere — including under `--no-host-lookup`, where Phase 1 step 2d still writes any dedup/deliverability skips)
- Phase 4 step 7d / step 10 (BC-14044): `workspace_collisions_skipped: <count>` (already-in-workspace leads set aside at gate 4b across all chunks; `0` when none / no 422 fired)
- Phase 5 step 3: `existing_campaign_matches: [<id>, ...]` (campaign IDs returned by `list_campaigns(search="{base}")` before User gate 5; empty list is the happy path)
- Phase 5 step 5: `reused_existing_ids: <bool>` (true if operator selected "Reuse existing IDs" at User gate 5; false on fresh creates)
- Phase 5 step 8 / step 10: `plain_text_applied: <bool>` (true only if step 8 PATCH loop completed for ALL campaigns; false if partial)
- Phase 5 step 9 / step 10: `identity_tag_id: <int>` (the per-workspace EB tag id for the chosen `sending_identity`, resolved + attached to every campaign in step 9; ids differ per instance — never hardcoded. Absent if the run didn't reach Phase 5.)
- Phase 5 step 10 + Phase 11 step 4: `activated_per_campaign: {<bucket>: <ISO-8601> | null, ...}` — keys initialized at Phase 5 (one per bucket in `campaign_ids`); values flip from `null` to ISO-8601 timestamp at the moment each campaign's resume call returns. Global `activated` flips to `true` only when every entry is non-null.
- Phase 6 step 7: `lead_attach_counts: {<bucket>: <count>, ...}` keyed by `{email_type}|{esp}` (same shape as `segments`).
- Phase 6 step 7: `lead_ids_by_bucket: {<bucket>: [<lead_id>, ...], ...}` — per-bucket lead IDs from the bucket map built in Phase 6 step 2; the resume primitive for re-running Phase 6 from metadata alone (without re-doing Phase 2 MX lookups + CSV-row joins).
- Phase 7 mode-selection: `sender_match_mode: "identity" | "esp" | "both" | "all"` (the operator-selected sender-match mode, resolved via `--sender-match` or the Phase 7 prompt; recorded before any attach so a resumed run re-reads it instead of re-prompting. Absent if the run didn't reach Phase 7.)
- Phase 7 step 2e: `esp_tag_ids: {"Google": <int>, "Outlook": <int>}` (the per-workspace EB tag ids for the Google / Microsoft-"Outlook" ESPs, resolved for the per-bucket `esp` / `both` modes; ids differ per instance — never hardcoded. Present only for `esp` / `both` runs; absent for `identity` / `all`.)
- Phase 7 step 2i: `sender_match_fallbacks: [<cell>, ...]` (per-bucket cells where an empty `both`-cell fell back to identity-only, keyed `{email_type}|{esp}`; `[]` when none) and `sender_unsent_cells: [<cell>, ...]` (empty `esp` cells — and `both` cells whose identity fallback was also empty — left sender-less per the gate-7 confirmation; `[]` when none). Both surfaced + confirmed at User gate 7, never silent.
- Phase 7 step 8: `sender_ids_attached` — **shape depends on `sender_match_mode`**: a flat list `[<id>, ...]` for the uniform modes (`identity`, `all`, the same pool on every campaign — this is the shape in the worked example above), but a per-cell map `{<bucket>: [<id>, ...], ...}` keyed `{email_type}|{esp}` for the per-bucket modes (`esp`, `both`, where each cell's set differs). Consumers MUST branch on `sender_match_mode` (or on `Array.isArray`) before reading it.
- Phase 7 step 7: `sender_verify_mode: "scalar" | "paginated"` (which post-attach verification path step 7 used — scalar-count happy path, or the paginated fetch+classify fallback when `get_campaign` exposes no scalar count field).
- Phase 8 step 7: `schedule_template_id: <id>` (renamed from `schedule_id`) + `campaign_schedule_ids: {<bucket>: <cloned_schedule_id>, ...}` — the source template ID applied plus the per-campaign cloned schedule entity IDs returned by `create_schedule_from_template`. Round-2 of BC-5906 confirmed each apply creates a NEW schedule entity (clone), not a reference to the template.
- Phase 10 Mode 1 step 8: `preview_method: "local-render" | "local-render + test-send"`, `preview_lead_email: "<email>"`
- Phase 10 Mode 2 step 6: `test_send_recipient: "<email>"`, `test_send_at: "<ISO-8601>"`

**Schema contract — no credential values.** This JSON writes labels, IDs, counts, timestamps, and resolution-method tags. It does NOT write credential values of any kind (tokens, keys, session IDs). When the resolution method is relevant (e.g., "sender resolved via workspace token"), log the source name, never the value. See Input validation § IV-7.

**Dogfood write path (F6 convention).** For any dogfood, staging, or testing run — typically a run against `emailbison-personal` with a synthetic test CSV — write the metadata JSON to `.claude/worktrees/<worktree-name>/dogfood/` (gitignored) instead of `docs/campaigns/{short_entity}/`. Production metadata lives under `docs/campaigns/` because downstream consumers (campaign-debrief skill, launch-history audits) read from there; dogfood metadata pollutes that directory and should never be committed. Detection is structured, not substring-matched — see Input validation § IV-3 for the pattern. The detection fires at Phase 1 step 3 (flagging the cross-mapping) AND Phase 1 step 10 (selecting the write path).

---

## Phase 1 — PRE-FLIGHT

**Purpose.** Validate every input before touching any EB state. This phase is read-only — no MCP mutations. Catch schema drift, missing variables, entity/workspace mismatch, and thin copy before any lead gets created.

**Steps:**

1. **CSV schema validation.** Read the first line of `--csv` via `Bash`: `head -1 "{csv}"`. Confirm it contains `email`, `first_name`, `company_domain` (case-insensitive). Halt with a clear error if any required column is missing. Report optional columns found (`last_name`, `job_title`, `company_name`) — absent-but-referenced-in-copy columns are flagged in step 4.
2. **Row count + input cleaning (BC-14044).** `wc -l "{csv}"` minus 1 for header = the raw row count. Then clean the list in two read-only passes (local CSV only, no EB calls) before any phase consumes it. Stash every dropped row in scratch state tagged with a `skip_reason`; dropped rows route to the skipped-contacts file (Phase 2 step 4c shared writer — see (2d) for the `--no-host-lookup` fallback). See `CONTEXT.md` § Marketing for **input-list dedup** vs the unrelated same-sounding concepts (unique-per-lead, the Phase 5 campaign-name guard, the Phase 6 cross-campaign skip).
   - **(2a) Input-list dedup.** Collapse rows whose `email` matches case-insensitively (`.strip().lower()`) to the FIRST occurrence; drop the rest (`skip_reason: duplicate`). Load-bearing because EB's `POST /api/leads/multiple` silently keeps only the first of a within-batch repeat (HTTP 201, dropped rows vanish from the response — `email-bison.md` § Known gotchas, verified BC-7667) — doing it client-side makes the drop visible and keeps the Phase 4 step 9 + Phase 6 count checks honest. If a dropped row's other fields differ from the kept row (e.g. different `company` / `title` / custom-variable values), record the (kept-row, dropped-row) pair for the User-gate-1 conflict display — the one case where keep-first could discard the better record.
   - **(2b) Deliverability filter.** Only when the CSV has an `email_deliverable` column (no-op if absent — many lists won't have it). Drop rows whose value lowercases to `false` / `no` / `0` (`skip_reason: undeliverable`) — known-undeliverable addresses bounce and degrade domain reputation (standard pre-send filter; Instantly auto-removes invalid on import). BLANK values are KEPT (blank = unchecked, not known-bad) and counted for the gate-1 summary. Never drop blanks.
   - **(2c) Adjusted count.** `lead_count` = raw count − dropped (2a + 2b). Every downstream phase (Phase 4 chunking + step 9 reconciliation, Phase 6 attach counts) uses this cleaned count, NOT the raw row count.
   - **(2d) Skipped-contacts file write.** The 2a + 2b dropped rows are written by the consolidated Phase 2 step 4c writer (alongside role/personal skips), POST-gate-1 so an operator keep-override (User gate 1) is reflected; Phase 2 step 4d records `skipped_leads_csv_path` in metadata. **`--no-host-lookup` fallback:** that flag skips Phase 2 entirely — so Phase 2 step 4d, which normally records the path, never runs. When the flag is set, write the dropped rows to the skipped-contacts file at the end of Phase 1 instead **AND record `skipped_leads_csv_path` into the metadata JSON at that same point** (set to the written path, or `null` if no rows were dropped) — otherwise a file would exist on disk with no path recorded in metadata. The operator always gets both the file and its recorded path (BC-14044). Apply IV-8 (path confinement) + IV-9 (formula-injection neutralization) at whichever write fires. Net: `skipped_leads_csv_path` is recorded in metadata whenever any row was dropped (by step 4d normally, or here under `--no-host-lookup`), else `null`.
3. **Workspace detection and cross-mapping flag (F2).** Load the copy artifact at `--copy-artifact` via `Read`. Extract `entity`. Map entity → expected workspace:
   - `brite-nites` → `emailbison-b2b` (workspace 55, `send.outbase.so`)
   - `brite-labs` → `emailbison-b2b` (workspace 55; Labs also runs b2b outreach)
   - Operator explicit override via `--workspace` is honored
   If `--workspace` disagrees with the entity→workspace mapping, **do NOT gate here.** Record a `workspace_mismatch` flag in scratch state with the expected and actual workspace IDs. The end-of-Phase-1 gate (the `AskUserQuestion` block labeled "User gate 1" — immediately after step 10's metadata write) surfaces this flag for acknowledgment alongside the rest of the pre-flight report — a single unified gate is easier to reason about than two mid-phase interrupts.

   Dogfood + staging runs legitimately cross-map (e.g., `--entity brite-labs --workspace emailbison-personal` for a dogfood against the personal workspace). The cross-mapping gate is **expected** in those cases, not a warning. Write path for metadata JSON also changes — see § Launch metadata schema "Dogfood write path" note.
4. **Copy artifact JSON schema validation.** Confirm the loaded JSON has `schema_version == "1.0"`, required fields `entity`, an offer posture field (see below), `step_1.subject`, `step_1.body`, `step_2.subject`, `step_2.body`, `custom_variables` (array). Halt on any missing field. **Offer posture field — backward-compat shim per ADR-017.** Try `offer_posture` first (preferred, new artifacts MUST emit this string enum: `knowledge` | `free-asset` | `pilot` | `risk-reversal`). If `offer_posture` is absent, fall back to the legacy `offer_tier` (integer 1-4) and map: 1→`knowledge`, 2→`free-asset`, 3→`pilot`, 4→`risk-reversal`. On fallback emit a one-line operator-facing deprecation warning: `"Copy artifact uses deprecated 'offer_tier' field — please re-emit with 'offer_posture' per ADR-017 (legacy alias removed after the 6-month deprecation window from PR-merge of BC-8720)."`. Halt only if BOTH fields are absent. See `plugins/marketing/skills/email-copywriting/SKILL.md` § JSON artifact schema for the full contract.
5. **Variable-presence check (F7).** Extract every `{VARIABLE}` from `step_1.subject`, `step_1.body`, `step_2.subject`, `step_2.body` via `Grep` (regex `\{[A-Z_]+\}`). For each variable, verify one of these resolution paths in priority order:
   - **EB-standard-variable allowlist (highest priority).** The variable is one of `FIRST_NAME`, `LAST_NAME`, `COMPANY`, `JOB_TITLE`, `EMAIL` — these resolve server-side via EB's render engine from EB's lead-body field names (`first_name`, `last_name`, `company`, `title`, `email`) that Phase 4 UPLOAD populates. No CSV-column string match is required — the render is field-based, not column-based. A lead object created via `bulk_create_leads` with `company: "Acme Corp"` will render `{COMPANY}` as `Acme Corp` even when the CSV column was named `company_name` — Phase 4 step 2 maps `csv.company_name → eb.company` (Sx-6, BC-5906). Note: `{COMPANY_DOMAIN}` is NOT EB-standard — EB has no native `company_domain` field. If a copy artifact references `{COMPANY_DOMAIN}`, the lead-body must stash it via `custom_variables` (per Phase 4 step 2). OR
   - The variable matches a CSV column (case-insensitive) populated for ≥95% of rows — for non-standard, per-lead variables that get written into `custom_variables[].value` at UPLOAD, OR
   - The variable appears in `custom_variables[]` with a non-empty default, OR
   - The variable is a `{SENDER_*}` variable (filled via the priority chain in step 7), OR
   - The variable is referenced via Liquid in `step_1.body` or `step_2.body` with one of three documented fallback shapes (per [EmailBison article 184](https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates)):
     - (a) Wrapped in an `{% assign %}` block whose filter chain includes a `default:` filter with a **non-empty string literal**. Gate detection regex: `\{%-?\s*assign\s+\w+\s*=\s*'\{[A-Z_]+\}'[^%]*default:\s*['"][^'"]+['"][^%]*-?%\}` — requires the full `{% assign %}` wrapper (NOT just the `default:` filter), the UPPERCASE `'{TOKEN}'` token reference, and a non-empty string literal in the `default:` filter. The naked-default form `{{ token | default: 'fallback' }}` (without an `{% assign %}` wrapper) does NOT satisfy this path because EB never substitutes per-lead values into a naked Liquid output tag — see `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback § Anti-pattern. The literal must contain at least one non-quote character; `default: ''` and `default: ""` do NOT satisfy this path. Canonical: `{%- assign name = '{TOKEN}' | strip | default: 'fallback' -%}`. Source: BC-6554 round-4 S-23 / BC-6782.
     - (b) Referenced inside a truthy `{% if local_var %}` block whose `{% else %}` clause is non-empty and contains either fallback prose or spintax (`{a|b|c}`).
     - (c) Referenced inside a `contains` keyword-branch block whose `{% else %}` clause is non-empty. Two valid shapes (per [EmailBison article 184](https://help.bisonsphere.com/en/articles/184-liquid-syntax-spintax-how-to-use-and-templates)): (c-i) direct-quoted form `{% if '{TOKEN}' contains '...' %}` (per the founder/ceo example), OR (c-ii) assigned-local form — `{% assign x = '{TOKEN}' | downcase | strip %}` followed by `{% if x contains '...' %}` (the canonical Pattern C in `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback; case-normalized via `downcase`).
   **HALT** if any variable fails all five checks. The error message names the offending variable(s) and the resolution paths each one failed. No operator override at the end-of-Phase-1 gate — the operator must fix the copy artifact (add a non-empty `custom_variables[].default`, surface the variable as a CSV column populated for ≥95% of rows, wrap the variable in a Liquid fallback per the canonical patterns, or remove the variable from the body) and re-run. This fail-closed behavior is the safety net for the empty-render finding (BC-6308 round-3 R-2b — EB renders unresolved tokens as empty string, producing visible double-spaces / orphan punctuation). Graceful per-lead fallback is now handled via Liquid syntax (BC-6613) — see `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback for the canonical patterns and `plugins/marketing/tools/integrations/email-bison.md` § Liquid + spintax + whitespace for the vendor-fact reference. The EB-standard allowlist prevents the false-flagging pattern surfaced in BC-5826 X17 dogfood (F7): `{COMPANY}` vs CSV column `company_name` would have failed a naive case-insensitive string match even though EB's render engine handles it correctly.
6. **Messaging sanity checklist.** Self-check the copy artifact against these rules (all MUST pass — halt with specific error on any fail):
   - No `{{TOKEN}}` double-brace EB-token typos in subject or body. Detection regex: `\{\{\s*[A-Z_]+\s*\}\}` (uppercase letters or underscores only; internal whitespace allowed but the identifier itself must be uppercase — catches both `{{FIRST_NAME}}` and `{{ FIRST_NAME }}`). Liquid output `{{ var }}` (lowercase identifier, space-padded) is allowed in body — it's required for the Liquid fallback patterns. Subjects MUST NOT contain Liquid output (existing convention: no merge variables in subject lines). See `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback for the full pattern reference.
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

   **EB shadows this resolution at delivery (BC-6784).** Email Bison's render engine has built-in `{SENDER_*}` resolution that pulls from the *sender record being used at the moment of send* — and **shadows** any artifact-level or local resolution this priority chain produced. Sender rotation (multiple senders attached per Phase 7) means each individual delivery resolves `{SENDER_*}` from a potentially different mailbox; the recipient's email always reflects the actual sender's first_name / email / role, not the priority-chain pick. The priority chain governs the **local Phase 10 spot-check display only** — it gives the agent and operator a representative value for preview, not the value recipients will see. Verified via UI Preview Body (BC-6554 round-4) — agent spot-check rendered `"Amanuel"` (artifact-default), EB preview rendered `"Rainer"` (sender record's first_name). See `email-bison.md` § Known gotchas § `{SENDER_*}` render-time resolution shadows artifact for the canonical statement of this rule.
8. **Lead spot check.** Pick 3 rows from the CSV (rows 2, middle, last). For each, render the step_1 body using the same local-render algorithm Phase 10 uses: substitute variables from CSV fields + `custom_variables[].default` + `{SENDER_*}` resolutions from step 7, then resolve spintax deterministically by picking the **first** option per `{opt1|opt2|…}` group, then replace `<br><br>` with paragraph breaks for display. Show rendered text to the operator. This catches spintax-rendering problems, missing CSV columns, and unbalanced `{` / `}` before any lead gets created. Call this out explicitly when rendering: "Spintax rendered with first-option pick for deterministic preview; actual sends will rotate options."

   **Liquid blocks are not evaluated in the local spot-check.** EmailBison evaluates Liquid (`{% assign %}`, `{% if %}`, `{{ var }}`) server-side at send time, after EB substitutes `{TOKEN}` references. The local spot-check renders only the EB-substitution layer — `{TOKEN}` references get replaced with CSV values, but Liquid blocks remain visible in the preview as raw text. To verify Liquid evaluation end-to-end, use `--test-send <your-email>` (Phase 10 Mode 2), which sends a real email through EB's render pipeline and lands in your inbox with the final rendered output. See `plugins/marketing/skills/email-copywriting/SKILL.md` § Liquid + spintax for graceful per-lead fallback for the canonical patterns.
9. **Unique-per-lead auto-toggle.** If `lead_count < 500`, enable per-lead variable uniqueness (Josh Braun framework from Revgrowth 10 — each lead gets a slightly different variable value rendering). If `lead_count >= 500`, skip per-lead uniqueness for deliverability / sender-volume reasons. Log the decision.
10. **Write initial metadata JSON.** First, **resolve the sending identity**: if `--identity` was provided use it; otherwise — on a real (non-`--preview`) run — prompt the operator via `AskUserQuestion` to pick `labs`, `supply`, or `nites` (no default, the operator must choose; do NOT derive it from `--entity`, identity is an independent axis). Under `--preview` (a no-mutation dry-run that never tags) skip the prompt when `--identity` is absent and record `sending_identity: null`. **Re-validate** the resolved value against the IV-11 enum regardless of source (flag or prompt) — an off-enum value HALTs, the same as an explicitly-supplied bad flag. Record it as `sending_identity` in scratch state. **Then verify the identity tag exists** in the target workspace, before any EB state is created (skipped under `--preview`, and when `sending_identity` is null): `search_api_spec` + `call_api` to list the workspace's tags and match the chosen identity's capitalized label (`labs`→`Labs`, `supply`→`Supply`, `nites`→`Nites`; the platform reconcile creates them capitalized, BC-13861). **HALT** if the chosen identity's tag is absent — a missing tag is a setup problem to fix before launching; do NOT create it here. Record `identity_tag_id` (the chosen identity's id) in scratch state for Phase 5. This is a read (no mutation — consistent with this phase) and it fails closed *before any campaign is created*, the same invariant IV-11 states for the value check. Then validate `--campaign-name` per IV-8 (regex + write-path realpath confinement) before constructing the path. Determine write path per § Launch metadata schema "Dogfood write path" note:
    - Default: `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json`
    - Dogfood override (CSV path under `.claude/worktrees/`): `.claude/worktrees/<detected-worktree>/dogfood/{campaign-name}-{YYYY-MM-DD}.json`
    Populate `schema_version`, `entity`, `sending_identity`, `campaign_name_base`, `workspace`, `copy_artifact_path`, `csv_path`, `lead_count`, `launched_at`. Also record the scratch-state flags from steps 3–7: `workspace_mismatch` (if any), `sender_resolution_method`, `unique_per_lead_enabled`. Set `last_completed_phase: 1`. This is the first progressive write.

**User gate 1 (single end-of-Phase-1 gate, F8).** Ask via `AskUserQuestion`. Render the pre-flight summary; if a `workspace_mismatch` flag was recorded in step 3, fold its acknowledgment into the same prompt (do NOT ask twice):

> Pre-flight complete. Lead count: {N} (after cleaning). Workspace: {workspace}. Entity: {entity}. Sending identity: {sending_identity}. Variables OK: {count-passed}/{count-total}. Sanity checklist: all passed.
>
> Input cleaning (BC-14044): {D} duplicate row(s) collapsed (kept first) · {U} undeliverable dropped · {B} kept without a deliverability check. {IF any row dropped}Skipped rows → `{skipped_leads_csv_path}`.{END IF}
> {IF differing-duplicate conflicts recorded in step 2a:}
> ⚠️ {K} duplicate email(s) had DIFFERENT details across rows — keeping the FIRST of each:
>   • `{email}` — kept row {i} (`{field}`="{a}"), dropped row {j} (`{field}`="{b}")
> Reply with an alternate keep (e.g. "keep row {j} for {email}") to override before upload; an unqualified proceed keeps the first.
> {END IF}
>
> {IF workspace_mismatch recorded:}
> ⚠️ Cross-mapping detected: entity `{entity}` normally routes to `{expected-workspace}`, but `--workspace {actual-workspace}` was explicit. Legitimate for dogfood / staging; flag for prod / real outreach. Metadata write path: `{metadata-path}` (dogfood path selected if CSV is under `.claude/worktrees/`).
> {END IF}
>
> Proceed to Phase 2?
>
> - Yes, proceed (acknowledges cross-mapping if flagged above)
> - Abort

**Gate-1 keep-override (BC-14044).** If the operator's response names an alternate keep for a differing-duplicate conflict ("keep row {j} for {email}"), swap which row is kept vs. dropped in the cleaned lead set AND in the skipped-contacts file before Phase 4; an unqualified "Yes, proceed" keeps the first of every conflict. This is the only re-litigated decision — non-differing duplicates and undeliverable drops are final. The override changes only which of the two same-email rows survives; it never un-drops a duplicate (the email still uploads exactly once).

**If Phase 1 fails:** the metadata JSON may or may not exist. If it does, it contains only the inputs — no EB state has changed. Fix the input (CSV, copy artifact, or marketing-context) and re-run.

---

## Phase 2 — HOST LOOKUP

**Purpose.** Phase 2 has two detection passes whose outputs combine into a 9-cell (email-type × ESP) segmentation grid. **Email-type detection** (step 1) classifies each lead as `professional` / `role` / `personal` and lets the operator drop role + personal addresses at gate 2 (default skip). **ESP detection** (steps 2–3) resolves who hosts each lead's domain so leads can be split into Google / Microsoft / Other. Step 3 joins the two: each surviving lead lands in exactly one (email-type, ESP) cell. The operator's gate-2 filter choice + F12 empty-cell prune are applied in step 4 (post-gate); the resulting non-empty cells become campaigns in Phase 5. Multiplicative segmentation reduces cross-provider AND cross-email-type deliverability interference — a sender warmed on Google professional may perform differently into Google role addresses or Microsoft professional, and isolating cells gives clean per-segment metrics. This phase is read-only; no leads are mutated.

**One skip flag:**

- **`--no-host-lookup`** — skip Phase 2 entirely. Step 1 (email-type detection) does NOT run; step 2 (ESP detection) does NOT run. Set `segmented: false`, `segments: null`, `email_type_filter_applied: null`, `invalid_email_rows: []`, `invalid_domain_rows: []` in metadata. **`skipped_leads_csv_path` is NOT forced `null` here (BC-14044):** Phase 1 step 2d still writes any `duplicate` / `undeliverable` skips even under this flag, so the path reflects that write — set when any row was dropped, else `null`. No gate 2. Proceed to Phase 3 with one combined campaign on the full lead set.

Without `--no-host-lookup` Phase 2 always runs and produces the multiplicative segmentation grid. There is no escape hatch from email-type-axis or ESP-axis individually — that path was removed per BC-6514 (opting into either rejected single-axis model would silently bypass the multiplicative call).

**Steps:**

1. **Email-type detection (per-lead pre-filter).** Before resolving ESP per domain, tag each lead by email-type. Two static lists are baked into the spec — no DNS lookup, no API call. Predicate output names (`is_role`, `is_free`) match the BounceBan response shape. (BC-8173 originally anticipated a drop-in swap of this static classification for a single batched brite-enrichment-MCP call. The shipped `verify_emails` tool is **single-email-only** — looping it per-lead over a full list is slower than this free static pass, costs provider $, and is creds-gated to the local operator run — so list-scale classification is **not** a drop-in swap here; it waits for the bulk-verify door (BC-5296). The static lists below stay the primary path. See ADR-024.)

   - **Role-prefix list (19 entries).** List verbatim: `info`, `sales`, `contact`, `support`, `hello`, `team`, `office`, `admin`, `help`, `service`, `general`, `feedback`, `enquiries`, `inquiry`, `inquiries`, `pr`, `press`, `partnerships`, `partners`. Match: case-insensitive exact on local-part. No normalization (no hyphen-stripping, no underscore-collapsing) — variant forms like `customer-service@` and `info-team@` are intentionally NOT caught at this level; catching them needs the smarter BounceBan classification, which arrives via the bulk-verify door (BC-5296), not here (see ADR-024). Scope rationale: list focuses on generic shared inboxes that genuinely show up in B2B CSVs and aren't a fit as cold-outreach targets. Intentionally excluded: back-office department names (`accounting`, `billing`, `legal`, `accounts`, `accountspayable`, `ap`), HR/talent (`hr`, `recruiting`, `recruiter`, `jobs`, `careers`), IT (`it`), customer-service-team queues (`cs`, `customerservice`), media/marketing/events (`media`, `marketing`, `events`), operations (`operations`, `ops`), and system addresses (`noreply`, `postmaster`, `webmaster`, `mail`, `email`). The exclusions reflect Brite's TAM (back-office departments aren't decision-makers for lighting; system addresses shouldn't appear in clean CSVs from list-building) plus the operator-override safety valve at gate 2 for the rare slip-through. False-positive cost is bounded — operator review at gate 2, not silent deletion.

   - **Free-mail-domain list (12 entries).** List verbatim: `gmail.com`, `yahoo.com`, `hotmail.com`, `outlook.com`, `icloud.com`, `aol.com`, `protonmail.com`, `googlemail.com`, `live.com`, `me.com`, `mac.com`, `mail.com`. Match: case-insensitive exact on domain. First 7 cover the canonical free providers (the original 5 from `tam-mapping` Operational rule 1 plus `aol.com` + `protonmail.com`). Last 5 are US-relevant aliases that legitimately appear in US-based prospect lists: `googlemail.com` (Google's older alias), `live.com` (Microsoft consumer), `me.com` + `mac.com` (Apple legacy), `mail.com` (generic free provider). Intentionally excluded: country-localized variants (`yahoo.co.uk`, `outlook.de`), Russian/Chinese providers (`mail.ru`, `yandex.*`, `163.com`, `qq.com`) — out of Brite's TAM. US ISP-attached email (`comcast.net`, `verizon.net`, `att.net`) — high false-positive risk on home-based micro-businesses (sole-proprietor installers giving out `tom@comcast.net` as the business contact) in Brite Nites' contractor-targeted campaigns.

     **Keep in sync.** This list mirrors `plugins/marketing/skills/tam-mapping/SKILL.md` § Operational rule 1 (free-email-provider pre-tier filter). The upstream rule routes free-mail rows to `personal-contacts.csv` BEFORE tier-A/B/C delegation; the runtime rule here is a safety net for CSVs that bypassed tam-mapping. **If you change this list (add/drop a free-mail domain), update both sides.** Annotation pair: `plugins/marketing/commands/launch-campaign.md` § Phase 2 step 1 free-mail-domain list ↔ `plugins/marketing/skills/tam-mapping/SKILL.md` § Operational rule 1.

   - **Per-lead predicate.**

     ```
     is_role(email):  local-part ∈ role-prefix list (case-insensitive exact match)
     is_free(email):  domain ∈ free-mail-domain list (case-insensitive exact match)
     bucket(email):
       if is_free(email):       → "personal"   (tiebreak: personal beats role)
       elif is_role(email):     → "role"
       else:                    → "professional"
     ```

   - **Tiebreak rule.** If a lead matches both `is_role` AND `is_free` (e.g., `sales@gmail.com`), report as `personal`, not `role`. Reasoning: dominant signal is the free-mail domain; aligns with operator-override semantics — if the operator opts to "include role but skip personal," this lead correctly follows the personal rule.

   - **Output.** Per-lead tag plus aggregated counts (scratch state for step 3's join, not metadata-bound). Step 3 is where these counts are projected into the (email-type × ESP) cell grid that becomes metadata's `segments` map.

   - **Malformed-email handling.** If a lead's email is missing `@`, has multiple `@`, or fails Phase 1's email-format check, record the row number in `invalid_email_rows` (sibling of `invalid_domain_rows` populated in step 2) and skip the lead from BOTH email-type and ESP buckets. Operator sees the count at gate 2.

   Steps 2–3 below operate on the lead set as a preview pass — they classify ESP for ALL leads (regardless of email-type tag) so gate 2 can show the post-filter 9-cell grid for any of the 4 filter choices the operator might pick. Step 4 (post-gate) is where the chosen filter is actually applied to produce the final per-cell lead lists, including the F12 skip-empty-cells prune (now step 4b) which only runs after the filter is known. The "all cells empty" halt path lives in step 4b — see below.

2. **Resolve ESP per domain via Bash `dig` (F10 — primary path).** Email Bison has no lead-side ESP detection tool today (BC-5826 X17 dogfood confirmed: `search_api_spec` on `host lookup`, `ESP`, `domain detection`, `check-mx-records` returns only sender-side tools). Bash `dig` is the primary — and currently only — path. Extract domains from ALL leads (not yet filtered — gate 2 needs ESP counts under any filter choice the operator might preview), filter invalid ones (per Input validation § IV-4), resolve MX records in **parallel in one Bash invocation**, bucket client-side:
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
3. **Build the 9-cell (email-type × ESP) grid.** Join scratch state from steps 1 and 2: for each lead, look up its (email-type tag, domain → ESP bucket) tuple and increment the appropriate cell of `{professional, role, personal} × {Google, Microsoft, Other}`. Single pass over the per-lead tag table from step 1; no additional CSV walks. The 9-cell grid is the segmentation plan — each non-empty cell post-gate-2 becomes one campaign in Phase 5. ESP detail beyond the 3-bucket plan (Proofpoint, Mimecast, Barracuda, Cisco, Custom, Unknown) is rolled up into `Other` for segmentation but surfaced in gate 2's preview for operator visibility — deliverability infra considers Google and Microsoft separately; the long tail stays one bucket.

**User gate 2 fires here** (rendered below — physically separated for readability; logically inserts between step 3 and step 4).

4. **Apply gate-2 decision (post-gate).** This step runs AFTER User gate 2 returns. Branch on the operator's choice in this exact order:
   - **(4a) Compute the skipped-lead set** based on the chosen filter:
     - `Apply default` → skip leads tagged `role` OR `personal` (enum: `default`)
     - `Include role addresses too` → skip leads tagged `personal` only (enum: `include_role`)
     - `Include personal addresses too` → skip leads tagged `role` only (enum: `include_personal`)
     - `Include all` → skip nothing (enum: `include_all`)
   - **(4b) Skip empty cells (F12).** With the surviving (post-filter) lead set, drop any cell in the 9-cell grid that has **0 leads** — do NOT create an empty campaign. Example: post-filter under `include_role` resolves to `(professional, Google): 84, (professional, Microsoft): 31, (professional, Other): 12, (role, Google): 3, (role, Microsoft): 0, (role, Other): 0` → create 4 campaigns (the 4 non-empty cells), skip the 2 empty role cells entirely. Record the skipped cells in scratch state so the metadata `segments` map reflects the actual (pruned) plan. If ALL cells are empty (either no leads survived the email-type filter, or every surviving lead's domain failed DNS), halt — the campaign has zero deliverable leads and Phase 3 cannot proceed.
   - **(4c) Consolidated skipped-contacts file write (only if non-empty).** This is the single skipped-contacts writer for the run. Write the **consolidated** skipped set: this phase's role/personal rows PLUS the Phase 1 step 2 stashed rows (`duplicate` + `undeliverable`) carried in scratch state. (Under `--no-host-lookup` Phase 2 does not run, so Phase 1 step 2d writes the file itself with just its rows — same path + same IV-8/IV-9 treatment; this writer covers the normal path.) Apply IV-8 (re-validate `--campaign-name` regex + realpath-confine the resolved path to the chosen write directory) and IV-9 (formula-injection neutralization on each cell value) before writing. Path convention mirrors the metadata JSON's dual-path rule from § Launch metadata schema "Dogfood write path" note:
     - **Production path:** `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}-skipped.csv`
     - **Dogfood path:** `.claude/worktrees/<detected-worktree>/dogfood/{campaign-name}-{YYYY-MM-DD}-skipped.csv`

     CSV columns: original CSV columns verbatim (preserve order, then apply IV-9 per-cell) + one new trailing column `skip_reason`. Values: `role_address`, `personal_domain` (this phase); `duplicate`, `undeliverable` (Phase 1 step 2, BC-14044); `liquid-metacharacter` (IV-10); `workspace_collision` (Phase 4, appended on a 422). If a lead matches both role + personal lists (tiebreak), `skip_reason` is `personal_domain` per the personal-beats-role rule. If the consolidated skipped set is empty, no file is created; `skipped_leads_csv_path` is `null`.
   - **(4d) Append to metadata JSON.** Set `segmented: true`, `segments: {<only non-empty post-filter cells, keyed by "{email_type}|{esp}", value {email_type, esp, count}>}`, `email_type_filter_applied: "<enum>"` (use the enum value from 4a, NOT the prose label), `skipped_leads_csv_path: <path>|null`, `last_completed_phase: 2`.

**User gate 2.** Ask via `AskUserQuestion`:

> Phase 2 detection summary for campaign `{base}`:
>
> **Email-type breakdown** (lead-level, before filter):
> - Professional — N leads
> - Personal     — N leads (free-mail domains)
> - Role         — N leads ({role-list-summary} addresses)
>
> {IF invalid_email_rows non-empty:}
> Skipped due to malformed email format: N rows.
> {END IF}
>
> {IF invalid_domain_rows non-empty:}
> Skipped due to invalid domain format (IV-4 regex filter, dropped before `dig`): N rows.
> {END IF}
>
> **9-cell segmentation grid** (after applying the chosen email-type filter — preview reflects current radio selection):
>
> | Email-type    | Google     | Microsoft  | Other      |
> |---|---|---|---|
> | Professional  | N leads    | N leads    | N leads    |
> | Role          | N leads    | N leads    | N leads    |
> | Personal      | N leads    | N leads    | N leads    |
>
> {IF any cell skipped by F12:}
> Skipped cells (0 leads after filter): {skipped-cell-list}. No campaigns will be created for these.
> {END IF}
>
> Detailed 8-bucket ESP breakdown (post-filter, rolled into the `Other` column above): Google N, Microsoft N, Proofpoint N, Mimecast N, Barracuda N, Cisco N, Custom N, Unknown N.
>
> **Default action: skip role + skip personal.** Only the {N-professional} professional leads will be segmented into up to 3 (Professional × ESP) campaigns.
>
> - Apply default — skip role + personal, segment professionals across (Professional × ESP) cells (Recommended)
> - Include role addresses too — also create (Role × ESP) cells, skip personal only
> - Include personal addresses too — also create (Personal × ESP) cells, skip role only
> - Include all — segment every lead across all (email-type × ESP) cells, no email-type filter
> - Abort

If the operator's chosen action leaves zero leads in any (email-type × ESP) cell after filtering, the F12 skip-empty-cells logic (step 4b) handles it.

**If Phase 2 fails:** the failure is almost always a DNS lookup error on a stale or typo'd domain. Halt and surface the failing domain. Operator fixes the CSV or accepts "Unknown" bucket leaks and re-runs. No EB state has changed. Malformed-email handling is documented in step 1's "Malformed-email handling" sub-bullet.

---

## Phase 3 — VARIABLES

**Purpose.** Create the `custom_variables` defined in the copy artifact in the EB workspace. These are merge-field definitions — values are attached per-lead in Phase 4. Running this before UPLOAD is required because `bulk_create_leads` will reject lead-level custom-variable values for variables that don't exist yet.

**With `--reference <campaign-id>` set:** call `get_campaign` (ground-truth the tool name via `search_api_spec`) on the reference campaign to fetch its variable set. Pre-fill the Phase 3 user gate with `{reference-variables}` as defaults. Operator still confirms — doesn't re-enter.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `custom variable create` — locate the exact tool (likely `create_custom_variable`). Also identify the `list_custom_variables` tool to check for pre-existing variables with the same name.
2. **Load variables from copy artifact.** From the parsed artifact (Phase 1 step 4), read `custom_variables[]`. Each entry has `{name, default}`. Example: `[{"name": "RECENCY_ANCHOR", "default": ""}, {"name": "PROOF_POINT_COMPANY", "default": ""}]`. The `default` is consumed in Phase 4 as the per-lead fill-in value when the CSV row lacks a column for this variable (see Phase 4 step 2 — the per-row custom_variables values + fallbacks paragraph) — it is NOT a workspace-scoped property of the variable in EB (per Sx-2, BC-6299 — EB's `POST /api/custom-variables` accepts only `{name}`).
3. **Check for existing variables.** Call `list_custom_variables` in the target workspace. For each artifact variable, classify:
   - **New** — not present in the workspace. Will create.
   - **Existing** — name matches case-insensitively (compare via `.lower()`; EB stores names lowercased per Sx-3 / BC-6299 — see `email-bison.md` § Known gotchas § Case-rule asymmetry); will NOT re-create (EB returns 422 on duplicate `POST /api/custom-variables`). Reuse as-is.
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
7. **Append to metadata JSON.** Persist `custom_variables_created: [{id, name}]` from each create response (response body is `{id, name, created_at, updated_at}` — no `default` field). Set `last_completed_phase: 3`. **Note (Sx-3, BC-6299):** EB silently lowercases names on store (`RECENCY_ANCHOR` → `recency_anchor`). Render-engine case-sensitivity verified BC-6308 round-3 R-2a: UPPERCASE tokens resolve correctly via case-insensitive lookup against the lowercased store; lowercase tokens do NOT resolve and render as literal text (BC-6548).

**If Phase 3 fails:** the workspace has some, none, or all of the variables created depending on where in the loop the failure happened. The metadata JSON's `custom_variables_created` list is authoritative for what's on the vendor side. **Note (Sx-4, BC-6299):** there is no `DELETE /api/custom-variables/{id}` endpoint. Custom variables persist workspace-scoped indefinitely; only the EB UI can remove them. Operator inspects the workspace and either retains the partial set (recommended for next re-run, since duplicate POSTs return 422) or manually removes via the UI; then re-runs the phase from scratch or patches the artifact to skip already-created names.

---

## Phase 4 — UPLOAD

**Purpose.** Create lead records in the EB workspace with per-lead `custom_variables` values. Leads exist as workspace-level records first; Phase 6 attaches them to specific campaigns. This is the first destructive phase in the flow — leads in EB carry tracking history and touch quota, so creating them is not free.

**Two-call gate required — agent-side, not vendor-side** (Sx-9, BC-5906; turn-structure rationale per BC-2707). Per § Tool tier map, `bulk_create_leads` is invoked via `call_api` against `/api/leads/multiple`, which has NO `confirmation` field at the API level and no dry-run — the one request creates the leads immediately. The gate this phase enforces is the **agent-side `AskUserQuestion`** turn: the operator sees the proposed action via the gate, and the single real `call_api` fires only after the operator's affirmative turn. There is no preliminary "no-confirmation" call — the operator turn IS the first half of the two-call structure, the real request is the second. BC-2707's turn-structure guarantee (model must yield before a consequential call) applies verbatim to this operator-side gate. Pattern:

1. Compose the proposed action agent-side — what will be created, in which workspace. No API call happens here; `/api/leads/multiple` has no dry-run, so any request to it creates immediately.
2. Relay that proposed action to the operator via `AskUserQuestion`.
3. Wait for the operator's response. If clear affirmative scoped to the operation ("yes", "approved", "go ahead", "proceed", "do it"), fire the single real `call_api` — the actual lead-create request. If ambiguous ("maybe", silence, off-topic), stop and re-ask.
4. **Never** fire that `call_api` in the same turn as the proposal. The anti-pattern this gate blocks is the skill issuing the mutating request without a real operator turn before it — not the wording of the affirmative (see `docs/precedents/BC-2707.md` for the turn-structure rationale). There is exactly one API request per chunk; there is no second `confirmation: true` call (see § Tool tier map for the wrapper-vs-API distinction).

**Gate cadence for chunked uploads.** At >500 leads the upload runs in N chunks of ≤500. Re-prompting a semantic "Are you sure?" per chunk trains gate-fatigue: the operator reflexively approves chunks 2..N and the gate stops being a real safety check. Separate the two concerns:

- **Semantic approval (operator-intent) — once**, via User gate 4 below, covering the entire batch. The operator sees the chunk count, sample rows, and lead-count total; approves the full run.
- **Turn-structure preservation (BC-2707) — per chunk**, via a minimal pass-through prompt that re-renders the agent-composed per-chunk action summary. The prompt is deliberately thin ("Chunk i/N — create {N} leads in {W}. Continue?") because the semantic gate already fired once; this prompt exists solely to create the user turn before the chunk's single real `call_api` per BC-2707's turn-structure contract.

The turn-structure prompt IS an `AskUserQuestion` — it must be, to create a real user turn before the chunk's mutating `call_api`. Rapid-fire affirmatives ("y" / "yes" / "do it") from the operator are expected and valid — they preserve BC-2707 turn structure without burning semantic attention. Abort at any chunk halts the remaining chunks; chunks already committed stay.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `bulk create leads`. Per `email-bison.md` § Common workflows the verified endpoint path is `POST /api/leads/multiple`. The conceptual label `bulk_create_leads` in this spec maps to that endpoint via `call_api`. Variant endpoint: `bulk_create_leads_csv` (CSV-upload variant, `POST /api/leads/bulk/csv`) — note that this endpoint preserves `columnsToMap[]` key case at lead-display layer (e.g., `columnsToMap[RECENCY_ANCHOR]` → `custom_variables[].name = "RECENCY_ANCHOR"` on the resulting lead), while the JSON `/api/leads/multiple` endpoint silently lowercases (BC-6780). Workspace schema (`GET /api/custom-variables`) is unaffected by either endpoint — lowercase canonical. Render behavior is the same across both endpoints (UPPERCASE-only token resolution per BC-6548); case-preservation is purely cosmetic at the lead-display layer. See `email-bison.md` § Case-rule asymmetry for the full 4-endpoint cross-reference (BC-7980). There is no separate `upsert_multiple_leads` endpoint, AND `/api/leads/multiple` does NOT upsert existing leads — re-POSTing a batch with any already-existing-lead email returns HTTP 422 and rejects the whole batch (Sx-8 atomic rule). Verified BC-6785 round-5 R-6 (1-row case) + BC-7667 round-6 R-6 (1-row case) + BC-11072 spike (mixed batch — 1 existing + 1 new, atomic-422, neither row created; 2026-05-22). Variant-endpoint absence verified BC-6785 R-28 (`POST /api/leads/upsert-multiple` → 405, `PUT` → 422 for both UPPERCASE and lowercase bodies, no `search_api_spec` matches for "upsert"). Default to `/api/leads/multiple` unless the artifact or operator instructs otherwise.
2. **Prepare lead batches.** Read the CSV. For each row, build the lead object using EB's lead-body field names (NOT the CSV column names — Sx-6, BC-5906):

   ```json
   {
     "email": "<csv email>",
     "first_name": "<csv first_name>",
     "last_name": "<csv last_name — if column present>",
     "title": "<csv job_title — if column present>",
     "company": "<csv company_name — if column present>",
     "custom_variables": [
       // Names lowercased here — EB's POST /api/leads/multiple rejects (HTTP 422) UPPERCASE names (BC-6780).
       // Artifact uses UPPERCASE everywhere; agent translates at this boundary only. See "Lowercase names before send" below.
       {"name": "recency_anchor", "value": "<row-specific value>"},
       {"name": "proof_point_company", "value": "<row-specific value>"},
       {"name": "company_domain", "value": "<csv company_domain>"}
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

   **Lowercase names before send (BC-6780).** EB's `POST /api/leads/multiple` requires `custom_variables[].name` to be exact-lowercase — UPPERCASE names return HTTP 422 and reject the whole chunk (verified BC-6554 round-4 S-4). Apply `name.lower()` to every `custom_variables[].name` entry as the final step of body construction; the result must match `^[a-z][a-z0-9_]*$` (verified by the step 6 pre-loop guard). Touch ONLY the `.name` keys inside the `custom_variables` array — do NOT lowercase `.value` (per-lead content), the surrounding lead-body fields (`email` / `first_name` / etc.), or any artifact content; only the per-call body's variable-name keys. Authors keep UPPERCASE everywhere in the copy artifact (BC-6548 token-render rule); the translation happens here only, at the API boundary.

   This is consistent with EB's silent lowercase-on-store at variable creation (Phase 3 step 7) and case-insensitive render-engine lookup. `POST /api/leads/multiple` is the ONLY endpoint with a strict lowercase requirement — see `email-bison.md` § Known gotchas § Case-rule asymmetry for the full three-rule table.
3. **Chunk to the 500-lead limit.** `bulk_create_leads` accepts 500 leads per call (verified in `email-bison.md` § Rate limits). EB does NOT upsert existing leads on re-POST — see step 1 above and `email-bison.md § Known gotchas` Sx-8 + BC-11072. If `lead_count > 500`, split into chunks of 500. Per the "Gate cadence for chunked uploads" note above, User gate 4 fires ONCE for the full batch; each chunk subsequently fires only a minimal turn-structure prompt.
4. **Show sample.** Before User gate 4, show the operator a sample of 3 leads (rows 2, middle, last) with full `custom_variables` rendered:

   > Sample of 3 leads from chunk 1 of {M}:
   >
   > 1. email: `alex@denvergov.org`, first_name: `Alex`, custom_variables: [recency_anchor: "the Denver downtown master plan announcement last month"]
   > 2. ...
   > 3. ...
5. **User gate 4 (semantic approval — once, covers all chunks).** Ask via `AskUserQuestion`:

   > About to create **{lead_count} leads in {M} chunks of ≤500** in workspace `{workspace}`. Sample (3 leads from chunk 1) shown above. Each chunk fires a minimal turn-structure prompt; semantic approval lives here.
   >
   > - Yes, create all {lead_count} leads across {M} chunks
   > - Abort the upload
6. **Pre-loop guard (BC-6780) — HARD FAIL, fires once.** After User gate 4, before entering the per-chunk loop, assert that every `custom_variables[].name` in the constructed body schema matches `^[a-z][a-z0-9_]*$` — no uppercase characters anywhere. The name set comes from the artifact (`custom_variables[]` in the copy JSON) and is loop-invariant across all M chunks; one assertion covers the whole run. **HALT** the run if any name fails the check. Error message: "Body contains UPPERCASE custom_variables[].name `{name}` — EB's POST /api/leads/multiple requires lowercase or returns HTTP 422 (BC-6780). Agent translation step (Phase 4 step 2 'Lowercase names before send') was skipped or incomplete." This guard mirrors the BC-6548 Phase 1 step 5 token-UPPERCASE check (inverse case, same enforcement shape — pre-loop, single pass) — its role is to catch translation-step regressions before they hit EB and 422 the first chunk.

7. **Per-chunk loop with turn-structure preservation.** For each chunk `i` in 1..M:

   a. **Compose the per-chunk action** (no API call). Build the operator-facing summary of what this chunk creates (typically: "This will create {N} lead records in workspace {W}. Proceed?"). `/api/leads/multiple` creates immediately on the one real request in (c), so nothing is sent to EB here.
   b. **Turn-structure prompt** (thin, fires per chunk to preserve BC-2707 turn structure — not a re-approval):

      > Chunk {i}/{M} — {the (a) summary, e.g. "create {N} lead records in workspace {W}"}
      >
      > - Continue
      > - Abort remaining chunks (chunks 1..{i-1} stay committed)

      Operator rapid-fire affirmatives are expected. The prompt exists solely to create the user turn required before the chunk's single real `call_api`.
   c. **Execute — the single real call.** On "Continue", invoke `bulk_create_leads` via `call_api` — the one and only API request for this chunk (no `confirmation` field; see § Tool tier map). On HTTP 201, capture the returned lead IDs and loop to the next chunk. On **HTTP 422**, go to (d) — do NOT HALT.
   d. **Workspace-collision recovery (BC-14044) — on HTTP 422 only.** A 422 means ≥1 email in this chunk already exists as a workspace lead (`/api/leads/multiple` is atomic + non-upserting — the whole chunk rejected, nothing created; Sx-8, BC-11072). `call_api` strips the body to `{error: "HTTP 422 Error"}` with no per-row detail, so identify the collisions client-side:
      i. **Build the workspace existing-email set (once per Phase 4, cached).** Paginate `list_leads` by incrementing `page` (1, 2, … until the response's page count is exhausted) — EB ignores `per_page` and hard-caps the page size at 15, so this is ~1,029 GETs at ~15,400 leads, incurred on every 422 incl. the re-run case — for the target workspace; collect `email.strip().lower()` into a set. This reactive scan is a backstop — the opt-in proactive single-workspace exclusion pre-pass in **BC-16147** filters before upload to avoid the 422 (and this scan) entirely. A later chunk's 422 reuses the cached set — never re-page per chunk. Cost is paid ONLY on a real 422 (the rare / re-run case), never on a clean launch.
      ii. **Diff.** Intersect this chunk's lowercased emails with the set → the colliding emails. **If the intersection is empty**, the cache may be stale — a lead created since it was built (by another process, or by an earlier chunk of this very run), which the once-cached set wouldn't contain — so **refresh the set once** (re-paginate `list_leads`, replacing the cache) and re-diff. Only if the intersection is STILL empty after the refresh is the 422 a genuine non-collision (e.g. a malformed row) → HALT with the chunk's lead-row range and the stripped error; do NOT resubmit blindly. A stale cache must never convert a recoverable collision into a false HALT.
      iii. **Set aside.** Append the colliding rows to the consolidated skipped-contacts file (`skip_reason: workspace_collision`; same Phase 2 step 4c columns + IV-8 / IV-9 treatment). If the file did not yet exist — a clean list whose first skip is here — this creates it, so **update `skipped_leads_csv_path` in metadata to the file path** (Phase 2 step 4d may have recorded `null` when there were no earlier skips; a written file must never be left with an unrecorded path). Record the collision count in scratch state for step 9 + step 10 (`workspace_collisions_skipped`).
      iv. **User gate 4b (semantic — resubmit confirm, never silent).** Ask via `AskUserQuestion`: "{k} of the {n} leads in chunk {i} already exist in `{workspace}` (set aside in the skipped-contacts file). Upload the remaining {n−k}?" Options: "Yes, upload the {n−k} clean leads" / "Abort remaining chunks". This is a genuine semantic gate — the send set changes — NOT a turn-structure prompt. **Never auto-resubmit** (decision-locked, BC-14044).
      v. **Resubmit the cleaned chunk.** On approval, re-run (7a → 7c) with the {n−k} non-colliding rows. If **n−k == 0** (whole chunk already exists — classic full re-run), skip the POST entirely, log "chunk {i}: all {n} already in workspace, nothing to upload", and continue. A resubmitted chunk that 422s **again** (a lead created between the scan and the resubmit) repeats (d) once using a refreshed set; a second consecutive non-collision 422 HALTs.
8. **Abort handling.** On any chunk's "Abort remaining chunks" response, HALT — do not start the next chunk. Chunks 1..{i-1} remain committed (their leads exist in EB); `lead_ids_uploaded` in metadata reflects only committed chunks. Operator re-runs with a delta CSV if they want to resume.
9. **Verify lead count (BC-14044 — collision-aware).** Sum the lead IDs created across all chunks. The expected total is `lead_count − {workspace_collision rows set aside in step 7d}` — the cleaned upload target minus any already-in-workspace leads the operator chose to skip at gate 4b. Confirm `sum == expected`. Within-file duplicates were already removed in Phase 1 step 2 (so they never cause a shortfall here), and a 422 is handled gracefully in step 7d (not as a HALT here). A shortfall **beyond** the recorded collision-skips means leads silently failed to create — HALT with the chunk range + the collision-skip count for the operator to reconcile against the EB UI. **Zero-upload guard (BC-14044):** if `lead_ids_uploaded == 0` (every lead was an already-in-workspace collision set aside at gate 4b, or all chunks aborted), HALT here — do NOT advance to Phase 5, which would create campaigns with no leads to attach (Phase 6 attaches only THIS run's uploaded IDs). Surface: "{N} leads all already exist in `{workspace}` — nothing new to upload. Attaching pre-existing workspace leads to fresh campaigns is not auto-handled; attach them via the EB UI, or re-run with a delta list of only new contacts." Keep `last_completed_phase` at 4.
10. **Append to metadata JSON.** Set `lead_ids_uploaded: <total>`, `workspace_collisions_skipped: <count from step 7d, 0 if none>`, `last_completed_phase: 4`.

**If Phase 4 fails mid-chunk:** some chunks have succeeded, others haven't. `lead_ids_uploaded` in the metadata is authoritative. Re-run reads the metadata, identifies that not all leads uploaded, and operator chooses to (a) delete the partial set via EB UI and re-upload from scratch, or (b) delta the CSV to only the unuploaded leads and re-run. The command does NOT auto-delta. Note (BC-14044): an already-in-workspace collision is no longer a "failure" — step 7d sets the colliding rows aside and resubmits the clean remainder after gate 4b; only a non-collision 422 or an unexplained shortfall (step 9) HALTs.

---

## Phase 5 — CAMPAIGN CREATE

**Purpose.** Create one empty campaign shell per non-empty (email-type × ESP) cell from Phase 2's `segments` map (or one combined campaign if `--no-host-lookup` skipped Phase 2). Campaigns at this point have no leads, senders, schedule, or sequence — those come in phases 6–9.

**With `--reference <campaign-id>` set:** call `get_campaign` on the reference campaign to fetch its name template, offer metadata, and other config. Pre-fill the naming convention + description in the Phase 5 user gate.

**Identity pre-check (resume-safe, BC-13863).** Before any campaign is created (step 6), ensure the chosen identity tag is resolved and exists in the target workspace. A fresh run already did this in Phase 1 step 10 — but a **resumed run skips Phase 1**, and a `--preview` breadcrumb **skipped resolution** even with an explicit `--identity`. So if `identity_tag_id` isn't already resolved: resolve `sending_identity` if null (prompt), then `search_api_spec` + `call_api` to list the workspace tags once, capture `identity_tag_id` (the chosen identity's id), and **HALT if the chosen identity's tag is absent**. This closes the missing-tag failure *before* step 6 creates campaigns on **every** path (fresh, resumed, preview-then-resume) — so a misconfigured workspace never orphans campaigns. Only the chosen id is needed here; the reuse-path cleanup (step 9b) reads each reused campaign's own tags, so no sibling identity ids are ever pre-resolved.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `create campaign`. Per `email-bison.md` § Common workflows the name is `create_campaign` with path `POST /api/campaigns`. Returns a campaign ID.
2. **Determine campaign names.** Two paths:

   - **`--no-host-lookup`**: one campaign named `{campaign-name}`.
   - **Default (multiplicative)**: one campaign per non-empty cell in metadata's `segments` map. Default naming convention from the copy artifact's preset (if preset supplies one) or the Brite default short form: `{campaign-name-base} | {Email-type-titlecased} | {ESP}` — e.g., `Denver Downtown Lighting | Professional | Google`, `Denver Downtown Lighting | Role | Microsoft`. Email-type comes before ESP per BC-6514 (matches workspace 13 production naming, which groups per-vertical campaign rosters by email-type first). Capitalize the email-type label for display: `professional` → `Professional`, `role` → `Role`, `personal` → `Personal`. Full long-form convention per issue spec: `{Niche} | {Target} | {Source} | {Region} | {Size} | {Offer}` — applies when copy artifact preset declares it. Operator can override the suffix format in the user gate.
3. **Pre-list existing campaigns by base name (silent-duplicate guard, F20 / BC-6302).** Call `list_campaigns(search="{campaign-name-base}")` (core-tier, directly callable per § Tool tier map). EB's `search` is substring-matched and has no API-side dedup — calling `create_campaign` twice with identical names returns two distinct IDs with `success: true` and no warning. This pre-list is the only place the operator sees pre-existing matches before User gate 5. Capture campaigns whose `name` starts with `{campaign-name-base}`. Empty match set is the happy path; non-empty triggers the duplicate-guard render in step 5. Record the matched IDs in scratch state for step 6's reuse path.
4. **Render the create plan.** Show the operator each proposed campaign:

   > Campaigns to create in workspace `{workspace}`:
   > 1. `Denver Downtown Lighting | Professional | Google` — 84 leads
   > 2. `Denver Downtown Lighting | Professional | Microsoft` — 31 leads
   > 3. `Denver Downtown Lighting | Professional | Other` — 12 leads
   > 4. `Denver Downtown Lighting | Role | Google` — 3 leads
5. **User gate 5.** Ask via `AskUserQuestion`. The render branches on step 3's pre-list:

   **If step 3's pre-list is empty (no duplicates):**

   > Create {N} empty campaigns with the names above? Campaigns start in `Draft` state — no sends until Phase 11. After create, each campaign will be PATCHed with `plain_text: true` (cold-outreach deliverability default — no opt-out).
   >
   > - Yes, create these campaigns (Recommended)
   > - Rename — I'll supply a different suffix convention
   > - Abort

   **If step 3's pre-list returned `M` matches:** prepend a duplicate warning and add a fourth "Reuse" option. Render up to 10 matches inline; if more, append `and {K} more` to the list:

   > ⚠️ {M} campaigns already exist matching `{campaign-name-base}` in workspace `{workspace}`:
   >   - id 22 — `BC-5906 Round 2 | Google` (draft)
   >   - id 24 — `BC-5906 Round 2 | Google` (draft)
   >   - … (and {K} more)
   >
   > Create {N} new campaigns anyway, or reuse existing IDs?
   >
   > - Reuse existing IDs (Recommended if names match exactly per bucket)
   > - Create {N} new campaigns anyway
   > - Rename — I'll supply a different suffix convention
   > - Abort

   The "Recommended" annotation flips between paths because the safer default differs: when nothing matches, create; when matches exist, reuse.
6. **Execute creates or reuse existing IDs.** Branch on User gate 5 decision:

   - **"Reuse existing IDs":** For each bucket from step 2, find the matching campaign ID in step 3's pre-list using exact `name` equality. Map bucket → ID. Skip the `create_campaign` calls entirely. If any bucket has zero exact matches in the pre-list, halt and surface which bucket has no match — operator must restart Phase 5, choosing Rename or Create at User gate 5.
   - **"Create {N} new campaigns anyway" or empty pre-list:** For each name in the plan, call `create_campaign`, capture the returned campaign ID, map bucket → ID, **and append that id to the metadata's `campaign_ids` immediately** — an incremental persist, so that if a *later* create in the loop fails, the campaigns already created still have a breadcrumb (no orphaned, unrecorded campaigns; a rerun's step-3 pre-list then finds them for reuse instead of duplicating). Keep `last_completed_phase` at its prior value (4).
   - **"Rename":** restart from step 2 with the operator-supplied suffix convention.
   - **"Abort":** halt; do not advance `last_completed_phase`.
7. **Verify IDs + finalize flags.** Confirm every bucket has a campaign ID (created or reused). Since step 6 persists each `campaign_ids` entry the moment its campaign is created (and the reuse branch maps pre-existing ids), the breadcrumb is already current — a `create_campaign` that fails partway, or a later HALT in the step 8–9 loops, still leaves every created campaign recorded. Also persist `existing_campaign_matches` + `reused_existing_ids` now. If any create failed, halt and surface the specific bucket + error — do NOT retry automatically (the partial set is recorded and resumable). Leave `last_completed_phase` at 4; Phase 5 completes at step 10.
8. **Apply plain_text deliverability default.** For each campaign ID confirmed in step 7, call `update_campaign` (path `PATCH /api/campaigns/{id}/update` per `email-bison.md` § Tool inventory + verified via `search_api_spec`) with `plain_text: true`. This PATCH is **always** applied — it is a deliverability invariant for cold outreach (the only use case `/marketing:launch-campaign` serves) and has no operator opt-out. EB defaults `plain_text` to `false` on create, which sends emails as HTML; HTML mode for cold B2B carries tracking pixels, link rewrites, and image references that signal "automated marketing" to spam filters. The copy artifacts produced by `email-copywriting` use `<br><br>` for paragraph breaks and contain spintax — both assume plain-text rendering. Note: `update_campaign` is NOT on `email-bison.md` § MCP confirmation gates list; this is a single MCP call per campaign, no two-call cycle. **EB's PATCH treats omitted boolean fields as `false`** (per the API spec — *"If nothing sent, false is assumed."*; verified BC-6544). The single `plain_text: true` PATCH is safe BECAUSE campaigns start with all-false defaults — but ANY future PATCH on this campaign that intends to preserve `plain_text: true` MUST re-send it explicitly in the body. The same rule applies to any other boolean setting (`open_tracking`, `can_unsubscribe`, `reputation_building`, etc.). Re-asserting `plain_text: true` against an already-plain-text campaign is the safe no-op; OMITTING it from a subsequent PATCH silently resets it. Reused campaigns and resume runs are safe under the current single-PATCH flow; do NOT add a second PATCH to this campaign without re-sending `plain_text: true`. Track per-campaign PATCH success in scratch state for step 10's metadata write.
9. **Attach the sending-identity tag to each campaign (BC-13863).** Push the `sending_identity` resolved in Phase 1 (`labs`/`supply`/`nites`) onto every campaign created or reused above, so downstream tooling — and BC-13864's identity-matched sender selection — can filter by it. Identity tags are **per-workspace** (the same identity has different tag ids in the commercial vs personal instances), so the id is resolved fresh per run — up front (Phase 1 step 10 / the Phase 5 identity pre-check), never hardcoded.

   a. **Use the identity tag id resolved by the Phase 5 identity pre-check** (above, before step 6). That pre-check guarantees — on fresh, resumed, AND preview-then-resume runs, all *before any campaign was created* — that `sending_identity` is set, the chosen tag exists, and `identity_tag_id` is resolved. So here, just use it; never attach a null/unresolved tag id. Creation is owned by the platform reconcile (BC-13861); this command only attaches. See `email-infrastructure-orchestration-platform/docs/designs/email-bison-tag-behavior.md`.
   b. **Attach to each campaign.** `search_api_spec` for the campaign-tag attach endpoint **once** (its shape is invariant across campaigns), then for each campaign ID confirmed in step 7, `call_api` to attach the resolved tag id — one `call_api` per campaign, no two-call gate (a low-risk metadata write like the step 8 `plain_text` PATCH; the identity was already chosen + confirmed at User gate 1, and creation was gated at User gate 5). **Reuse path:** a campaign reused via "Reuse existing IDs" may already carry a *different* identity tag from a prior launch. For each reused campaign, read its **own current tags** (e.g. `get_campaign`) and look for an identity tag — recognized by the constant names `Labs`/`Supply`/`Nites` — that isn't the chosen one. If found, **HALT and surface** the campaign + the conflicting identity for the operator to resolve; do NOT silently detach (a campaign carrying two sending identities routes ambiguously under BC-13864, and reusing a campaign while *changing* its identity is unusual enough to warrant a human check). Reading the campaign's own tags means **no sibling tag ids need pre-resolving** — the campaign's tag list carries every name + id directly. Fresh creates have no prior tag, so this only fires on reuse.
   c. **Idempotency + failure handling.** Treat an "already attached" / duplicate-tag response as **success**, not a failure — tag-attach is idempotent (verified for sender-email tags in BC-13861, `email-infrastructure-orchestration-platform/docs/designs/email-bison-tag-behavior.md`; campaign tags are expected to behave the same). This is what makes a resume or a "Reuse existing IDs" re-run safe (step 9 re-attaches to every campaign — see the mid-loop recovery note below). Only a *genuine* attach failure triggers **HALT and surface** the campaign ID + error — do not silently continue, since an existing-but-untagged campaign would later route the wrong senders under BC-13864. (`identity_tag_id` is resolved by Phase 1 step 10 or the Phase 5 identity pre-check — always before step 6.)
10. **Append to metadata JSON.** `campaign_ids` (e.g. `{"professional|Google": 5551, ...}` — one entry per non-empty cell from `segments`, keyed by `{email_type}|{esp}`), `existing_campaign_matches`, and `reused_existing_ids` were already persisted in step 7. Now append `plain_text_applied: true` (only if step 8 PATCH succeeded for ALL campaigns; else `false`) and `identity_tag_id: <the per-workspace tag id resolved in Phase 1 + attached in step 9>`, and set `last_completed_phase: 5`. Also seed `activated_per_campaign: {<bucket>: null, ...}` with one key per bucket in `campaign_ids` — pre-populated to null so Phase 11 step 4 can flip them per iteration without first probing for object presence (and so the global `activated` flag has a deterministic AND-of-non-null check at finalization).

**If Phase 5 fails mid-loop:** partial campaigns exist in the workspace. Because step 6 persists each `campaign_ids` entry the moment its campaign is created, the metadata always lists every campaign that exists — whether a `create_campaign` fails partway through step 6, or a step 8 PATCH / step 9 attach HALTs later (in all of these `last_completed_phase` stays at 4, not 5). `plain_text_applied: true` is recorded (step 10) only if the step 8 PATCH loop completed for ALL campaigns; a `false`/absent value means partial-PATCH state may exist (some campaigns plain-text, others HTML). Operator inspects EB UI, decides whether to delete the partial campaigns or resume by running a reduced version of Phase 5 that creates only the missing ones. On resume, the step 3 pre-list will surface the partial-set as duplicates; the operator selects "Reuse existing IDs" for buckets already created and "Create … anyway" only for buckets that didn't get an ID on the prior run. After partial-PATCH, the spec re-runs the step 8 PATCH loop on every campaign in `campaign_ids` regardless of prior state. Each PATCH re-sends `plain_text: true` explicitly; already-plain-text campaigns are safe no-ops on re-send (the omitted-field reset risk only fires if a different PATCH body is sent without re-asserting `plain_text: true` — see step 8). **Step 9 (identity tag) also re-runs on resume** — re-attaching the tag to every campaign in `campaign_ids` — which is safe because tag-attach is idempotent (step 9c): an already-tagged campaign returns success, so the HALT-on-attach-failure never trips on a re-tag. No automatic partial-resume.

---

## Phase 6 — ATTACH LEADS

**Purpose.** Attach the lead IDs created in Phase 4 to the campaign IDs created in Phase 5, bucketed by (email-type × ESP) cell. This is the join step between the lead pool and per-cell campaigns.

**Two-call gate applies — agent-side** (Sx-9, BC-5906; turn-structure per BC-2707). `import_leads_to_campaign` is listed as vendor-gated in `email-bison.md § MCP confirmation gates`, but per § Tool tier map this command invokes it via `call_api` against `/api/campaigns/{id}/leads/attach-leads`, which has NO `confirmation` field at the API level. The load-bearing safeguard is the agent-side `AskUserQuestion` turn that must precede the single real `call_api` — same shape as Phase 4. The `allow_parallel_sending` branch below IS a real semantic vendor gate (verified BC-6545, 2026-05-04 — attach returns HTTP 422 on lead-already-in-any-campaign conflict; through `call_api` the response body is stripped to `{error: HTTP 422 Error}` per the Sx-8 wrapper limitation, but `allow_parallel_sending: true` in the body succeeds when added), so it stays as-written.

**Gate cadence for multi-campaign attach (same pattern as Phase 4).** User gate 6 is the **semantic operator-intent gate** and fires ONCE for the full per-campaign batch. Per-campaign turn-structure prompts fire — **minimal**, not a semantic re-approval. Rapid-fire affirmatives per campaign are expected; the prompt's only job is to create the user turn required by BC-2707's turn-structure contract.

**`allow_parallel_sending` alert** per `email-bison.md` § Known gotchas: if any lead being attached is already in another campaign (regardless of campaign status — verified BC-6545, 2026-05-04 against draft campaigns), the tool refuses with HTTP 422. **Never auto-enable parallel sending.** Surface the conflict to the operator via `AskUserQuestion` — relay the prompt body verbatim if the path surfaces it; through `call_api` the body is stripped (Sx-8 wrapper limitation), so present the operator-side diagnostic per step 5d below. Parallel sending can over-contact a prospect across campaigns and is a deliverability risk. This is a genuine semantic gate (not turn-structure filler) because the decision materially changes who gets emailed.

**Steps:**

1. **Ground-truth the tool name.** `search_api_spec` with query `attach leads` or `import leads to campaign`. Per `email-bison.md` § Common workflows the name is `import_leads_to_campaign` with path `POST /api/campaigns/{id}/leads/attach-leads`.
2. **Bucket the lead IDs by (email-type × ESP) cell.** From the **uploaded** lead set (Phase 4's returned lead IDs — NOT the raw CSV rows) joined to each lead's Phase 2 cell assignment, build a map `{"{email_type}|{esp}" → [lead_id, lead_id, ...]}` keyed identically to metadata's `segments` and `campaign_ids`. Each uploaded lead belongs to exactly one cell. Rows set aside in Phase 1 step 2 (`duplicate` / `undeliverable`) or Phase 4 step 7d (`workspace_collision`) have no lead ID and are absent here by construction (BC-14044), so the per-campaign counts reconcile at step 6.
3. **Show attach plan.** Render per-campaign counts:

   > Attach plan:
   > - `{campaign_ids["professional|Google"]}` ← 84 leads
   > - `{campaign_ids["professional|Microsoft"]}` ← 31 leads
   > - `{campaign_ids["professional|Other"]}` ← 12 leads
   > - `{campaign_ids["role|Google"]}` ← 3 leads
   > Total: 130 leads attached across 4 campaigns.
4. **User gate 6 (semantic approval — once, covers all campaigns).** Ask via `AskUserQuestion`:

   > Attach {total} leads to {N} campaigns per the plan above? Per-campaign minimal turn-structure prompts fire after this one semantic approval.
   >
   > - Yes, proceed with attach across all {N} campaigns
   > - Abort
5. **Per-campaign loop with turn-structure preservation.** For each campaign in the bucket map:
   a. **Compose the per-campaign action** (no API call). Build the operator-facing summary of the attach — campaign ID + lead count. The one real request fires in (c).
   b. **Turn-structure prompt** (thin — per-campaign, preserves BC-2707 turn structure, not semantic re-approval):

      > Campaign `{id}` — {the (a) summary, e.g. "attach {count} leads"}
      >
      > - Continue
      > - Abort remaining campaigns

   c. **Execute — the single real call.** On "Continue", invoke `import_leads_to_campaign` via `call_api` — the one and only API request for this campaign (no `confirmation` field; see § Tool tier map).
   d. **`allow_parallel_sending` branch** (semantic, not turn-structure): if the `call_api` response is `{error: HTTP 422 Error}` against `/leads/attach-leads` (verified BC-6545 — F22 safety check firing on lead-already-in-any-campaign conflict, regardless of the other campaign's status), treat it as a real semantic gate. The verbatim prompt body is stripped through `call_api` (Sx-8 wrapper limitation); the vendor-tool path may surface it but was not verified this round. Relay the prompt body verbatim if the path surfaces it; otherwise present the operator-side diagnostic — call `list_leads` filtered on `lead_campaign_status=in_sequence` and cross-reference against the lead IDs in the failing batch to identify which leads are in conflict. Then ask the operator to either (a) decline (default) — delta the leads already in other campaigns, attach only the delta, list the skipped leads at the end, or (b) approve parallel sending — explicitly documented as a deliverability risk. Never auto-approve.
6. **Verify per-campaign counts.** After each attach, re-query the campaign's lead count (via `get_campaign` or equivalent) and confirm it matches the attached count. If mismatch, halt and surface the discrepancy.
7. **Append to metadata JSON.** The `campaign_ids` already list the per-campaign mapping. Add `lead_attach_counts: {<bucket>: <count>, ...}` mirroring `segments` (compound key shape). Add `lead_ids_by_bucket: {<bucket>: [<lead_id>, ...], ...}` from the bucket map built in step 2 — this is the resume primitive that lets a Phase 6 re-run reconstruct the bucket→IDs mapping without re-running Phase 2 MX lookups + CSV-row joins. Set `last_completed_phase: 6`.

**If Phase 6 fails mid-campaign:** some campaigns have attached leads, others don't. Metadata indicates which ran (`last_completed_phase`). Operator inspects EB UI per campaign and re-runs Phase 6 scoped to the unattached campaigns.

---

## Phase 7 — ATTACH SENDERS (CRITICAL INVARIANT)

**Purpose.** Attach this run's sender pool — scoped by the operator-selected `sender_match_mode` — to every campaign. This is the single most consequential phase of the flow, and the invariant it enforces is load-bearing for deliverability.

**Scope (BC-13864).** Sender attach is an **operator-selected step**: a Phase 7 prompt (or the `--sender-match` flag) picks one of four modes — `identity` (the run's brand senders only, the redirect-safe default), `esp` (senders matching each campaign's recipient ESP), `both` (identity ∩ ESP), or `all` (every connected sender, redirect-*unsafe*). All four are wired: the two **uniform** modes — `identity` (verified `tag_ids=[identity]`) and `all` (every connected sender, no filter) — attach the same pool to every campaign; the two **per-bucket** modes — `esp` and `both` — apply a *different* filter to each campaign cell via the three-way Google / Microsoft / SMTP mapping (step 2). Empty per-bucket cells are never silent: surfaced + confirmed at User gate 7, with `both` falling back to identity-only for that cell (redirect-safe). ⚠️ That `both`→identity fallback is flagged **provisional** — see step 2i.

### The invariant

> **Attach ALL of this run's identity-matched senders to ALL campaigns. Never split that pool across campaigns.** *(This is the `identity` mode — the redirect-safe default; `esp` / `both` / `all` vary it as the paragraphs below detail.)*

The pool is scoped to the run's sending identity (`tag_ids=[identity]`, BC-13864): an identity-mismatched sender — say a Nites inbox on a Supply campaign — lands the prospect on the wrong brand's site after the redirect cutover, which is the forcing function for this whole change. **Within the identity-matched pool the even-spread rule still holds:** sender warmup and reputation are per-inbox, not per-campaign, so every campaign gets the *whole* identity pool — splitting it across per-cell campaigns concentrates volume on a subset of inboxes, burning reputation unevenly for no analytical benefit. The only split is *across* identities (different brands) — and, in the per-bucket modes, *across* ESPs (each cell draws senders on its recipients' ESP, step 2) — by design. Revgrowth 10's upstream `launch.py` encodes the even-spread rule; Brite inherits it, now scoped per identity. **In the identity-scoped modes (`identity`, `both`) any deviation — rationing a pool across campaigns, OR attaching an off-identity sender — is a hard failure surfaced to the operator; the command offers no split-sender flag.** (`all` and the ESP axis of `esp` relax the identity rule by design — see the next two paragraphs.)

**Per-bucket modes (`esp` / `both`) draw a different pool per cell.** When the operator selects `esp` or `both`, each campaign cell (Google / Microsoft / Other) gets the senders that match *its* recipients' ESP — so the cells legitimately hold different pools with different counts. This is **not** the forbidden split: the forbidden split rations *one* pool across same-cell campaigns to concentrate volume; per-bucket modes give each cell its *whole* matching pool, and the even-spread rule still holds within a cell. `esp` carries no identity guarantee (an ESP-matched sender may be any brand); `both` is identity ∩ ESP and keeps the off-identity-sender = hard-failure rule per cell.

**`all` mode opts out of identity scoping.** When the operator selects `all`, the pool is *every* connected sender — not identity-scoped — a deliberate, redirect-*unsafe* choice surfaced with a warning at both the mode prompt and gate 7. The even-spread rule still holds: that full pool attaches *whole* to every campaign, never split across them. The "off-identity sender = hard failure" rule above is specific to the identity-scoped modes; in `all` mode off-identity senders are the explicit, operator-selected result, not a violation.

### Sender-match mode (BC-13864)

Phase 7 attaches senders per an operator-selected **sender-match mode**. Resolve it once, here, before enumerating (step 2):

1. **From the flag or a resume.** If `--sender-match` was provided, use it — already IV-12-validated to one of `identity` / `esp` / `both` / `all`. On a **resume**, read `sender_match_mode` from the metadata breadcrumb instead of re-prompting.
2. **From the operator.** Otherwise prompt via `AskUserQuestion` (no silent default — the operator must choose):

   > Which senders should attach to each campaign?
   >
   > - `identity` — only this run's `{sending_identity}` brand senders (redirect-safe) (Recommended)
   > - `esp` — only senders whose ESP matches each campaign's recipient ESP
   > - `both` — identity ∩ ESP (brand senders that also match the cell's ESP)
   > - `all` — every connected sender ⚠️ redirect-UNSAFE: an off-brand sender lands the prospect on the wrong site after the redirect cutover

   **Under `--no-host-lookup`** (one combined campaign, no ESP split) offer **only `identity` / `all`** — omit `esp` / `both`, which have no cell ESP to match. (An explicit `--sender-match esp|both` combined with `--no-host-lookup` was already rejected at IV-12 pre-flight, so any flag value reaching here under `--no-host-lookup` is `identity` or `all`.)

3. **Record it.** Write `sender_match_mode` to metadata *before* any attach so a resumed run re-reads it. All four modes are wired in the steps below: the **uniform** modes (`identity`, `all`) enumerate one pool attached to every campaign; the **per-bucket** modes (`esp`, `both`) enumerate a different pool per campaign cell via step 2's three-way ESP mapping.

### Pagination is mandatory

**Note: `?per_page=N` is silently ignored** — EB hardcodes `per_page: 15` regardless of the parameter (Sx-10, BC-5906). For 500 connected senders that's ~34 pages; for 772 senders it's 52. Pagination is N/15 pages and not operator-configurable. Plan loop iteration counts accordingly.

**Cardinality under multiplicative segmentation.** Post-attach verification (step 7) calls `get_campaign` once per campaign — at up to 9 cells, that's up to 9 calls in the scalar-first happy path. The fallback `sender_verify_mode: "paginated"` runs the full `while True` cursor loop per campaign, so worst case at 772 senders × 9 campaigns = 9 × 52 = ~468 paginated requests. Always exhaust scalar-first first; surface the failing campaign ID before paginating to keep the diagnostic scoped.

Workspaces can have 500+ connected senders. `list_sender_emails` is cursor-paginated. The `while True` / cursor-loop pattern from Revgrowth 10:

```
senders = []
cursor = None
while True:
    response = list_sender_emails(cursor=cursor, filter={"status": "connected", "tag_ids": [identity_tag_id]})  # filter is mode-dependent — see step 2 (identity: tag_ids=[identity_tag_id]; all: status only; esp/both: per-cell ESP filter)
    senders.extend(response.data)
    cursor = response.next_cursor
    if not cursor:
        break
```

Pagination applies at two points: (a) enumerating senders before attach — once for the uniform modes, once **per cell** for the per-bucket modes (each cell runs its own filtered loop) — and (b) re-querying post-attach for verification. Both loops must exhaust the cursor — never truncate after the first page.

### Steps

1. **Ground-truth the tool names.** `search_api_spec` with queries `list sender emails`, `attach sender emails`. Per `email-bison.md` § Common workflows the names are `list_sender_emails` (GET) and `attach_sender_emails_to_campaign` (POST `/api/campaigns/{id}/attach-sender-emails`). Request body: `{"sender_email_ids": [1, 2, 3]}`.
2. **Enumerate this run's connected senders.** Page `list_sender_emails`, fail-closed. How many pools, and what filter each uses, depends on `sender_match_mode`: the **uniform** modes (`identity`, `all`) enumerate **one** pool attached to every campaign; the **per-bucket** modes (`esp`, `both`) enumerate **one pool per campaign cell**, each with that cell's ESP filter.

   **Uniform modes (`identity` / `all`):**
   a. **`identity` mode — resolve + hard-guard the identity tag id (fail closed).** Reuse the per-workspace `identity_tag_id` already resolved before any campaign was created (Phase 1 step 10 / the Phase 5 identity pre-check, BC-13863) — on a resume, read it from the metadata breadcrumb; never re-resolve or hardcode it. **Assert it is a resolved positive integer.** If it is null/unresolved (e.g. corrupt or hand-edited metadata), re-run the Phase 5 pre-check; if it is *still* unresolved, **HALT — never call `list_sender_emails` with an empty or missing `tag_ids[]`**, because an empty tag filter returns the full workspace pool and would silently attach off-identity senders. *(`all` mode needs no tag id — it deliberately wants the full pool — so it skips this sub-step.)*
   b. **Enumerate.**
      - **`identity`:** run the `while True` loop against `list_sender_emails` with filter `?status=connected` (lowercase) **plus `tag_ids[]=<identity_tag_id>`**; ground-truth the exact tag-filter param shape via `search_api_spec` once. EB's status filter is case-sensitive: `?status=Connected` returns 422 (Sx-11, BC-5906) — always pass the lowercase form. Exhaust the cursor; record the full list.
      - **`all`:** run the same loop with `?status=connected` (lowercase) **only — no tag filter**, returning every connected sender in the workspace. The off-identity senders this includes are intentional (the redirect-*unsafe* legacy pool the operator opted into at the mode prompt), not a fail-open. Exhaust the cursor.
   c. **Verify the filter actually applied (don't trust it) — `identity` mode only.** Each returned sender carries a `tags[]` array — confirm every one includes `identity_tag_id`. If any returned sender lacks it, the server-side `tag_ids[]` filter was silently ignored (Sx-5 — EB accepts and no-ops unsupported params), so the list is the full unfiltered pool; **HALT** rather than attach. This is what makes the identity filter *verified*, not merely *trusted* — step 7's count check is self-referential (it compares the attach against this enumeration) and cannot catch this fail-open on its own. **`all` skips this cross-check:** it asserts no tag membership (the full connected pool *is* the intended result), so step 7's count check alone verifies the attach.
   d. **Zero-pool HALT.** If the enumerated pool is empty, **HALT** — surface the mode + workspace; no campaign can send without a sender, and silently proceeding would create campaigns that queue forever. For `identity` this means zero senders carry the identity tag (stricter than the old global zero-sender check: a workspace with hundreds of connected senders can still have zero for *this* identity); for `all` it means zero connected senders at all.

   **Per-bucket modes (`esp` / `both`):**
   e. **Resolve the ESP tag ids (fail closed).** `esp`/`both` match on recipient ESP, so resolve the workspace's `Google` and `Outlook` tag ids — **EB names Microsoft "Outlook"** — the same way the Phase 5 pre-check resolved the identity tag: `search_api_spec` + `call_api` to list the workspace tags once, match the labels `Google` / `Outlook`. Per-instance, never hardcode (commercial and personal differ). **HALT if either is absent** — ESP matching is impossible without them. For `both`, also **resolve + hard-guard `identity_tag_id` here** — the Per-bucket branch does **not** execute sub-step (a), so (a)'s positive-integer assertion must run at this entry point, not be assumed: **assert `identity_tag_id` is a resolved positive integer**; if null/unresolved (corrupt or hand-edited metadata, or a Phase 5 failure), re-run the Phase 5 pre-check; if *still* unresolved, **HALT — never build a `tag_ids=[identity, <esp>]` filter with a null or missing identity id**, because EB silently dropping the null entry would return the full ESP-matched pool with no identity scoping (the exact fail-open this change prevents, and which 2h's membership check can't cleanly catch when the id it checks against is itself null). On a **resume**, reuse `esp_tag_ids` from the metadata breadcrumb if present; if absent (a crash before step 8 persisted them), just re-resolve here — resolution is deterministic and side-effect-free.
   f. **Build each cell's filter (three-way Google / Microsoft / SMTP).** Each `campaign_ids` key is `{email_type}|{esp}` with esp ∈ {`Google`, `Microsoft`, `Other`}. Map the cell's esp component to a `list_sender_emails` filter (all also pass `?status=connected` lowercase; multiple `tag_ids` = **AND/intersection**, verified):

      | Cell ESP | `esp` filter | `both` filter (identity ∩ ESP) |
      |---|---|---|
      | `Google` | `tag_ids=[Google]` | `tag_ids=[identity, Google]` |
      | `Microsoft` | `tag_ids=[Outlook]` | `tag_ids=[identity, Outlook]` |
      | `Other` (SMTP) | `excluded_tag_ids=[Google, Outlook]` | `tag_ids=[identity]` + `excluded_tag_ids=[Google, Outlook]` |

      `Other` = any ESP that is neither Google nor Microsoft, expressed as the exclusion of both — so an **untagged** sender (no ESP tag at all) also falls into the `Other` cell by construction. Ground-truth the exact `tag_ids[]` / `excluded_tag_ids[]` param shapes via `search_api_spec` once. **If `excluded_tag_ids` is unsupported** (the `Other` cell depends on it), **HALT** — do not fall back to an unfiltered `status=connected` query, which would silently attach Google/Outlook senders to the SMTP cell.
   g. **Enumerate per cell.** For each cell in `campaign_ids`, run the `while True` loop with *that cell's* filter from (f). Exhaust the cursor; record the cell's list keyed by the cell. **Dedupe by filter:** cells that share an identical filter (e.g. `professional|Google` and `role|Google` both query `tag_ids=[Google]`) enumerate the same pool — run the paginated loop once per distinct filter and reuse the result across those cells, rather than re-paging at 52-pages-per-pool.
   h. **Verify the filter applied, per cell (don't trust it — Sx-5).** Inspect each returned sender's `tags[]`:
      - **`Google` / `Microsoft` cells:** every sender must carry the expected positive tag — `esp`: the ESP tag; `both`: the identity tag **and** the ESP tag. Any miss means the `tag_ids[]` filter was silently ignored → **HALT**.
      - **`Other` (SMTP) cells:** every sender must carry **neither** `Google` nor `Outlook` (this verifies `excluded_tag_ids` applied — a *negative* check, load-bearing precisely because EB no-ops unsupported params, so a silently-ignored exclusion would return Google/Outlook senders); for `both`, every sender must **also** carry the identity tag. Any violation → **HALT**.
   i. **Empty-cell handling (never silent — surfaced + confirmed at User gate 7).** If a cell's pool from (g) is empty:
      - **`both` mode → fall back to identity-only for that cell.** Re-enumerate that cell with `tag_ids=[identity_tag_id]` alone (drop the ESP filter), **verify the fallback pool the same way:** every returned sender's `tags[]` must include `identity_tag_id`, else the `tag_ids[]` filter silently no-oped (Sx-5) → **HALT**. (2c's "`identity` mode only" header scopes the *uniform* branch; this tag-membership check applies to any `tag_ids=[identity_tag_id]` query, so it is mandatory here in the `both` fallback too.) Then **make that identity pool the cell's recorded pool — it *replaces* the empty (g) entry, so every downstream reference to "that cell's pool" (steps 6, 7, 8) resolves to the fallback list and its count, not the empty ESP-filtered one.** Redirect-safe, and it keeps the cell's already-attached leads moving rather than stranding them. Record the cell in `sender_match_fallbacks` (step 8). Never applied silently: it is shown and confirmed at gate 7.
      - **`esp` mode → no fallback** (esp is not identity-scoped, so there is no brand pool to fall back to). Record the cell in `sender_unsent_cells` (step 8); surface it at gate 7, where the operator either aborts (to fix sender coverage / switch modes) or proceeds leaving that cell sender-less — it will not send until senders are attached out-of-band.
      - **If a `both` cell's identity fallback pool is *also* empty,** treat it as the `esp` case (no senders at all → `sender_unsent_cells`, surfaced at gate 7).
      - **Whole-launch floor.** If *every* per-bucket cell ends up empty (all land in `sender_unsent_cells`, none has senders even after the `both` fallback), **HALT** — the per-bucket analogue of the uniform zero-pool HALT (2d); a 100%-unsent launch would create only campaigns that queue forever, so it never reaches gate 7 as a "proceed" option.

      > ⚠️ **Provisional (BC-13864).** The `both`→identity fallback is flagged provisional. Small / ESP-lopsided brands trigger empty `both` cells often — e.g. Nites inboxes cluster in *different* ESPs per instance (commercial Google + SMTP, personal Outlook) — so a Nites `both` launch hits empty cells frequently and quietly degrades toward identity-mode coverage. If that causes operator confusion or cross-ESP deliverability issues from the fallen-back cells, revisit. Alternatives parked: drop the cell, hard-HALT the launch, or a smarter per-cell fallback.
3. **With `--reference <campaign-id>` set:** call the reference campaign's `get_campaign` (or equivalent sender-list endpoint) to fetch its attached sender IDs. Pre-fill the gate to show "reference campaign had these senders attached — this run attaches its own sender pool per `sender_match_mode` (step 2), which may differ." The invariant still applies — we still attach ALL of this run's enumerated senders (step 2), not just the reference's subset. `--reference` pre-fills the display, not the attach payload.
4. **Render the attach plan.** The shape depends on `sender_match_mode`.

   **Uniform (`identity` / `all`)** — one pool, same count to every campaign:

   > Sender pool for workspace `{workspace}`: {N-senders} connected senders — `sender_match_mode={sender_match_mode}` (`identity` → carrying the `{sending_identity}` tag; `all` → every connected sender, no filter).
   >
   > Attach plan (per-campaign count must match — same pool to every campaign):
   > - `{campaign_ids["professional|Google"]}` ← {N-senders} senders
   > - `{campaign_ids["professional|Microsoft"]}` ← {N-senders} senders
   > - `{campaign_ids["professional|Other"]}` ← {N-senders} senders
   > - `{campaign_ids["role|Google"]}` ← {N-senders} senders
   >
   > Sender list preview (first 5): sender@brite.co, ops@brite.co, intro@brite.co, …

   **Per-bucket (`esp` / `both`)** — a different pool per cell; counts legitimately differ:

   > Sender pools for workspace `{workspace}` — `sender_match_mode={sender_match_mode}`, three-way ESP match (`both` also ∩ `{sending_identity}`):
   > - `{campaign_ids["professional|Google"]}` (Google) ← {N_google} senders
   > - `{campaign_ids["professional|Microsoft"]}` (Outlook) ← {N_microsoft} senders
   > - `{campaign_ids["professional|Other"]}` (SMTP, excl. Google/Outlook) ← {N_other} senders
   > - `{campaign_ids["role|Google"]}` (Google) ← {N_google} senders
   >
   > Per-cell counts differ by design. Sender preview per cell (first 3 each): …
5. **User gate 7.** Ask via `AskUserQuestion` — the prompt depends on `sender_match_mode`.

   **Uniform (`identity` / `all`):**

   > Attach ALL {N-senders} senders (`sender_match_mode={sender_match_mode}`) to ALL {N-campaigns} campaigns? Every campaign gets the same pool — splitting it across campaigns is forbidden. Proceed?
   > *(For `all`: ⚠️ this attaches every connected sender, off-brand ones included — redirect-UNSAFE; you selected this at the mode prompt.)*
   >
   > - Yes, attach the full pool to every campaign (Recommended)
   > - Abort

   **Per-bucket (`esp` / `both`):**

   > Attach each cell's ESP-matched pool to its campaign (`sender_match_mode={sender_match_mode}`, counts above)? Each campaign gets only the senders on its recipients' ESP — *for `both`, each pool is also ∩ the `{sending_identity}` identity (ESP **and** brand); for `esp`, ESP only — NOT identity-scoped, so off-brand senders can attach*. Per-cell counts differ by design. Proceed?
   >
   > *(If step 2i found cells with no ESP-matched senders, list each with its resolution — never silent:)*
   > ⚠️ Cells with no ESP-matched senders (resolved per step 2i):
   > - `{cell}` — **fell back to identity-only ({M} `{sending_identity}` senders)** ✅ redirect-safe, WILL send (`both` mode)
   > - `{cell}` — **NO senders at all — will NOT send** (empty `esp` cell, or a `both` cell whose identity fallback was also empty) unless you abort and fix coverage (or attach manually later)
   >
   > - Yes — attach each cell's matched pool *(and, for any cells listed above: apply the `both` identity fallback, and leave the no-sender cells unsent)* (Recommended)
   > - Abort
6. **Execute attach per campaign.** For each campaign ID in `campaign_ids`, call `attach_sender_emails_to_campaign`:
   - **Uniform (`identity` / `all`):** `{"sender_email_ids": [<all enumerated sender IDs from step 2>]}` — the same pool for every campaign.
   - **Per-bucket (`esp` / `both`):** `{"sender_email_ids": [<that cell's effective pool — step 2g, or its 2i identity fallback>]}` — each campaign gets its own cell's matched set, so the payload differs per campaign. **Skip cells recorded in `sender_unsent_cells`** — make no attach call for them (they are intentionally sender-less per the gate-7 confirmation; attaching an empty list is undefined).
   - If the vendor returns a confirmation-gated response (unlikely for sender attach, but verify), follow the two-call pattern.
   - **Resume note:** a resumed run re-runs Phase 7 from step 1 and re-attaches every campaign. If `attach_sender_emails_to_campaign` is append-style, an already-attached campaign then shows duplicate senders — surfaced as "extra" at step 7 → HALT for manual reconciliation, not a silent double-send. Verify replace-vs-append semantics via `search_api_spec` and prefer a replace call if EB offers one.
7. **Post-attach verification (count-scalar first; fetch + classify on mismatch).** The invariant enforcement step. **First, for any per-bucket cell in `sender_unsent_cells`:** step 6 attached nothing, so the expected count is **0** — a *fresh* campaign verifies trivially (0 == 0, no fetch). But a *reused* campaign (Phase 5 reuse branch) may still carry N pre-existing senders, so the cell the operator confirmed sender-less at gate 7 would in fact send — **HALT** with the specific message "cell `{cell}`'s reused campaign carries N leftover senders but was confirmed sender-less — detach via EB UI or abort", **not** the generic missing/extra classifier below. Never silently skip a reused unsent cell. Then, for each remaining campaign ID:
   - **Scalar check first** — call `get_campaign` and read the `attached_senders_count` (or equivalent count field returned without paginating). Compare to the campaign's step-2 enumerated count — for uniform modes that's the single pool count; for per-bucket modes it's *that cell's* effective enumerated count (step 2g, or the 2i fallback count for cells in `sender_match_fallbacks`). **In `identity` mode a match verifies identity-membership by construction:** step 6 attaches exactly step 2's list and step 2c already confirmed every id in it carries the identity tag; a fresh campaign starts empty, and any off-identity sender lingering on a *reused* campaign would push the count *above* N into the mismatch path below — so on either path equal counts mean the attached set *is* the identity set, no off-identity sender possible. **In `all` mode** equal counts simply confirm the attach landed — there is no membership to verify (the operator opted into the full pool), so the scalar check is the whole verification. **In the per-bucket modes (`esp` / `both`)** the same scalar check runs per cell, comparing each campaign's count to *that cell's* step-2g count (counts differ across cells — there is no cross-cell equality to assert); per-cell membership is already guaranteed by the 2h verify (`both` = identity ∩ ESP — or identity-only for a cell that fell back per 2i; `esp` = ESP only, no identity guarantee), so the scalar count confirms the attach landed. **(Why count-only suffices for `esp`, mirroring `identity`: 2h verified every enumerated sender matches the cell's ESP filter *before* attach, step 6 attaches exactly that set onto an empty campaign, so an equal count means the attached set *is* the ESP-verified set; an off-ESP leftover on a reused campaign pushes the count past N into the mismatch path.)** This is the 99% path: 1 MCP call per campaign, no pagination, no per-id fetch.
   - **On count mismatch (or absent scalar) — fetch the full attached set, classify, then HALT.** Re-query the campaign's full attached-sender list (`get_campaign` + the `while True` loop) and diff it against the campaign's step-2 enumerated list (the single pool for uniform modes; *that cell's* effective list for per-bucket modes — step 2g, or its 2i fallback for cells in `sender_match_fallbacks`). Classify the diff *before* halting:
     - **Extra senders not in the step-2 list.** In `identity` mode these are **off-identity** — almost always a *reused* pre-BC-13864 campaign (Phase 5's "Reuse existing IDs" branch) still carrying full-pool senders, which Phase 5 step 9b's tag-only check doesn't catch and an *append*-style attach leaves in place; they violate the identity invariant. In `esp` / `both` they are **off-cell** — a sender that doesn't match this cell's ESP filter (and, for `both`, may also be off-identity); **for a cell that fell back to identity-only per 2i the cell is identity-scoped (no ESP filter), so an extra there is *off-identity*, not off-ESP — label it as a reused-campaign identity leak, not a phantom ESP mismatch.** Same reused-campaign cause, same fix. (In `all` mode there is no off-identity class — every connected sender is in-pool by definition — so an "extra" can only be a sender pre-attached on a *reused* campaign that is no longer in the connected enumeration; HALT to surface the discrepancy.)
     - **Missing step-2 senders** = a vendor-side silent drop at high pool sizes (all modes).
     **HALT** and surface the campaign id with the specific extra (off-identity / off-cell) and missing sender ids + the classification; do not advance `last_completed_phase`. (This is where the off-identity / off-cell protection actually executes: a *replace*-style attach yields exactly the matched set and passes at the scalar step, while an *append* surfaces the leftovers here as extras — correct either way.)
   - **Ground-truth fallback** — if `get_campaign`'s schema doesn't expose a scalar count field this session (verify via `search_api_spec` once up-front), fall back to pagination-first on every campaign (fetch + classify as above). Record the chosen verification mode in metadata: `sender_verify_mode: "scalar" | "paginated"`.
8. **Append to metadata JSON.** `sender_attach_counts: {"professional|Google": N, ...}` — one entry per cell in `campaign_ids`. The shape of `sender_ids_attached` and the count invariant depend on the mode:
   - **Uniform (`identity`, `all`):** `sender_ids_attached: [<full enumerated list from step 2>]` (one flat list). All `sender_attach_counts` values MUST be equal — every campaign gets the same pool.
   - **Per-bucket (`esp`, `both`):** `sender_ids_attached: {"professional|Google": [<that cell's IDs>], ...}` (a per-cell map — the sets differ by cell). `sender_attach_counts` values legitimately differ across cells; equality is **not** asserted. Also record `esp_tag_ids: {"Google": <id>, "Outlook": <id>}` (resolved in step 2e) so a resumed run reuses them instead of re-resolving. Plus the empty-cell outcomes from step 2i: `sender_match_fallbacks: [<cell>, ...]` (the `both` cells that fell back to identity-only) and `sender_unsent_cells: [<cell>, ...]` (empty `esp` cells — and `both` cells whose identity fallback was also empty — left sender-less per the gate-7 confirmation); both default to `[]`.

   `last_completed_phase: 7`.

### Forbidden patterns (hard failures)

- Rationing a single pool across campaigns to concentrate volume (e.g. a uniform mode's pool, or one per-bucket cell's pool, sliced senders 1–10 / 11–20 across campaigns). Explicit anti-pattern — never shipped, never offered as an option. (Per-bucket modes giving *different* cells *different* full pools is not this — each cell still gets its whole matched pool.)
- **In `identity` mode**, attaching a sender that does not carry the run's identity tag. Step 2 filters to the identity and step 2c verifies it; the pool must never be widened back to the full workspace. *(In `all` mode this is not a violation — the full connected pool, off-identity senders included, is the explicit, operator-selected, redirect-unsafe result.)*
- **In per-bucket modes**, attaching a sender to a cell whose ESP it doesn't match — a `Google`/`Outlook`-tagged sender on the `Other` (SMTP) cell, or the wrong ESP tag on a Google/Microsoft cell. The per-cell filter (step 2f) + the 2h verify prevent it; a mismatched-ESP sender degrades deliverability. For `both`, additionally attaching a sender outside the cell's identity ∩ ESP set. **Exception — the step 2i `both` fallback:** when an empty `both` cell falls back to identity-only (recorded in `sender_match_fallbacks`), that cell's effective pool is identity-scoped, *not* ESP-scoped — so an ESP mismatch inside a fallen-back cell (e.g. a `Google`/`Outlook`-tagged sender on a fallen-back SMTP cell) is the authorized, gate-7-confirmed outcome, **not** a violation; the rule above applies only to cells still on their step-2f ESP filter.
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

   > Schedule template selected: `{template-name}` (ID {schedule_template_id})
   > - Monday–Friday
   > - 08:00–17:00 (local timezone: {tz})
   > - Applies to all {N} campaigns.
4. **User gate 8.** Ask via `AskUserQuestion`:

   > Apply schedule `{template-name}` to all {N} campaigns? (All campaigns share the same schedule — per-campaign schedule override not supported in this command.)
   >
   > - Yes, apply (Recommended)
   > - Pick a different template — I'll show the full list
   > - Abort
5. **Execute apply per campaign.** For each campaign ID, call `create_schedule_from_template` with `{"schedule_id": N}` (the request-body field name is EB's parameter; do not confuse with the metadata field name in step 7). Capture each call's response — each apply returns a NEW cloned schedule entity (not a reference to the template), so record the cloned schedule ID per call into a scratch `campaign_schedule_ids` map keyed by bucket for the metadata write at step 7.
6. **Verify per campaign.** Re-read the campaign via `get_campaign` and confirm the schedule is attached. Halt on first mismatch.
7. **Append to metadata JSON.** Set `schedule_template_id: N` (the source template ID — same value the operator picked in step 4; renamed from the prior `schedule_id` field). For each campaign in `campaign_ids`, write `campaign_schedule_ids: {<bucket>: <cloned_id>, ...}` from the scratch map captured in step 5 — round-2 of BC-5906 confirmed each apply creates a new schedule entity, so per-campaign IDs are required to re-locate the schedule for resume / debug. Set `last_completed_phase: 8`.

**If Phase 8 fails mid-loop:** partial schedule application. Metadata records `last_completed_phase: 7` and `campaign_schedule_ids` reflects whichever campaigns received clones before the failure. Operator inspects the unscheduled campaigns via EB UI and re-runs Phase 8 scoped to those.

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
   - All `{TOKEN}` references in step_1.subject, step_1.body, step_2.subject, step_2.body MUST be UPPERCASE. Grep all `\{[A-Za-z_]+\}` matches; HARD FAIL if any match contains lowercase characters (i.e., `[a-z]`). Error message: "Artifact contains lowercase or mixed-case token `{X}` — EB's render engine only resolves UPPERCASE tokens; lowercase tokens render as literal text in delivery (verified BC-6308 round-3 R-2a). Update the artifact to use UPPERCASE: `{X.upper()}`."
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
8. **Append to metadata JSON.** Set `sequence_ids: {"professional|Google": 8801, "professional|Microsoft": 8802, "professional|Other": 8803, "role|Google": 8804}` (one entry per cell in `campaign_ids`; example shows 4-cell from gate-2 `include_role`), `last_completed_phase: 9`.

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

1. **Pick a preview lead.** Prefer the first lead in the largest cell of the `segments` map (most leads → most representative). Ties broken by the cell's display order in the gate-2 grid (`professional|Google` → `professional|Microsoft` → `professional|Other` → `role|Google` → ...). Fall back to row 2 of the CSV if `segments` is empty (`--no-host-lookup` path). Read the lead's CSV row.
2. **Build the variable values map.** For each `{VARIABLE}` extracted from step_1/step_2 subject+body:
   - EB-standard variables (`FIRST_NAME`, `LAST_NAME`, `COMPANY`) resolve from the lead's CSV fields (`first_name`, `last_name`, `company_name`).
   - All other variables resolve from `custom_variables[].default` in the copy artifact.
   - `{SENDER_*}` variables resolve per Phase 1 step 7 priority chain. **Caveat (BC-6784):** the resolved value is for *display only* in this local spot-check. EB's render engine shadows the priority chain at delivery and pulls `{SENDER_*}` from the actual sender record being used at the moment of send. Under sender rotation, recipients see different `{SENDER_*}` values across deliveries — not the value rendered here. See `email-bison.md` § Known gotchas § `{SENDER_*}` render-time resolution shadows artifact.
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

   > **Preview — campaign `{campaign-name} | Professional | Google`, lead `alex@denvergov.org`:**
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

Additive to Mode 1 — Mode 1 always runs first. Mode 2 only fires if `--test-send <email>` was passed AND Mode 1 passed all sanity checks AND the `--test-send` value passed Input validation § IV-5 (email-format regex). Any IV-5 failure skips Mode 2 with an informative message — does NOT error the whole Phase 10.

**Preconditions:** Phases 4–9 completed (sequence step exists in EB, lead attached to campaign). If any precondition fails, skip Mode 2 with an informative message — do NOT error the whole Phase 10.

**Steps:**

1. **Ground-truth the endpoint.** `search_api_spec` for `POST /api/campaigns/sequence-steps/{sequence_step_id}/test-email` — confirm path + required body fields (`sender_email_id`, `to_email`). Build the `call_api` body via **structured JSON construction** per IV-5 (never string concatenation of the email value).
2. **Pick a sender.** Default to the first attached sender from Phase 7. Operator can override with `--test-send-sender <id>` if they want a specific mailbox to send from.
3. **Safety surface to operator** — this mode SENDS A REAL EMAIL. Before the call, make the blast radius explicit:

   > **Mode 2 — real test-send.** This will deliver a real email to `{--test-send email}` via sender `{sender_id}`, using sequence step `{step_1_id}` from campaign `{campaign_name | Professional | Google}`. The email counts toward sender reputation and daily limits. No lead is contacted.
4. **User gate 10b** (real-send confirm):

   > Send real test email to `{test-send email}`?
   >
   > - Yes, send test to my inbox
   > - Skip test-send (Mode 1 local render is already complete)
5. **Execute test-send.** Call `call_api` with `POST /api/campaigns/sequence-steps/{step_1_id}/test-email` and body `{"sender_email_id": N, "to_email": "<test-send email>", "use_dedicated_ips": false}`. Record the response.
6. **Append to metadata JSON.** Extend `preview_method` to `"local-render + test-send"`, add `test_send_recipient: "<email>"`, `test_send_at: "<ISO-8601>"`.
7. **Prompt operator to check inbox.** Ask them to visually confirm the email rendered correctly in a real mail client (plus or beyond what local render showed). **Two operator-facing notes** (BC-7598, BC-6785 R-21★):
   * Subject will carry `[test] ` prefix — e.g., authored `"Quick idea"` arrives as `"[test] Quick idea"`. EB-side test-distinction marker; real-campaign sends do not carry this prefix (see `email-bison.md` § Known gotchas).
   * Mode 2's test-send may use a different lead's data than Mode 1's local render showed. EB's `test-email` endpoint does NOT expose which lead is picked — operators should validate render STRUCTURE (variable substitution, spintax, line breaks) rather than expecting specific lead values to match Mode 1's preview.

### User gate 10 (single gate, both modes)

After Mode 1 completes (and optionally Mode 2):

> Preview rendered above (local + optional real test-send). Everything look right? This is the last chance to catch render issues before activation.
>
> - Yes, preview looks clean
> - Problem — I'll describe it and abort

### Behavior when `--activate` is NOT set

After Phase 10 completes, surface the final summary message and exit:

> Launch flow complete at Phase 10. Campaigns created in `Draft` state:
> - `{campaign_ids["professional|Google"]}` — 84 leads, 2-step sequence, ready to activate
> - `{campaign_ids["professional|Microsoft"]}` — 31 leads, 2-step sequence, ready to activate
> - `{campaign_ids["professional|Other"]}` — 12 leads, 2-step sequence, ready to activate
> - `{campaign_ids["role|Google"]}` — 3 leads, 2-step sequence, ready to activate
>
> Metadata: `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json`
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
2. **Agent-side per-campaign turn-structure gate** (Sx-9, BC-5906; turn-structure per BC-2707). Per § Tool tier map, `resume_campaign` is invoked via `call_api` against `PATCH /api/campaigns/{id}/resume`, which has NO `confirmation` field at the API level. The "second gate" is the operator's affirmative turn that must precede the single real `call_api` against the resume endpoint. The per-campaign description the operator sees comes from the wrapper-tool's `discover_tools` prose (relayed verbatim) — not from a preliminary API call, because `PATCH /api/campaigns/{id}/resume` has no dry-run and no `confirmation` parameter, so the one request fires the resume immediately.

The two gates are layered — the operator says "yes" twice per campaign, in two different contexts, with both prompts rendered separately. The anti-pattern this layering blocks: the skill issuing both the intent gate and the per-campaign resume `call_api` in the same turn without real user turns between them. Per `docs/precedents/BC-2707.md` the guarantee being enforced is turn structure, not vocabulary — accept any clear affirmative ("yes", "approved", "go ahead", "proceed", "do it"); ambiguous or silent responses still halt.

### Steps

1. **Ground-truth the tool name.** `search_api_spec` with query `resume campaign`. Per `email-bison.md` § Common workflows the name is `resume_campaign` with path `PATCH /api/campaigns/{id}/resume`.
2. **Final summary to operator** (pre-first-gate):

   > Phase 11 ACTIVATE — this will transition {N} campaigns from `Draft` to `Queued` and begin sending real emails. Summary:
   > - `{campaign_ids["professional|Google"]}` — 84 leads, step 1 sends on the campaign's next scheduled window
   > - `{campaign_ids["professional|Microsoft"]}` — 31 leads, same
   > - `{campaign_ids["professional|Other"]}` — 12 leads, same
   > - `{campaign_ids["role|Google"]}` — 3 leads, same
   >
   > Sender pool: {N-senders} inboxes per campaign.
   > Schedule: Mon–Fri 08:00–17:00 {tz}.
   >
   > Metadata will update `activated_per_campaign[<bucket>]` per campaign as each resume call succeeds. Global `activated: true` flips only when every campaign activates; partial success leaves it `false` with per-campaign timestamps recording exactly which ones ran.
3. **User gate 11a — operator intent.** Ask via `AskUserQuestion`:

   > Activate all {N} campaigns now? Each campaign gates separately too.
   >
   > - Yes, proceed to the per-campaign gates
   > - Abort
4. **Per-campaign turn-structure gate loop.** For each campaign in the bucket map:
   - **Compose the per-campaign resume prompt** (no API call). The operator-facing description comes from the wrapper-tool's `discover_tools` prose, which describes the resume-campaign action (typically: "This will transition campaign {id} from Draft to Queued and begin sending emails."). Per Sx-9 `PATCH /api/campaigns/{id}/resume` has no dry-run and no `confirmation` parameter — the actual resume fires once, in the bullet below, after the operator's turn. Render that description verbatim in the gate to preserve BC-2707 turn structure.
   - **User gate 11b — vendor confirmation.** Relay the vendor prompt verbatim via `AskUserQuestion`:

     > Vendor prompt for campaign `{campaign-name} | Professional | Google`: "{vendor-prompt-text}"
     >
     > - Yes, activate this campaign
     > - Abort the entire Phase 11 (already-activated campaigns stay activated)
   - On operator affirmative, fire the single `call_api` request against the resume endpoint (no `confirmation` field — see § Tool tier map). Record the returned campaign state (should be `Queued`).
   - **Per-iteration metadata write.** Immediately after the resume `call_api` returns success, set `activated_per_campaign[<bucket>] = "<ISO-8601-of-the-resume-call-response>"` in the metadata JSON. This is the resume primitive: if Phase 11 fails or aborts mid-loop, the metadata authoritatively records exactly which campaigns activated. The global `activated: true` does NOT flip yet — that's step 6's finalization, gated on every bucket key being non-null.
   - On operator abort, HALT the loop — do not continue to other campaigns. Already-activated campaigns in this loop remain activated and their `activated_per_campaign[<bucket>]` timestamps remain authoritative.
5. **Post-activate verification.** For each activated campaign, call `get_campaign_stats` (or equivalent) and confirm the campaign activated successfully. **Pass state is `Queued` OR `Active`** — EB's state machine progresses `draft → queued → launching → active` over a few seconds after `resume_campaign`, so a `get_campaign` call within ~5s may return `Active` instead of `Queued`. Both indicate successful activation (BC-6785 round-5 R-23★ — see `email-bison.md` § Known gotchas). Capture the initial counters for the final report.
6. **Finalize metadata JSON.** Confirm every entry in `activated_per_campaign` is non-null. Set `activated: true` only when that holds; otherwise leave `activated: false` (a partial-success state — phase ran, some campaigns activated, the operator aborted before the rest). Set `activated_at: "<ISO-8601-of-final-resume-call>"` (the timestamp of the LAST successful per-iteration call, not a wall-clock now()). Set `last_completed_phase: 11` regardless — `last_completed_phase` tracks "phase ran", not "phase fully succeeded"; partial-success state is encoded in `activated_per_campaign`.
7. **Sync Salesforce Campaign status to "In Progress" (BC-8752, soft-fail).** After `activated: true` is finalized, mirror the new active state into Salesforce via the σ3 trigger per the BC-8752 design (Linear sub-issue 6 close → SF `In Progress`). Only fires when global `activated: true` (every bucket non-null). On partial activation (`activated: false`), the operator will reconcile manually via `/marketing:sync-campaign-status` after fixing the un-activated buckets — Phase 11 is the σ3 author point for `active`, but partial Phase 11 success is an explicitly-deferred state.

   1. **Resolve the GTM slug from the manifest.** `/marketing:plan-campaign` writes manifest at `docs/campaigns/<short-entity>/<slug>/manifest.json` using the SHORT-form entity slug it accepts (`nites` / `supply` / `labs` / `cross-entity`), while launch-campaign's `--entity` flag uses the LONG-form slug (`brite-nites` / `brite-labs`). This mismatch is a known cross-skill asymmetry (campaign-debrief/SKILL.md § Known cross-skill asymmetry). Normalize at read time: derive `<short-entity>` by stripping the `brite-` prefix from `--entity` (`brite-nites` → `nites`, `brite-labs` → `labs`; launch-campaign's `--entity` set does not include `cross-entity`, so this normalization is total). Then try `Read` `docs/campaigns/<short-entity>/<campaign-name>/manifest.json` (where `<campaign-name>` is the `--campaign-name` flag value — by GTM convention from `/marketing:plan-campaign`, this IS the slug). Both path segments are constrained upstream: `<short-entity>` is the mechanically-stripped form of the `--entity` enum (`brite-nites|brite-labs`) so traversal characters are impossible; `<campaign-name>` is regex-gated by Phase 1 IV-8 (`^[A-Za-z0-9][A-Za-z0-9 _.-]{0,79}$` — blocks `..` / `/` / `\` even though it permits spaces and mixed case, which is the source of the casing-mismatch failure-mode the log line below calls out). Strict-kebab is enforced separately on `manifest.slug` at step 2 below, not on `<campaign-name>`. If the manifest file does not exist OR JSON parse fails OR `.slug` is absent, log a single line to stderr — `[BC-8752] No GTM manifest at "docs/campaigns/<short-entity>/<campaign-name>/manifest.json"; skipping σ3 SF sync. If /marketing:plan-campaign was used to scaffold, --campaign-name must equal the strict-kebab slug it produced (no spaces, no mixed case). Otherwise this is a standalone launch — expected.` — and continue to step 8.
   2. **Re-validate the manifest slug** (defense-in-depth against manifest tampering / argument injection). After extracting `<slug>` from `manifest.slug`, check it against the canonical regex `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` (same regex as `/revops:update-sf-campaign-status` Phase 1 and ADR-012 canonicals lint — duplicated locally because the manifest is a file on disk and a poisoned `slug` value with whitespace could otherwise inject an extra `--linear-status` flag into the args string constructed in step 3). Apply the regex without the multiline (`m`) flag — `^` and `$` must match input boundaries, not line boundaries; a manifest slug containing an embedded newline must FAIL the check (not slip past via a per-line match on a first valid-looking line). On regex mismatch, log `[BC-8752] Manifest slug failed canonical regex — refusing σ3 SF sync. Manifest at "docs/campaigns/<short-entity>/<campaign-name>/manifest.json" may be tampered or out-of-date.` (the slug VALUE is intentionally omitted from this log to avoid echoing potentially poisoned content into the agent context) and continue to step 8 without invoking the Skill.
   3. **Invoke the sibling slash command.** Per the BC-8717 / BC-8723 respec pattern (no MCP write tool exists for Campaign — the surface is `/revops:update-sf-campaign-status`):

      ```
      Skill(
        skill: "revops:update-sf-campaign-status",
        args: "--slug=<manifest.slug> --linear-status=active"
      )
      ```

   4. **Parse the single-line JSON response on stdout.** Branch in this exact order — the first matching case wins:
      - **`error: <kind>`** (any payload with an `error` key) → log `[BC-8752] σ3 SF sync soft-fail: <kind>. Detail: <stringified error>. Launch succeeded; SF status is stale until reconciliation.` Continue to step 8.
      - **`{"warning":"campaign_not_found", ...}`** (warning key present AND no `campaign_id`) → log `[BC-8752] SF Campaign for slug "<slug>" not found — σ3 auto-create at /marketing:plan-campaign Step 8b may have failed. Reconcile manually: /revops:create-sf-campaign ... then /marketing:sync-campaign-status --slug=<slug> --status=active.` Continue to step 8.
      - **Success with degradation** (`campaign_id` AND `warning` key both present — typically `warning: "instance_url_unknown"` or `warning: "updated_at_unavailable"` per the underlying command's Phase 7 / Phase 6 fall-through; UPDATE landed but a non-blocking artifact is missing) → log `[BC-8752] SF Campaign synced with degradation: <slug> → In Progress (campaign_id=<id>, warning=<kind>). UPDATE landed; consult /revops:update-sf-campaign-status § Error/warning catalog for the specific impact.` Continue to step 8.
      - **Success or noop** (`campaign_id` present AND no `warning` key — `noop: true` may also be present per the underlying command's Phase 5) → log `[BC-8752] SF Campaign synced: <slug> → In Progress (campaign_id=<id>).` Continue to step 8.
   5. **Soft-fail invariant.** No SF response — success, warning, or error — halts the launch flow. Phase 11 success is owned by EB activation, not by SF mirroring. This matches the soft-fail philosophy in `/marketing:plan-campaign` Step 8b (SF auto-create is soft-fail w.r.t. Linear+manifest writes) and `/revops:update-sf-campaign-status`'s own exit-0-always contract.
8. **Final report to operator:**

   > Launch complete. {N} campaigns activated in workspace `{workspace}`:
   > - `{campaign-name} | Professional | Google` (id {id}) — Queued, 84 leads, first sends next scheduled window
   > - `{campaign-name} | Professional | Microsoft` (id {id}) — Queued, 31 leads, same
   > - `{campaign-name} | Professional | Other` (id {id}) — Queued, 12 leads, same
   > - `{campaign-name} | Role | Google` (id {id}) — Queued, 3 leads, same
   >
   > Metadata written to `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json`.
   >
   > Monitor via `get_campaign_stats` or the Email Bison UI.

### Forbidden patterns in Phase 11 (hard failures)

- Firing the `resume_campaign` `call_api` in the same turn as the operator-intent gate (11a) or the per-campaign prompt (11b), without a real operator turn before it. Defense-in-depth against same-turn auto-confirm per BC-2707 — the gate is operator turn structure, not a vendor `confirmation` parameter (see § Tool tier map).
- Skipping the operator-intent gate (11a) even when "yes" was implicit from the `--activate` flag being passed. The flag authorizes the phase to run; it does not authorize skipping the intent gate.
- Continuing the loop after an operator abort. The phase halts on the first abort — other campaigns wait for a future run.
- Auto-confirming the turn-structure gate because the vendor prompt text is predictable. The gate is the *structure*, not the text.

**If Phase 11 fails mid-loop:** some campaigns are activated, others are still in Draft. Metadata records the state. Operator re-runs with `--activate` and the command picks up at the first un-activated campaign — but note that re-running from scratch still executes Phases 1–10 as no-ops (all state detection-gated); this is intentional and keeps the re-run idempotent.

---

## Error recovery — overview

Each phase documents its own failure mode inline. This section is the meta-view: what state each phase leaves in the EB workspace and in the metadata JSON, and how to resume.

| Phase | EB workspace state if phase fails | Metadata JSON state | Resume strategy |
|---|---|---|---|
| 1 PRE-FLIGHT | Unchanged (read-only) | Partial or missing — only inputs populated | Fix input (CSV / copy artifact / marketing-context), re-run from scratch |
| 2 HOST LOOKUP | Unchanged (read-only) | `segmented`, `segments` populated | Fix failing domain lookup, re-run from scratch |
| 3 VARIABLES | Some variables created, others not | `custom_variables_created` lists succeeded names | Inspect EB UI, delete partials OR delta artifact to skip created names, re-run |
| 4 UPLOAD | Some leads created; already-in-workspace collisions set aside (step 7d), not created | `lead_ids_uploaded` = total created; `workspace_collisions_skipped` = collisions set aside | Collisions auto-handled in-flow (gate 4b). For a genuine failure: inspect EB UI → delete partials + re-upload OR delta CSV + re-run |
| 5 CAMPAIGN CREATE | Some campaigns exist, others don't | `campaign_ids` map populated with succeeded buckets | Delete partial campaigns OR manually create missing ones and patch metadata, re-run |
| 6 ATTACH LEADS | Some campaigns have leads attached | Nothing phase-6-specific in metadata — `last_completed_phase` is the check | Re-run scoped to unattached campaigns |
| 7 ATTACH SENDERS | Count mismatch on one or more campaigns (invariant violation) | `sender_ids_attached`, `sender_attach_counts` | Manual attach via EB UI + re-run from Phase 8, OR HALT and surface to operator |
| 8 SCHEDULE | Some campaigns have schedules, others don't | `schedule_template_id` set if Phase 8 ran at all; `campaign_schedule_ids` reflects whichever campaigns received clones before the failure | Re-run scoped to unscheduled campaigns (those missing from `campaign_schedule_ids`) |
| 9 SEQUENCE | Some campaigns have sequences, others don't | `sequence_ids` populated with succeeded buckets | Delete partial sequences OR manually patch missing ones, re-run scoped |
| 10 PREVIEW | Unchanged (read-only) | `preview_rendered_at` set if rendered | Skip preview and proceed, OR investigate render tool error |
| 11 ACTIVATE | Some campaigns Queued, others still Draft | `activated_per_campaign` records per-bucket ISO-8601 timestamps for activated campaigns (still `null` for un-activated); `activated: true` only when every entry is non-null | Re-run with `--activate`; Phases 1–10 re-execute as no-ops; Phase 11 reads `activated_per_campaign` and picks up at the first bucket whose value is still `null` |

### General resume rules

- **Re-running the command is idempotent through Phase 10.** Phases 1–3 are read-only / detection-gated. Phases 4–6 do create state but re-running will either collide with existing IDs (prompting a gate to skip) or simply re-execute (in which case the operator declines at the gate). The command does not auto-skip previously-created state — operators are expected to read `last_completed_phase` in the metadata and decide manually whether to patch inputs, abort, or proceed.
- **Never re-activate a Queued campaign.** Phase 11 is NOT idempotent; calling `resume_campaign` on an already-Queued campaign may no-op or error depending on the vendor's current version. The command's Phase 11 loop skips campaigns whose metadata shows they're already activated.
- **Metadata JSON is authoritative for resume.** If the metadata file is missing after a failure, treat the entire run as lost and restart from Phase 1. The JSON is written progressively — any phase that completed should have left a trace.
- **When in doubt, inspect the EB UI.** Campaigns, sequences, leads, and senders are all visible in the workspace. The EB UI is the ground truth if the metadata JSON ever disagrees with vendor state.

---

## Verification checklist

Before marking this command shipped, confirm:

- [ ] File exists at `plugins/marketing/commands/launch-campaign.md` with valid frontmatter (description, argument-hint, allowed-tools).
- [ ] `allowed-tools` includes `mcp__emailbison-b2b__*`, `mcp__emailbison-personal__*`, `mcp__plugin_marketing_salesforce__*`, Read, Write, Glob, Grep, Bash, AskUserQuestion, Skill. `Skill` powers the BC-8752 σ3 SF sync to `/revops:update-sf-campaign-status` after Phase 11 ACTIVATE succeeds.
- [ ] All 11 phases named and ordered correctly (PRE-FLIGHT / HOST LOOKUP / VARIABLES / UPLOAD / CAMPAIGN CREATE / ATTACH LEADS / ATTACH SENDERS / SCHEDULE / SEQUENCE / PREVIEW / ACTIVATE).
- [ ] Every mutating phase (3/4/5/6/7/8/9/11) has an explicit semantic "USER CONFIRM" gate, and Phase 10 Mode 2 (`--test-send`) has its own intent gate (10b) before the real test-send.
- [ ] Phases 4 and 6 use **one semantic gate + minimal per-chunk/per-campaign turn-structure prompts** rather than re-prompting semantic approval per loop iteration (BC-2707 turn-structure preserved without gate fatigue).
- [ ] Phase 7 ATTACH SENDERS resolves an operator-selected sender-match mode (`--sender-match` / Phase 7 prompt; `identity` is the redirect-safe default). Uniform modes attach one pool to every campaign (`identity`: `tag_ids=[identity]` + per-sender tag cross-check; `all`: every connected sender, count-only); per-bucket modes (`esp`/`both`) attach a different pool per campaign cell via the three-way Google/Outlook/SMTP `tag_ids`/`excluded_tag_ids` mapping (AND-intersection), with per-cell membership verification (positive tags on Google/Microsoft cells, negative Google/Outlook exclusion on SMTP cells). Documents the paginated `while True` pattern AND post-attach count verification; rationing a pool across campaigns — and, in `identity`/`both`, attaching off-identity senders — is explicitly forbidden.
- [ ] Phase 4 UPLOAD gates the lead-create behind the agent-side operator-turn gate — single real `call_api` after the operator's turn, no vendor two-call (BC-2707 precedent).
- [ ] Input-email duplicate handling (BC-14044): Phase 1 step 2 input-list dedup (case-insensitive, keep-first, differing-duplicate conflict display + verbal keep-override at gate 1) + deliverability filter (drop `email_deliverable=false`, keep+warn blank, no-op absent), with `lead_count` set to the post-clean count; Phase 4 step 7d workspace-collision recovery (identify via cached existing-email set → set aside `workspace_collision` → gate 4b resubmit, never silent) + collision-aware step 9 count-check; skipped-contacts file always written (incl. `--no-host-lookup`).
- [ ] Phase 11 ACTIVATE requires double-confirm (operator-intent gate 11a + per-campaign turn-structure gate 11b; agent-side, single resume `call_api` per campaign).
- [ ] Phase 9 SEQUENCE enforces: step 1 `wait_in_days >= 1`, step 2 `wait_in_days >= 3`, field name `wait_in_days` (not `wait_days`), field name `email_subject` (not `subject`), 2-step max.
- [ ] Phase 1 PRE-FLIGHT validation checklist includes variable check, messaging sanity, lead spot check, workspace guard, unique-per-lead auto-toggle at <500.
- [ ] All 4 required args + 10 flags documented (`--no-host-lookup`, `--no-sequence`, `--activate`, `--preview`, `--reference`, `--entity`, `--identity`, `--sender-match`, `--test-send`, `--test-send-sender`); `argument-hint` frontmatter lists all 10.
- [ ] § Input validation section present with IV-1..IV-12 covering CSV-path safety (IV-1), path confinement (IV-2), dogfood path detection (IV-3), domain regex filter (IV-4), --test-send validation (IV-5), SOQL email regex (IV-6), metadata-no-credentials (IV-7), --campaign-name validation + write-path confinement (IV-8), sidecar CSV formula-injection neutralization (IV-9), CSV Liquid-metacharacter rejection (IV-10), --identity value validation (IV-11), and --sender-match value validation (IV-12).
- [ ] Error recovery documented per phase (partial state + resume procedure).
- [ ] Launch metadata write path `docs/campaigns/{short_entity}/{campaign-name}-{YYYY-MM-DD}.json` documented.
- [ ] Dogfood transcript (test campaign on `emailbison-personal`, 5–10 leads) attached to BC-5826 as a comment — activated or draft-only. Phase 10 Mode 1 (local render) MUST succeed with all 5 sanity checks passing. Phase 10 Mode 2 (`--test-send`) is optional and only validated if the flag was passed.
- [ ] `email-bison.md` §Consumed by / §Related skills lists this command as a consumer.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
