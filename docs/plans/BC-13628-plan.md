# BC-13628 — Plan: re-cut plan-campaign / launch-campaign boundary

**Issue:** [BC-13628](https://linear.app/brite-nites/issue/BC-13628/re-cut-plan-campaign-launch-campaign-boundary-move-eb-draft-creation)
**Branch:** `drake/plan-campaign-eb-draft-staging`
**Source handoff:** `docs/plans/plan-campaign-eb-draft-staging-handoff.md`
**Status:** Scoping (pre-implementation). ADR must be ratified before spec edits.

---

## Goal

Re-cut the two GTM orchestrators so each owns one clean stage, so the EB sequence can be built/approved **in parallel with list-building** instead of waiting on the list:

- **`plan-campaign`** — stage the whole vessel **including the EB draft** (campaign(s) + custom-vars + sequence, **no leads**, draft state).
- **`launch-campaign`** — **leads only**: CSV validation + upload/attach + QC (`--preview`/`--test-send`) + `--activate`.

## Decided up front

- **Copy-timing = Option 2.** `plan-campaign` invokes the `email-copywriting` Skill as a sub-phase, then builds the EB draft from the emitted `copy-*.json`. One entry point; plan-campaign inherits email-copywriting's interactive gates and input needs.
- **Canonical repo = `brite-claude-plugins`** (installed per `~/.claude/plugins/cache/`). `brite-plugins` is a second clone of the same remote — no divergence.

## Ground-truth: EB has NO native recipient-ESP routing (verified 2026-06-19, b2b `search_api_spec`)

`POST /api/campaigns` takes only `name`+`type`; `attach-sender-emails` takes explicit sender IDs; `check-mx-records` is sender-side DNS only. No `provider`/`connection_type`/`match`/`route`/`recipient` field anywhere in the campaign or sender API. **The like-to-like ESP split is a manual Brite deliverability tactic, not a hidden EB feature.** EB's send model is: attach a sender pool to a campaign, EB rotates across it — so same-ESP sending requires partitioning into one campaign per ESP yourself.

**Architectural payoff for this refactor** — the ESP split is a *sender-side partition*, and senders are workspace-level + known at plan time, **independent of the leads**:

| Dimension | Driven by | Knowable at plan time? |
|---|---|---|
| **ESP** (Google/Microsoft/SMTP) | sender-pool partition | ✅ yes — pre-create 3 drafts + attach senders |
| **email-type** (professional/role/personal) | recipient address (`dig` host-lookup) | ❌ no — needs the leads |

This **resolves OQ1** (ESP-only at draft time is correct; email-type sub-split must stay at attach-time) and surfaces a new consideration: **ATTACH SENDERS may move left into plan-campaign too** (see Phase 1 / OQ5).

---

## Docs-grounding finding (2026-06-19): manifest schema already exists (ADR-020)

ADR-020 / BC-11852 (**Done**) already shipped the v2 `email_bison.campaigns[]` array — `{workspace, campaign_id, esp, audience_tier{tier,seniority,modifiers}, name, launched_at, status}`, empty = unlaunched. BC-11852's own description: *"1 logical campaign = 1-3 EB records split by ESP (SMTP/Google/Microsoft)"* — i.e. the handoff's ESP triplet IS this `esp` axis. **So we reuse `campaigns[]` (status:draft records), NOT a new `draft_campaign_ids` dict.**

**Live schema debt this refactor must close:** `build_manifest.py` still emits `SCHEMA_VERSION = 1` (singular `email_bison.campaign_id`) and `test_plan_campaign_contracts.py` still asserts the singular shape. ADR-020's promised scaffolder-v2 pin (BC-11857) never landed. This refactor absorbs it: builder → `campaigns[]`, contract test flips, `SCHEMA_VERSION` 1→2 (existing manifests covered by `migrate_manifest_v1_to_v2.py`).

ADR-035 corrected accordingly (Decision §3).

## Phase 0 — ADR (blocking; `/workflows:architecture-decision`)

Ratify the lifecycle + boundary before touching specs. The ADR must explicitly decide:

1. **Copy-timing resolution = Option 2** (sub-phase). Record why (one entry point; copy stays downstream-of-scaffold but inside the same command run) and the cost (plan-campaign becomes interactive + heavier; coupled to email-copywriting + situation-mining inputs).
2. **ESP-split model change (the load-bearing decision).** Today `launch-campaign` Phase 5 creates one campaign per `(email-type × ESP)` cell, derived from host-lookup on the **leads**. At plan time there are no leads, so the draft must be a fixed **ESP-only triplet** (Google / Microsoft / SMTP). Consequence: email-types collapse to share one campaign per ESP; email-type bucketing moves to attach-time in launch-campaign. The ADR must ratify:
   - draft campaign naming convention at plan time (`{base} | {ESP}` vs today's `{base} | {Email-type} | {ESP}`);
   - that launch-campaign's `(email_type × ESP)` segment map now **attaches into** the pre-created ESP draft (Phase 6 ATTACH LEADS maps `professional|Google`, `role|Google`, … → the single `Google` draft);
   - whether email-type-level campaign separation is lost intentionally, or preserved via a different mechanism (e.g. tags). **Recommend: ESP-only at draft time per the handoff; email-type carried as a lead attribute/tag, not a separate campaign.**
3. **Manifest schema.** Add an `email_bison` block to the plugin `manifest.json` written by plan-campaign: `email_bison.draft_campaign_ids` keyed by ESP (`{"Google": <id>, "Microsoft": <id>, "SMTP": <id>}`), plus `email_bison.copy_artifact_path`, `custom_variables_created`, `sequence_ids` (per ESP), `draft_created_at`. Define how launch-campaign reconciles ESP-only manifest keys against its `{email_type}|{esp}` launch-metadata keys.
4. **Deterministic-builder boundary (ADR-028).** EB MCP writes are **IO-boundary / command-side** (like the existing Step-8 Linear + Step-8b SF writes), NOT `build_manifest.py` computation. The builder may *compute* the draft campaign names + the manifest `email_bison` block shape (deterministic); the command performs the EB MCP calls and backfills real IDs. Confirm the emit-mode contract still holds and define the new emit-mode fixture coverage.
5. **Idempotency contract.** plan-campaign must detect (a) an existing milestone (live trap `gotcha_plan_campaign_duplicates_existing_milestone`) AND (b) existing EB drafts, and NOT re-create either. Define the detection probe (`list_campaigns(search="{base}")` pre-list, same guard as launch-campaign Phase 5 step 3) and the reuse path.

---

## Phase 1 — `plan-campaign.md` edits (GAINS the EB draft)

Insert new phase(s) after the existing Linear/SF writes (Step 8) and before/at the final reconcile (Step 11). The EB draft requires the resolved slug, entity→workspace map (Step 4), and a copy artifact.

1. **New flag(s).** Add `--copy-artifact <path>` (use an existing copy artifact instead of generating) and document the email-copywriting sub-phase. Reconcile with existing `--situation-mining` / `--creative-angles` flags. Update `argument-hint` + the Step-1 flag table + Step-1b parse-time validation (path-exists / shape check for `--copy-artifact`).
2. **New sub-phase A — copy resolution.** If `--copy-artifact` given → read + validate it (email-copywriting JSON schema v1.0). Else → invoke `email-copywriting` Skill (it runs its own offer-posture / value-equation / entity gates; needs `marketing-context.md` + a situation artifact or scratch interview). Capture the emitted `copy-*.json` path. Honor email-copywriting's ABORT semantics (missing proof point, declined entity) — surface and HALT plan-campaign's EB phase without rolling back the Linear/SF writes.
3. **New sub-phase B — EB draft build** (IO-boundary; ground-truth every tool via `search_api_spec` first):
   - **Custom variables** (ported launch Phase 3): `list_custom_variables` (case-insensitive dedup) → `create_custom_variable` (`{name}` only) for new ones.
   - **Campaign create** (ported launch Phase 5, ESP-only): pre-list `list_campaigns(search="{base}")` → idempotency gate → `create_campaign` ×3 (Google/Microsoft/SMTP draft) → `update_campaign` `plain_text: true` PATCH each.
   - **Sequence** (ported launch Phase 9): build step_1 + step_2 from the copy artifact; **port the 5 EB sequence gotchas** — step-1 `wait_in_days` ≥ 1; A/B variant wired via the saved step **id** (not order); no spintax in subject lines; newlines → `<br>`; `call_api` takes `body` not `data`.
4. **Manifest write (Step 7 / backfill).** Populate the `email_bison` block (Phase-0 schema) with the real draft IDs after the MCP writes return.
5. **Two-call confirm gate.** The existing Step-6 gate must cover the EB writes too (or add a dedicated gate before EB create). Keep `disable-model-invocation: true`.
6. **Update non-goals** — remove "Do NOT support `--reference`" framing if the draft now needs cloning semantics (decide in ADR; likely keep `--reference` in launch-campaign only and have plan-campaign read its own manifest).
7. **`--dry-run` / emit mode** — the dry-run preview (Step 5) must render the planned EB draft (names, var count, sequence steps) without writing; emit mode must cover the new manifest `email_bison` block deterministically.

## Phase 2 — `launch-campaign.md` edits (BECOMES leads-only)

1. **Remove** Phase 3 VARIABLES, Phase 5 CAMPAIGN CREATE, Phase 9 SEQUENCE (now plan-campaign's job). Renumber remaining phases.
2. **Resolve the draft** — read `email_bison.draft_campaign_ids` from the manifest (preferred) or `--reference <campaign-id>`. Add validation: HALT with a clear message if no draft exists ("run `plan-campaign` first to stage the EB draft").
3. **Phase 6 ATTACH LEADS** — change the bucket→campaign map from `{email_type}|{esp}` → per-cell-campaign to `{email_type}|{esp}` → **ESP-only draft** (all email-types of an ESP attach to that ESP's single draft). Keep `allow_parallel_sending` guard.
4. **Update** `argument-hint` (drop `--no-sequence`; keep `--csv` required, `--preview`, `--test-send`, `--activate`, `--reference`), `allowed-tools`, the launch-metadata schema (drop `sequence_ids`/`custom_variables_created`/`campaign_ids`-create semantics; they become read-from-manifest), tool tier map, input validation.
5. **Preserve** PRE-FLIGHT, HOST-LOOKUP, UPLOAD, ATTACH-SENDERS, SCHEDULE, PREVIEW, ACTIVATE.

## Phase 3 — manifest schema + builder + tests

1. `build_manifest.py` — extend manifest schema with the `email_bison` block; deterministic computation of draft names; bump manifest `schema_version` + add a migration if a v2→v3 step is needed (`migrate_manifest_*.py`).
2. Update `plugins/marketing/tests/test_plan_campaign_contracts.py` + launch-campaign contract tests; add emit-mode eval for the new EB phase (ADR-028 Phase-1 gate: changed cmd ships emit-mode + ≥1 eval).
3. Run `./scripts/validate.sh` (Step-sequence lint, hook lint, contract tests) — bump BOTH `plugins/marketing/.claude-plugin/plugin.json` and the `marketplace.json` entry in the SAME commit (cache-key gotcha).

## Phase 4 — lifecycle docs + dogfood

1. Write the ADR (Phase 0) and add its index entry to `CLAUDE.md` + `docs/decisions/`.
2. Update handbook/process references + the Linear milestone-template prose that describes the launch flow.
3. **Dogfood** on the live case `FY26, M07 | Prior-Year Clients | Holiday Renewal & Upsell` (milestone `772bb2be`) once EB MCP is reconnected: copy artifact exists (`brite-gtm` PR #33); EB drafts may already exist (built 06-08) → verify the idempotency gate detects + does not duplicate. List (BC-12434) is Backlog = the staged-before-leads scenario.
4. `/workflows:ship`.

---

## Open questions for the design session / ADR

- **OQ1 (ESP model):** confirm email-type-level campaign separation is intentionally dropped in favor of ESP-only drafts (recommend yes per handoff). If not, plan-campaign cannot pre-create the cells without leads — would force a hybrid (shells now, split later).
- **OQ2 (copy provenance):** when `email-copywriting` is invoked as a sub-phase, does plan-campaign require a situation-mining artifact up front, or allow the scratch-path interview? (recommend: allow both; warn on scratch path per email-copywriting Flow 2.)
- **OQ3 (rollback semantics):** if the EB-draft sub-phase fails after the Linear milestone + SF Campaign already landed, what's the recovery? (recommend: soft-fail the EB phase like SF — manifest records `draft_campaign_ids: null`, operator re-runs `plan-campaign --copy-artifact` to attach the draft idempotently.)
- **OQ4 (`--reference`):** keep cloning semantics in launch-campaign only, or let plan-campaign clone an existing draft? (recommend: plan-campaign reads its own manifest; `--reference` stays a launch-campaign affordance.)
- **OQ5 (move ATTACH SENDERS left?):** since senders are ESP-partitioned + workspace-level + plan-time-knowable (see Ground-truth above), Phase 7 ATTACH SENDERS could move into plan-campaign too, making the draft "ready except for leads." Trade-off: plan-campaign would need the sender-pool / ESP-tag convention up front, and sender state can drift between plan and launch. (recommend: decide in ADR — leaning move it left, with launch-campaign re-validating attached senders at PRE-FLIGHT.) **ADR-035 decided: move it left.**
- **OQ6 (tier at plan time) — RESOLVED (operator, 2026-06-19):** Exactly **3 ESP drafts, never 6** — tier is NOT a campaign-split axis (professional+role share the ESP draft). Personal/general inboxes are **not targeted** (filtered at launch HOST-LOOKUP). Each draft record reuses ADR-020's existing `PLACEHOLDER_AUDIENCE_TIER` verbatim: `audience_tier:{tier:"professional",seniority:null,modifiers:[]}` + `pending_classification:true` (same value `migrate_manifest_v1_to_v2.py` writes) — `pending_classification:true` marks tier non-authoritative. No schema relaxation. New draft-metadata fields (`sequence_id`, `senders_attached`, `copy_artifact_path`, `draft_created_at`, `custom_variables_created`) added as OPTIONAL schema properties → stays v2.

## Risks

- **Two ~1000-line specs edited in lockstep** — the phase-numbering + cross-references between them must stay consistent (launch-campaign references "the copy artifact ingested by Phase X"; those move).
- **EB MCP was disconnected** in the originating session — reconnect/relaunch before any dogfood (`/marketing:setup-email-bison`).
- **Idempotency is now double** (milestone + EB drafts) — the highest-value test surface.
