# 035. Campaign-lifecycle boundary: EB-draft staging moves into plan-campaign; launch-campaign becomes leads-only

**Status:** Accepted
**Date:** 2026-06-19
**Linear:** [BC-13628](https://linear.app/brite-nites/issue/BC-13628)
**Related ADRs:** [ADR-020](020-gtm-campaign-manifest-schema-v2.md) (the `email_bison.campaigns[]` v2 schema this builds on), [ADR-023](023-gtm-commercial-model-vocabulary.md), [ADR-028](028-skill-engineering-discipline.md) (builder/emit-mode discipline)

## Context

Brite's outbound GTM motion is driven by two orchestrator commands in the marketing plugin:

- `plugins/marketing/commands/plan-campaign.md` (~1022 lines) — a 4-layer scaffolder. It computes a slug, writes the plugin `manifest.json`, creates the Linear milestone + 2 work issues, soft-fails a Salesforce Campaign, and assigns an Email Bison workspace. Its non-goals section states it creates **NO EB campaign** ("Do NOT support `--reference` for cloning … not part of plan-campaign's surface"). It runs at scaffold time, *before any copy exists*.
- `plugins/marketing/commands/launch-campaign.md` (~1056 lines) — an 11-phase monolith requiring `--csv`: PRE-FLIGHT → HOST-LOOKUP → **VARIABLES (Phase 3)** → UPLOAD → **CAMPAIGN CREATE (Phase 5)** → ATTACH-LEADS → ATTACH-SENDERS (Phase 7) → SCHEDULE → **SEQUENCE (Phase 9)** → PREVIEW → ACTIVATE.

**Problem.** The lead list is the long pole of a campaign. Because EB campaign + custom-variables + sequence creation live *inside* `launch-campaign` (Phases 3/5/9) — which requires `--csv` — the email sequence cannot be built or approved until the list is ready. The copy and the list are the two slowest artifacts, and today they are serialized behind a single command. The team wants to stage the EB draft (sequence built, ready to send) **in parallel with list-building**.

**The copy-timing tension.** `plan-campaign` runs before copy exists; copy is a downstream artifact produced by the `email-copywriting` skill (emits `docs/campaigns/{short_entity}/copy-*.json` with `custom_variables`, `step_1`, `step_2`). You cannot build an EB sequence draft with no copy. So moving EB-draft creation into `plan-campaign` forces a copy dependency at plan time.

**Ground-truth on EB's send model (verified 2026-06-19 via `search_api_spec` + the BC-13628 dogfood).** Email Bison has **no native recipient-ESP→sender routing**: `POST /api/campaigns` takes only `name`+`type`; `attach-sender-emails` takes an explicit sender-ID array (no tag/all filter); EB rotates sends across whatever sender pool is attached, blind to the recipient's host. So Brite's "like-to-like" ESP split (Gmail→Gmail, etc.) is a **manual deliverability tactic**: partition into one campaign per ESP and attach only that ESP's senders. **Senders ARE labeled by their own ESP** — the `/api/sender-emails` record carries a `type` field (`google_workspace_oauth` / `microsoft_oauth` / SMTP-IMAP) AND `ScaledMail-{ESP}` tags — so the partition is done by filtering senders on the ESP tag (the routing is absent; the *sender labeling* is present). This makes the ESP split a *sender-side partition* — senders are workspace-level, knowable at plan time, **independent of the leads**. The email-type dimension (professional/role/personal), by contrast, is *recipient-derived* (resolved by `dig` host-lookup in launch-campaign Phase 2) and genuinely requires the leads.

Tracked in [BC-13628](https://linear.app/brite-nites/issue/BC-13628). Source handoff: `docs/plans/plan-campaign-eb-draft-staging-handoff.md`. Scoped plan: `docs/plans/BC-13628-plan.md`.

## Options Considered

The genuine fork is *how plan-campaign obtains copy* so it can build the draft at plan time. Four resolutions were weighed (from the handoff):

### Option 1: `--copy-artifact` hard precondition (copy-first)

`plan-campaign --copy-artifact <path>` requires copy to exist before planning.

- **Pros**: cleanest data flow; the draft build has its input guaranteed.
- **Cons**: reorders the lifecycle — copy must be produced *before* the plan/milestone/issues that normally scope the copywriting work. Chicken-and-egg: the issue that scopes the copy would not yet exist.

### Option 2: invoke `email-copywriting` as a sub-phase

`plan-campaign` calls the `email-copywriting` skill in-flow, then builds the draft from the emitted artifact.

- **Pros**: one entry point; lifecycle ordering preserved (scaffold still happens first within the same run); copy is generated exactly when the draft needs it.
- **Cons**: `plan-campaign` becomes heavier and interactive — it inherits `email-copywriting`'s gates (offer-posture confirm, value-equation 4-input gate, entity hard-gate) and input needs (situation-mining artifact or scratch interview, `marketing-context.md`). Couples the two orchestrators.

### Option 3: two-stage shell now, sequence later

`plan-campaign` creates the EB campaign *shell* (draft, no sequence) at plan time; a re-run or `--add-sequence` attaches the sequence once copy lands.

- **Pros**: no copy dependency at first run; preserves ordering.
- **Cons**: leaves empty EB shells lingering between stages; adds a second resumable entry point; the shell has little value without the sequence.

### Option 4: optional gated phase (skip-with-warning)

`plan-campaign` adds an EB-draft phase that skips with a warning when no copy artifact is present, safe to re-run later.

- **Pros**: lowest-friction migration; preserves ordering.
- **Cons**: the common case requires running `plan-campaign` twice; doesn't actually solve "stage the draft" on the first run when copy is absent.

## Decision

**Adopt Option 2** — `plan-campaign` invokes `email-copywriting` as a sub-phase, then builds the EB draft. One entry point keeps the operator mental model simple and guarantees the draft's copy input is produced exactly when needed, without reordering the scaffold-first lifecycle. The interactive-coupling cost is accepted: `plan-campaign` will marshal `email-copywriting`'s inputs up front and surface its gates. A `--copy-artifact <path>` flag is *also* added so an already-produced artifact can be passed in (skipping the sub-phase), which doubles as the idempotent re-entry path.

The decision carries five load-bearing sub-decisions:

1. **ESP-only triplet at draft time — exactly 3 drafts, never 6.** `plan-campaign` pre-creates the EB draft as a fixed **3-campaign ESP partition** (Google / Microsoft / SMTP), draft state, `plain_text: true`. This is correct *because* the ESP split is a sender-side partition that is plan-time-knowable (see Context ground-truth). **Tier is explicitly NOT a campaign-splitting axis** (operator decision, BC-13628): professional + role leads share their ESP's single draft — the team does not want the `tier × ESP` 6-way fan-out. **Personal / general inboxes are not targeted at all** and are filtered out at the launch-campaign lead-filter stage (HOST-LOOKUP email-type filter), so no personal/general draft is created. Email-type sub-split is recipient-derived and stays at attach-time; each lead is bucketed by `dig`-resolved ESP and attached to the matching pre-created draft. Draft naming convention becomes `{base} | {ESP}`.

2. **ATTACH SENDERS moves left too, ESP-PARTITIONED.** The sender attach (legacy launch Phase 7) moves into `plan-campaign` Step 8c.7 so the draft is "ready to send except for leads." Senders are **partitioned by ESP** — each ESP draft gets only its own ESP's senders (Google senders → Google draft, etc.) so same-ESP senders reach same-ESP recipients. This **supersedes the upstream Revgrowth-10 "attach ALL senders to ALL campaigns, never split" invariant**, which would defeat the like-to-like routing the ESP split exists to create (confirmed in the BC-13628 dogfood — an all-to-all attach was the bug; the operator caught it). The partition key is the workspace's `ScaledMail-{ESP}` sender tags (per-workspace mapping in Step 8c.7; e.g. personal: `ScaledMail-Google` / `ScaledMail-Microsoft` / `ScaledMail - SMTP - 11/26/2025`; b2b: `Google` / `ScaledMail-Microsoft` / `Scaledmail SMTP`). `launch-campaign` re-validates the attached senders **per ESP** at PRE-FLIGHT and halts if a pool drifted (never cross-attaches to fill a gap). When the per-page enumeration is impractical, the attach MAY defer to `launch-campaign` / the list-building issue scope (BC-12434).

3. **Manifest schema — reuse ADR-020 `campaigns[]`, do NOT fork it.** The draft campaigns are recorded in the existing v2 `email_bison.campaigns[]` array (ADR-020 / BC-11852), each entry `{workspace, campaign_id, esp, audience_tier{tier,seniority,modifiers}, name, launched_at, status}`. plan-campaign writes one `status: "draft"` record per ESP (`esp` ∈ `google`/`microsoft`/`smtp` — ADR-020's exact split axis), `launched_at: null`, real `campaign_id` backfilled after the MCP create. launch-campaign sets `status`/`launched_at` at activate. New per-draft fields needed by this refactor (`copy_artifact_path`, `custom_variables_created`, `sequence_ids`, `senders_attached`, `draft_created_at`) attach to each `campaigns[]` record or a sibling `email_bison.draft` block — **not** a parallel `draft_campaign_ids` dict.
   - **Blocking schema debt (BC-11857 never landed).** ADR-020 promised "a follow-up edit pins the scaffolder to schema v2 (BC-11857 hardening)," but `build_manifest.py` still emits `SCHEMA_VERSION = 1` with the singular `email_bison.campaign_id`, and `test_plan_campaign_contracts.py` still asserts the singular shape. This refactor **must complete that v2 pin** (builder emits `campaigns[]`; contract test flips; manifest `SCHEMA_VERSION` 1→2; existing manifests already covered by `migrate_manifest_v1_to_v2.py`). It is a prerequisite, not optional.
   - **RESOLVED — tier at plan time (operator decision, BC-13628).** Each of the 3 ESP draft records reuses ADR-020's **existing placeholder convention** verbatim: `audience_tier: {tier: "professional", seniority: null, modifiers: []}` + `pending_classification: true` — the exact `PLACEHOLDER_AUDIENCE_TIER` that `migrate_manifest_v1_to_v2.py` already writes. `pending_classification: true` is the signal that the tier is a non-authoritative placeholder (the drafts are intentionally NOT tier-split; professional+role share the ESP draft; personal/general excluded). **No schema relaxation needed** — `tier: "professional"` is a valid slug and `eb_campaign_record` already permits `pending_classification`. launch-campaign MAY stamp an observed-tier summary at attach-time for audit but does not need to back-fill.
   - **Additive schema fields (stays v2, no migration).** `email_bison_block_v2` and `eb_campaign_record` are `additionalProperties: false`, so the new draft-staging metadata is added as *optional* properties: on the record — `sequence_id`, `senders_attached[]`; on the block — `copy_artifact_path`, `draft_created_at`, `custom_variables_created[]`. Optional ⇒ existing manifests stay valid ⇒ `schema_version` remains `2`; `lint_canonicals.py` `SCHEMA_VERSION` unchanged.

4. **Deterministic-builder boundary (ADR-028 preserved).** EB MCP writes are an **IO boundary** performed command-side (exactly like the existing Step-8 Linear writes and Step-8b SF soft-fail), *not* `build_manifest.py` computation. The builder may deterministically compute the draft campaign names + the `email_bison` block *shape*; the command performs the MCP calls and backfills real IDs. `disable-model-invocation: true` stays; emit mode gains fixture coverage for the new manifest block.

5. **Double idempotency.** `plan-campaign` must detect an existing milestone (live trap `gotcha_plan_campaign_duplicates_existing_milestone`) **and** existing EB drafts, and re-create neither. EB-draft detection reuses the `list_campaigns(search="{base}")` pre-list guard from launch-campaign Phase 5; a re-run with `--copy-artifact` attaches/repairs the draft idempotently. If the EB sub-phase fails after the Linear/SF writes landed, it **soft-fails** like SF (manifest records `draft_campaign_ids: null`, operator re-runs to attach).

The EB sequence gotchas port with the logic: step-1 `wait_in_days` ≥ 1; A/B variant wired via the saved step **id** (not order); no spintax in subject lines; sequence-step newlines → `<br>`; `call_api` takes `body` not `data`; `search_api_spec` before any extended-tier `call_api`.

## Consequences

### Positive

- Copy + sequence can be staged and approved while list-building runs in parallel — the two long poles are no longer serialized. The draft sits in EB ready to send, blocked only on leads.
- Each command owns one clean stage: `plan-campaign` = the vessel (incl. draft), `launch-campaign` = leads + QC + go-live. `launch-campaign` shrinks from 11 phases to leads-only (PRE-FLIGHT, HOST-LOOKUP, UPLOAD, ATTACH-LEADS, SCHEDULE, PREVIEW, ACTIVATE).
- The campaign topology becomes simpler and matches EB's actual send model: 3 ESP campaigns instead of up to 9 `(email-type × ESP)` cells.
- The live dogfood case (`FY26, M07 | Prior-Year Clients | Holiday Renewal & Upsell`, milestone `772bb2be`) — copy exists, list still Backlog, drafts may already exist — is exactly the staged-before-leads scenario and the idempotency regression test.

### Negative

- `plan-campaign` becomes interactive and heavier — it inherits `email-copywriting`'s gates and now performs EB MCP writes, increasing its blast radius and the surface that must be idempotent. Two orchestrators are now coupled through the `email-copywriting` skill + the manifest contract.
- **Loss of email-type-level campaign separation.** Email-types now share one campaign per ESP. Any downstream analysis or deliverability tuning that relied on per-`(email-type × ESP)` campaigns must move to lead-level segmentation (tags/attributes). This is a deliberate topology change, not a regression.
- Sender state can drift between plan time (attach) and launch time (send); mitigated by a PRE-FLIGHT re-validation in `launch-campaign`.
- Two ~1000-line specs must be edited in lockstep; cross-references between them (and the manifest schema + `build_manifest.py` + contract tests) must stay consistent.
- **Scope absorbs the deferred v2-scaffolder pin (BC-11857).** Because `build_manifest.py` still emits v1, this refactor must finish what ADR-020 deferred — bring the builder + contract test to the v2 `campaigns[]` shape before adding draft records. That's net-positive (closes live schema debt) but enlarges the blast radius beyond the two command specs.
- The `audience_tier.tier`-at-plan-time question (Decision §3) must be resolved before the EB-draft phase can write a schema-valid `campaigns[]` record.
