# BC-5826 Plan — `/marketing:launch-campaign` command (11-phase CSV → EB activation flow)

> **Note (2026-05-05, BC-6654):** segmentation references in this plan reflect the pre-multiplicative ESP-axis spec. The current spec uses (email-type × ESP) cell segmentation per BC-6514 (`docs/designs/BC-6514-segmentation-axis-decision.md`); the metadata schema, naming convention, and `--no-segment` flag all changed. This plan is preserved as historical execution record.

**Issue:** [BC-5826](https://linear.app/brite-nites/issue/BC-5826) · **Milestone:** Marketing Plugin v0.1 — GTM Workflows (Revgrowth) · **Priority:** High · **Cycle:** W17 (current) · **Blocks:** campaign-debrief skill (consumes launch metadata) · **Unblocked by:** BC-5825 (email-copywriting, merged PR #157) · **Absorbs:** BC-5904 (Phase 10 Mode 1 + Mode 2 rewrite, F13/F5 from X17 dogfood), BC-5905 (F1 tool tier map, F2 cross-mapping, F4 sender priority chain, F6 dogfood metadata path, F7 EB-standard variable allowlist, F8 single end-of-Phase-1 gate, F10 Bash `dig` primacy, F11 future MCP-native note, F12 skip-empty-buckets) · **Post-review polish pass (2026-04-20):** 13 P2 + 12 P3 review findings fixed — added § Input validation (IV-1..IV-7), scoped ground-truthing rule to extended-tier only, documented EB namespace decision, metadata schema disclaimer + optional-fields block + credential exclusion rule, Supply-entity absence footnote, Phase 1 step 7 ADR 2c 0-row fallthrough + diagnostic, Phase 2 single-Bash-invocation with xargs -P + IV-4 filter + dynamic gate bucket placeholder, Phase 4/6 one-semantic-gate + per-iteration turn-structure prompts (BC-2707 preserved), BC-2707 affirmative list adds "do it", Phase 6 BC-2707 inline cite, Phase 7 count-scalar verification (paginate only on mismatch), Phase 10 Mode 2 IV-5 reference, verification checklist flag count 6→9

## Scope

Ship a single slash command at `plugins/marketing/commands/launch-campaign.md` that encodes Brite's 11-phase Email Bison launch flow with user gates between every mutating step. Also cross-link from `plugins/marketing/tools/integrations/email-bison.md` §Consumers. Two file changes total.

The command **consumes** the BC-5825 JSON artifact (`docs/campaigns/{entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`) + an enriched lead CSV, and **produces** an activated (or draft) Email Bison campaign plus a progressively-written launch-metadata JSON.

## Design decisions (captured in Phase 5 brainstorm, 2026-04-20)

### D1 — Progressive metadata writes (error recovery)

Each phase appends its result IDs to `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` as it completes. Partial JSON *is* the breadcrumb on failure; Phase 11 finalizes with `activated: true`. No separate `.resume/` state surface.

**Shape of the metadata JSON (final):**

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
  "custom_variables_created": ["COMPANY", "FIRST_NAME", "RECENCY_ANCHOR", "..."],
  "lead_ids_uploaded": 127,
  "campaign_ids": {"Google": 5551, "Microsoft": 5552, "Other": 5553},
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

`last_completed_phase` is the breadcrumb — on re-run the operator reads the file and picks up at phase N+1 manually. The command itself does not auto-resume; it documents the resume procedure prose-style per phase.

### D2 — `--reference <campaign-id>` pre-fills, does NOT skip gates

When `--reference` is passed, Phases 3/5/7/8 **still run their user gates**, but the option defaults are pre-populated from the reference campaign (variables, naming convention, sender list, schedule). User confirms — doesn't re-enter. Keeps every safety gate intact; saves typing, not attention.

Implementation: before each of phases 3/5/7/8, the command issues a read-only EB MCP call against `--reference` to fetch the relevant config, then surfaces the defaults inside the phase's AskUserQuestion.

### D3 — Phase 11 ACTIVATE inline, flag-gated, double-confirm

Phase 11 lives in the same command file. Entire block is skipped unless `--activate` flag is passed. When run, requires **two** user confirms:

1. **Operator-intent gate** (AskUserQuestion): "Phase 11 ACTIVATE will transition campaigns from `Draft` → `Queued` and begin sending real emails. Proceed?"
2. **Vendor MCP two-call gate** on `resume_campaign` (per BC-2707 precedent): first call returns vendor prompt → relay verbatim to user → second call with `confirmation: true` only after explicit affirmative turn.

Default (no `--activate`): command stops at Phase 10 PREVIEW with "Campaigns created in draft. Re-run with `--activate` to send."

## Phase structure — inner-loop discipline

- **E — Explore** (session-start): completed. Read `setup-email-bison.md`, `email-bison.md`, `docs/precedents/BC-2707.md`, `email-copywriting/SKILL.md`.
- **P — Plan** (this document): approved before Execute begins.
- **X — Execute**: 18 tasks (below), written directly into `launch-campaign.md` section by section. No code compilation — this is command markdown authoring.
- **V — Verify**: run the 16 verification criteria from the issue + dogfood on `emailbison-personal` with 5–10 leads.

## Task breakdown (18 tasks, maps 1:1 to issue)

### Scaffolding (X1–X2)
1. **X1** — Create `plugins/marketing/commands/launch-campaign.md` with frontmatter (`description`, `argument-hint`, `allowed-tools` block per issue spec).
2. **X2** — Write command header: one-paragraph purpose, link to upstream Revgrowth 10, link to BC-2707 precedent, link to BC-5825 JSON artifact schema.

### 11 phase bodies (X3–X13)
3. **X3 — Phase 1 PRE-FLIGHT.** CSV schema validation (required `email`, `first_name`, `company_domain`; optional `last_name`, `job_title`, `company_name`), row count via `wc -l`, workspace auto-detect (copy-artifact `entity: brite-nites` → b2b; `brite-labs` → b2b; operator override — BC-5905 F2: dogfood cross-maps legitimately, record `workspace_mismatch` flag rather than gating immediately), copy-artifact load + JSON-schema validate against BC-5825's schema v1.0, variable-presence check with EB-standard-variable allowlist (BC-5905 F7: `FIRST_NAME`, `LAST_NAME`, `COMPANY`, `COMPANY_DOMAIN`, `JOB_TITLE`, `EMAIL` resolve server-side via EB render engine, not CSV string match), messaging sanity checklist (value first? proof? CTA? spintax? 2-step max? em-dash-free? no `{FIRST_NAME}` in subject?), `{SENDER_*}` resolution via explicit 4-step priority chain (BC-5905 F4: artifact default → marketing-context → Salesforce → operator prompt), 3–5 lead spot-check render with deterministic first-option spintax, unique-per-lead auto-toggle at <500 leads, metadata JSON initial write (dogfood path override if CSV under `.claude/worktrees/` — BC-5905 F6). **Single end-of-phase user gate** (BC-5905 F8: folds workspace-mismatch ack + final approval into one prompt).
4. **X4 — Phase 2 HOST LOOKUP.** Bash `dig MX {domain} +short` per unique CSV domain (primary path — BC-5905 F10 correction: EB has no lead-side ESP tool). Bucket MX records into Google / Microsoft / Proofpoint / Mimecast / Barracuda / Cisco / Custom / Unknown client-side. Skip empty buckets in the 3-bucket plan (BC-5905 F12). Render segmentation plan (`{base} | Google`, `{base} | Microsoft`, `{base} | Other`). Note future MCP-native unlock requires moving Phase 2 after Phase 4 UPLOAD (BC-5905 F11). **User gate:** approve segmentation or `--no-segment`.
5. **X5 — Phase 3 VARIABLES.** For each entry in copy-artifact `custom_variables[]`, call `create_custom_variable`. Surface list pre-create. When `--reference` passed, pre-fill with reference campaign's variable set. **User gate.**
6. **X6 — Phase 4 UPLOAD.** `bulk_create_leads` with `custom_variables` array per lead. Chunk at 500-lead boundary. Two-call MCP confirmation gate per BC-2707 precedent (destructive to workspace state). Show sample 3 leads pre-submit. **User gate (explicit two-call).** Write `lead_ids_uploaded` count + `custom_variables_created` list to metadata JSON.
7. **X7 — Phase 5 CAMPAIGN CREATE.** Per segment, `create_campaign` with naming convention (base name + `| Google` / `| Microsoft` / `| Other` suffix). When `--reference` passed, pre-fill name template + config from reference. **User gate.** Append `campaign_ids` map to metadata JSON.
8. **X8 — Phase 6 ATTACH LEADS.** `import_leads_to_campaign` per campaign. Show per-campaign counts pre-attach. Handle `allow_parallel_sending` prompt verbatim — **never auto-enable**, relay to user per `email-bison.md` §Known gotchas. **User gate.**
9. **X9 — Phase 7 ATTACH SENDERS** (CRITICAL INVARIANT). Paginate full sender list via `list_sender_emails` — document the `while True` / cursor-pagination pattern from Revgrowth 10 upstream verbatim. Attach ALL connected senders to ALL campaigns via `attach_sender_emails_to_campaign`. Post-attach: re-read sender list per campaign, verify count matches. **Split/chunk senders across campaigns is explicitly forbidden** (Revgrowth 10 rule) — if count mismatch, HALT and surface error. When `--reference` passed, pre-fill with reference campaign's sender set. **User gate.** Append `sender_ids_attached` + `sender_attach_counts` to metadata JSON.
10. **X10 — Phase 8 SCHEDULE.** `create_schedule_from_template` with default template ID (document how to find it via `get_schedule_templates`). Default schedule: Mon–Fri 08:00–17:00 local. Show schedule summary pre-apply. When `--reference` passed, pre-fill with reference campaign's schedule. **User gate.** Append `schedule_id` to metadata JSON.
11. **X11 — Phase 9 SEQUENCE.** From copy-artifact `step_1` / `step_2`, call `create_sequence_steps` (v1.1 path — per `email-bison.md` §Known gotchas, prefer v1.1 over deprecated `/sequence-steps`). Enforce: `wait_in_days >= 1` on step 1, `wait_in_days >= 3` on step 2, field name `wait_in_days` (NOT `wait_days`), field name `email_subject` (NOT `subject`), 2-step max. Honor `--no-sequence` by skipping. **User gate.** Append `sequence_ids` to metadata JSON.
12. **X12 — Phase 10 PREVIEW** (revised per BC-5904 / F13 from X17 dogfood — EB has no standalone preview endpoint). Two modes. **Mode 1 (default): local render.** Substitute variables from copy artifact + lead CSV fields + `{SENDER_*}` resolutions; resolve spintax deterministically (first option); replace `<br><br>` with paragraph breaks; run 5 sanity checks (no unresolved `{VARIABLE}`, no unresolved spintax, no em-dash, no `<p>`, no `{{`); display to operator. Client-side only; no EB call. **Mode 2 (optional, `--test-send <email>`):** real EB test-send via `POST /api/campaigns/sequence-steps/{step_id}/test-email`. Additive — Mode 1 always runs first. **User gate (explicit sanity check):** operator visually confirms variables + spintax + format render cleanly.
13. **X13 — Phase 11 ACTIVATE** (optional, `--activate` only). Operator-intent AskUserQuestion → per-campaign `resume_campaign` with BC-2707 two-call gate. Document anti-pattern: two MCP calls in the same turn without a real user turn between them. On success, append `activated: true`, `activated_at`, `last_completed_phase: 11` to metadata JSON.

### Supporting sections (X14–X18)
14. **X14 — Argument parsing section.** Document all 4 required args (`csv`, `workspace`, `copy-artifact`, `campaign-name`) + all 6 flags (`--no-segment`, `--no-host-lookup`, `--no-sequence`, `--activate`, `--preview`, `--reference`, `--entity`). Defaults table.
15. **X15 — Error recovery section.** Per-phase resume procedure. Each phase block has a "If this phase fails…" subsection documenting (a) what state the workspace is in, (b) what IDs exist in the metadata JSON, (c) how to re-run from the next phase (manually, by re-invoking the command + reading the partial metadata).
16. **X16 — Cross-link from `email-bison.md` §Consumers.** Add `launch-campaign` command entry alongside existing consumers. Two-line edit.
17. **X17 — Dogfood.** Run the command on `emailbison-personal` workspace with a 5–10 lead test CSV + a hand-authored minimal copy artifact. Default path (no `--activate`) — campaigns created in draft, Phase 10 preview renders. Capture transcript, attach to BC-5826 as comment.
18. **X18 — Validation.** `./scripts/validate.sh` → exit 0. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → exit 0.

## Verification — 16 criteria (from issue, checked at Phase V)

- [ ] File exists with valid frontmatter (description, argument-hint, allowed-tools)
- [ ] `allowed-tools` includes `mcp__emailbison-b2b__*`, `mcp__emailbison-personal__*`, `mcp__plugin_marketing_salesforce__*`, Read, Write, Glob, Grep, Bash
- [ ] All 11 phases named and ordered correctly (PRE-FLIGHT / HOST LOOKUP / VARIABLES / UPLOAD / CAMPAIGN CREATE / ATTACH LEADS / ATTACH SENDERS / SCHEDULE / SEQUENCE / PREVIEW / ACTIVATE)
- [ ] Every mutating phase (3/4/5/6/7/8/9/11) has an explicit "USER CONFIRM" gate
- [ ] Phase 7 ATTACH SENDERS documents paginated `while True` pattern AND post-attach count verification; sender-split anti-pattern explicitly forbidden
- [ ] Phase 4 UPLOAD uses two-call MCP confirmation gate (cites BC-2707)
- [ ] Phase 11 ACTIVATE requires double-confirm (operator-intent + MCP two-call)
- [ ] Phase 9 SEQUENCE enforces: step 1 `wait_in_days >= 1`, step 2 `wait_in_days >= 3`, `wait_in_days` (not `wait_days`), `email_subject` (not `subject`), 2-step max
- [ ] Phase 1 PRE-FLIGHT includes variable check, messaging sanity, lead spot check, workspace guard, unique-per-lead auto-toggle at <500
- [ ] All 4 required args + 6 flags documented (csv, workspace, copy-artifact, campaign-name, --no-segment, --no-host-lookup, --no-sequence, --activate, --preview, --reference, --entity)
- [ ] Error recovery documented per phase (partial state + resume procedure)
- [ ] Launch metadata write path `docs/campaigns/{entity}/{campaign-name}-{YYYY-MM-DD}.json` documented + progressive-write shape spec'd
- [ ] Dogfood transcript attached to BC-5826 as comment (5–10 leads on `emailbison-personal`, Phase 10 preview rendered)
- [ ] `email-bison.md` §Consumers lists this command
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0

## Risks and notes

- **MCP tool name drift.** The issue references tools like `bulk_create_leads`, `create_campaign`, `attach-leads`, `create_sequence_steps`. Ground-truth every name via `search_api_spec` during X3–X13 — do NOT hardcode names from upstream docs that may have drifted. `email-bison.md` was last verified 2026-04-17; re-check during Execute.
- **Phase 7 invariant is load-bearing.** The Revgrowth 10 rule "never split senders across campaigns" exists because split-sender campaigns burn deliverability when segmentation creates sender-pool imbalance. Document this anti-pattern explicitly in the command body, not just in the verification list.
- **Dogfood scope.** 5–10 leads on `emailbison-personal` with `--activate` omitted. If any phase 1–10 fails during dogfood, surface immediately — do NOT proceed to mark task complete.
- **Parallel-session plan-file-loss.** Per BC-5798 precedent, once worktree is created, plan artifacts should live at `${WORKTREE}/docs/plans/` — not the primary checkout. This file is currently at primary-checkout `docs/plans/BC-5826-plan.md`; on worktree creation, verify the file is carried over.
- **No upstream pattern for progressive metadata writes.** D1 is a Brite-side innovation on top of Revgrowth 10's single-shot launch log. Document it clearly in the "launch metadata schema" section so downstream consumers (campaign-debrief skill) know the shape.

## References

- `plugins/marketing/commands/setup-email-bison.md` — command shape exemplar
- `plugins/marketing/tools/integrations/email-bison.md` — EB MCP ground truth, tool inventory, common workflows, gotchas
- `docs/precedents/BC-2707.md` — two-call MCP gate semantics (turn structure, not vocabulary)
- `plugins/marketing/skills/email-copywriting/SKILL.md` §4 JSON schema — copy artifact input contract
- [Revgrowth1/ai-gtm-workflows workflow 10 launch.py](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/10-campaign-launch) (MIT) — upstream 9-step flow
- `docs/plans/marketing-gtm-expansion.md` §1.4 — scoping rationale
- `memory/MEMORY.md` — EB workspace disambiguation (55 b2b / 13 personal), security hook bare `git push` gotcha
