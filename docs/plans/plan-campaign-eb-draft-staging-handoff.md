# Handoff — move EB draft creation into `plan-campaign`; make `launch-campaign` leads-only

**For:** a fresh session in the `brite-claude-plugins` repo (the marketing plugin / command specs).
**Created:** 2026-06-19, from a GTM working session in `brite-gtm`.
**Decision owner:** Holden/Drake (Head of GTM). This is a **campaign-lifecycle change** → collaborative; ship as a PR to the two command specs + an ADR.

---

## The decision

Re-cut the boundary between the two orchestrators so each owns one clean stage:

- **`plan-campaign`** → stage the whole campaign vessel **including the Email Bison draft** (campaign(s) + copy + sequence, **no leads**, draft state).
- **`launch-campaign`** → **leads only**: CSV validation + upload/attach + QC gates (`--preview`, `--test-send`) + `--activate`.

Today `launch-campaign` is monolithic (create campaign → apply sequence → upload leads → activate; `--csv` required). The goal is to pull "create EB draft + sequence" *left* into `plan-campaign`, so the sequence can be built/approved **in parallel with list-building** instead of waiting on the list.

## 🔴 The core design problem to solve first (copy-timing)

`plan-campaign` currently runs at **scaffold time, before any copy exists** — it deliberately creates **no** EB campaign, only records a workspace assignment in the manifest. Copy is a *downstream* output (the `/marketing:email-copywriting` artifact, produced after planning). **You cannot build an EB sequence draft with no copy.** So owning EB-draft creation forces a copy dependency at plan time. Weigh these resolutions:

1. **`plan-campaign --copy-artifact <path>` (copy-first):** require copy to exist before planning. Cleanest data flow, but reorders the lifecycle (copy moves before plan).
2. **`plan-campaign` invokes `email-copywriting` as a sub-phase:** generate copy inside plan-campaign (Skill call), then build the draft. Keeps one entry point; makes plan-campaign heavier + needs the situation-mining/offer inputs up front.
3. **Two-stage / idempotent:** plan-campaign creates the EB campaign *shell* now (draft, no sequence); a re-run (or a small `plan-campaign --add-sequence`) attaches the sequence once copy lands. Preserves today's ordering; adds a resumable step.
4. **Optional, gated phase:** plan-campaign adds an EB-draft phase that **skips with a warning** when no copy artifact is present, and is safe to re-run later. Lowest-friction migration.

Recommend the design session pick one explicitly and record it in the ADR.

## What moves where

**`plan-campaign` GAINS (from launch-campaign Phases ~3–9):**
- EB campaign creation (ESP-split triplet: Google/Microsoft/SMTP), draft state
- custom-variable creation; sequence-step upload from the copy artifact; **step-1 A/B variant wiring**
- write the draft `campaign_id`(s) back into `manifest.json` at plan time
- keep existing: Linear milestone + 2 work issues, SF Campaign (soft-fail), workspace assignment

**`launch-campaign` BECOMES (leads + QC + go-live):**
- validate `--csv` → upload/attach leads to the **existing** draft (lean on the current `--reference <campaign-id>` plumbing, or read the draft id from the manifest)
- suppression / 180-day gate, host-lookup segmentation (if retained), QC: `--preview` local render + `--test-send`
- `--activate` (queued / real sending). Drop sequence creation (now plan-campaign's job).

## Cross-cutting concerns the session must handle

- **EB sequence gotchas move with the logic** — port these to plan-campaign: step-1 `wait_in_days` ≥ 1; A/B variant needs the saved step **id** (not order); no spintax in subject lines; sequence-step newlines → `<br>`; ESP-split naming convention; `call_api` takes `body` not `data`. (See the `brite-gtm` memory `gotcha_eb_*` notes.)
- **Idempotency / no duplicate drafts** — plan-campaign must detect an existing EB draft (and existing milestone) and **not** re-create. This is already a live trap: see `gotcha_plan_campaign_duplicates_existing_milestone` — re-running plan-campaign on an existing campaign duplicates the milestone + revives the retired 8-issue chain. The EB-draft addition makes idempotency *more* important (don't double-create EB campaigns either).
- **Manifest schema** — add `email_bison.draft_campaign_ids` (per ESP) populated at plan time; `launch-campaign` reads them.
- **ADR + lifecycle docs** — this changes the standard lifecycle; write an ADR in the plugins repo and update any handbook/process references (and the Linear milestone-template prose that describes the launch flow).
- **EB MCP reality** — servers register at **user level** (`mcp__emailbison-personal__*` / `mcp__emailbison-b2b__*`, no `plugin_marketing_` prefix). Honor the **ground-truthing rule**: `search_api_spec` before any extended-tier `call_api`. (Note: EB MCP was **disconnected** during the originating session — reconnect/relaunch before dogfooding.)

## Files + current state

- `plugins/marketing/commands/plan-campaign.md` (~1022 lines) — 4-layer scaffolder; "NO EB campaign created here" today.
- `plugins/marketing/commands/launch-campaign.md` (~1056 lines) — 11-phase; `--csv` required; `--no-sequence`, `--preview`, `--activate`, `--reference` flags exist; **no `--no-leads`** today.
- ⚠️ **Two repos** carry these files: `brite-claude-plugins` AND `brite-plugins`. Confirm the canonical/installed one first (`~/.brite-plugins/.repo-root` read empty in the originating session). This repo is currently on branch `drake/plan-campaign-icp-dependency-map`; branch fresh for this work.

## Live test case (dogfood on a real, already-staged campaign)

`FY26, M07 | Prior-Year Clients | Holiday Renewal & Upsell` (Linear milestone `772bb2be`, slug `landscape-lighting-luxury-homeowner-holiday-renewal-winter-ready-fy26-m07`):
- Copy artifact exists: `brite-gtm` PR #33 → `docs/campaigns/nites/copy-prior-year-clients-holiday-renewal-upsell-2026-06-08.json` (step_1 + step_2, A=GFCI / B=heat-strips variant, EB spintax).
- Milestone notes say copy was *"built as ESP-split drafts"* on 06-08 — so EB drafts **may already exist**. Perfect idempotency test: the new plan-campaign EB phase must detect + not duplicate them.
- List (Corinne, BC-12434) is still Backlog — i.e. exactly the "draft staged before leads" scenario this refactor is for.

## Suggested approach / skills

1. `brainstorming` — resolve the copy-timing question (the 4 options above) before touching specs.
2. ADR (`/workflows:architecture-decision`) — record the chosen lifecycle + boundary.
3. `writing-plans` → edit both command specs + manifest schema in lockstep; keep them consistent.
4. Dogfood `--preview`/draft on the BC-12307 campaign once EB MCP is back; verify no-duplicate behavior.
5. `/workflows:ship` — PR + compound learnings.
