# BC-6545 plan — F22 (allow_parallel_sending) live verification + spec update

**Issue:** [BC-6545](https://linear.app/brite-nites/issue/BC-6545) — Backlog (Low prio)
**Branch:** `corinne/bc-6545-bc-6308-follow-up-f22-allow_parallel_sending-safety-check`

---

## Plain-language summary

When you launch a marketing campaign, you upload a list of people to email. Email Bison (Brite's email-sending tool) is **supposed** to refuse adding someone if they're already being emailed by another active campaign — emailing one person from two campaigns at once damages sender reputation. The launch-campaign checklist says this safety check works. **We've never actually tested it.** This session triggers a conflict on purpose in our practice account, watches what Email Bison really does, writes down the real answer, and updates the checklist with verified behavior. ~45 min including cleanup.

**Decision rationale:** The issue body said "don't test now, deferral pattern is sound across rounds 1–3." That reasoning was situational (inside 5-hour dogfood walks). In a focused session with no main flow to protect, the 5-min walltime is just 5 min — and produces real signal that removes a long-standing "unverified" hedge from the spec. Confirmed with Corinne 2026-05-04.

---

## What we're verifying

**The hypothesis our spec currently asserts** (`launch-campaign.md` lines 556 / 560 / 589 + `email-bison.md` line 270):
When attaching a lead to a campaign via `POST /api/campaigns/{id}/leads/attach-leads`, if the lead is *already* in another active campaign's sequence, Email Bison **refuses the attach and returns a parallel-sending prompt body** asking the operator to enable `allow_parallel_sending: true`.

**What's confirmed:** The `allow_parallel_sending` parameter exists in the endpoint schema (verified `search_api_spec` BC-6308 round-3 T7).

**What's unverified:** What Email Bison actually does when the conflict fires without the parameter. Three possibilities:
- HTTP 422 with a prompt body → safety check works as our spec says
- HTTP 200 with no protection → safety check broken (would need spec correction)
- HTTP 200 with skip-and-warn → soft safety (spec needs softening)

---

## Pre-flight

- Workspace target: `emailbison-personal` workspace 13 (Brite's practice account; never customer data).
- Test artifacts that will be created and cleaned up: 2 throwaway campaigns + 1 test lead.
- Test lead email: `bc-6545-f22-test@brite.co` (deletable per BC-6515 precedent — lead 14723 was created + DELETE'd cleanly).
- No permanent state delta expected. Workspace 13 already holds 8 permanent custom variables from prior dogfood rounds; this F22 test does NOT touch custom variables.

---

## Task list

### Task 1 — Pre-test setup in workspace 13 (~5 min)

**Goal:** Create the conflict scenario — one lead "In Sequence" in campaign A, ready to be conflict-attached to campaign B.

**Steps:**
1. Confirm active workspace via `mcp__emailbison-personal__get_active_workspace_info` → expect workspace 13.
2. Create campaign A: `mcp__emailbison-personal__create_campaign` with `name: "BC-6545 F22-test-A"`. Capture `campaign_id_A`.
3. Create campaign B: `mcp__emailbison-personal__create_campaign` with `name: "BC-6545 F22-test-B"`. Capture `campaign_id_B`.
4. Create test lead: `mcp__emailbison-personal__create_lead` with `email: "bc-6545-f22-test@brite.co"`, `first_name: "F22"`, `last_name: "Test"`, `company: "BC-6545"`. Capture `lead_id`.
5. Attach lead to campaign A: `mcp__emailbison-personal__call_api` against `POST /api/campaigns/{campaign_id_A}/leads/attach-leads` with body `{lead_ids: [lead_id]}`. No `allow_parallel_sending`. Expect 200 success (no conflict yet).
6. Activate campaign A so the lead is "In Sequence." Path: `search_api_spec(search_term="activate")` to find the activation endpoint, then `call_api`. If activation requires more setup (sequence steps, schedule), document the blocker and adjust — see fallback path below.
7. Verify lead is "In Sequence" in campaign A: `get_campaign(campaign_id_A)` and check lead status.

**Fallback path:** If activating campaign A requires sequence steps + schedule + senders (full launch readiness), the test setup balloons beyond 5 min. In that case:
- Document the activation blocker.
- Pivot to a softer test: attach the lead to a non-activated campaign A (just creates the lead↔campaign join), then attach to B and observe. This won't trigger the production-realistic conflict — surface that gap in the verdict.
- If the softer test produces no conflict at all: pivot to **Option 1 (soften wording)** for the spec update — file a follow-up issue (e.g., "BC-XXXX: BC-6545 test recipe needs activation-path detail") and proceed with the wording-softening fallback.

**Verification:** Lead exists in campaign A in some attached state. Capture exact state in scratch notes for transcript.

**Commit checkpoint:** None — workspace-side setup only.

---

### Task 2 — Run the F22 test (~5 min)

**Goal:** Trigger the conflict and record Email Bison's response.

**Steps:**
1. **Test 2a — without override:**
   - `mcp__emailbison-personal__call_api` against `POST /api/campaigns/{campaign_id_B}/leads/attach-leads` with body `{lead_ids: [lead_id]}`. **Do NOT** set `allow_parallel_sending`.
   - Record: HTTP status, full response body verbatim.
2. **Test 2b — with override:**
   - `mcp__emailbison-personal__call_api` against `POST /api/campaigns/{campaign_id_B}/leads/attach-leads` with body `{lead_ids: [lead_id], allow_parallel_sending: true}`.
   - Record: HTTP status, full response body verbatim.
3. Classify the verdict using the three-possibility framework above.

**Verification:** Both 2a and 2b returns recorded verbatim. Classification picked.

**Commit checkpoint:** None — test execution only.

---

### Task 3 — Cleanup (~3 min)

**Goal:** Return workspace 13 to its pre-test state.

**Steps:**
1. Delete the test lead via `mcp__emailbison-personal__call_api` (DELETE endpoint per BC-6515 verification). If lead is attached to active campaigns and delete returns 422, find the detach endpoint via `search_api_spec(search_term="detach lead")` and run it before delete.
2. Delete campaign A and campaign B. `search_api_spec(method=DELETE, search_term="campaign")` to find the endpoint. If campaigns must be paused/deactivated before delete, do so.
3. Verify workspace 13 is clean: list campaigns, confirm no `BC-6545 F22-test-*` campaigns remain. List leads filtered on email pattern `bc-6545-f22-test`, confirm none.

**Verification:** Workspace 13 lead and campaign counts back to pre-test baseline. No permanent state delta.

**Commit checkpoint:** None — workspace cleanup only.

---

### Task 4 — Capture test transcript (~5 min)

**Goal:** Write a brief, factual record of the test for institutional memory and as the source-of-truth artifact for the spec update.

**Steps:**
1. Create `docs/dogfood/bc-6545/` directory.
2. Write `docs/dogfood/bc-6545/f22-test-transcript.md` with:
   - **Setup:** campaign IDs created, lead ID created, activation state achieved (or blocker noted).
   - **Test 2a (no override):** request + verbatim response + HTTP status.
   - **Test 2b (with override):** request + verbatim response + HTTP status.
   - **Verdict classification:** one of {fires-as-spec / no-protection / soft-skip / inconclusive-blocked-on-activation}.
   - **Cleanup:** confirmation of lead + campaign deletion.
   - **Implication for spec:** which lines change and how.

**Verification:** Transcript reads cleanly cold (someone reading it 6 months from now understands what was tested and what was found).

**Commit checkpoint:** Commit 1 — `BC-6545: live F22 test transcript + workspace 13 cleanup confirmation`. Captures the raw test artifact before any spec edits, so the spec change has a verifiable source.

---

### Task 5 — Update spec lines with verified behavior (~10 min)

**Goal:** Replace the unverified assertion in 4 spec lines with the verified behavior. Specific edits depend on the Task 2 verdict.

**Files:**
- `plugins/marketing/commands/launch-campaign.md` lines 556, 560, 589
- `plugins/marketing/tools/integrations/email-bison.md` line 270

**Edit shape per verdict:**

- **Verdict = fires-as-spec (HTTP 422 with prompt body):** Remove the "may fail" / "is a real semantic vendor gate" hedging where redundant; replace with verified-behavior wording citing BC-6545. Cite the actual response body and HTTP status.
- **Verdict = no-protection:** Update the spec to remove the parallel-sending alert as a vendor-side safeguard. Add a flagged P1 follow-up note that operator-side delta-check is the only protection. File spec-correction follow-up issue.
- **Verdict = soft-skip:** Update wording to describe the actual behavior (silent skip + which leads were skipped). Adjust the operator-gate wording in step 5d accordingly.
- **Verdict = inconclusive-blocked-on-activation:** Pivot to wording-softening per fallback in Task 1. Add "(unverified — see BC-6545 transcript; activation-path test recipe needs follow-up)" hedge. File the test-recipe follow-up issue.

**Common edit elements (any verdict):**
- Add `(verified BC-6545, 2026-05-04)` cite-anchor at each touched line per the BC-6515 precedent (live-verify before enshrining).
- Drop the `may fail` softening verb in `email-bison.md` line 270 — replace with the verified-behavior verb (`fires`, `silently skips`, etc.) per the verdict.

**Verification:** Run `grep -n "allow_parallel_sending\|F22" plugins/marketing/` and confirm every match either reflects the verified behavior or is intentionally unaffected.

**Commit checkpoint:** Commit 2 — `BC-6545: spec update on 4 lines with verified F22 behavior` (or "wording softening" fallback variant).

---

### Task 6 — Version bump + validate (~3 min)

**Goal:** Patch-level version bump per CLAUDE.md rule (any edit under `plugins/marketing/{commands,skills,...}` requires a same-commit version bump in BOTH `plugin.json` AND `marketplace.json`).

**Steps:**
1. Edit `plugins/marketing/.claude-plugin/plugin.json`: bump `version` from `0.3.21` → `0.3.22`.
2. Edit `.claude-plugin/marketplace.json`: bump the `marketing` entry's `version` to `0.3.22`.
3. Run `./scripts/validate.sh` and confirm green.

**Verification:** validate.sh exits 0; both version strings now read `0.3.22`.

**Commit checkpoint:** Commit 3 — `BC-6545: marketing 0.3.22 — F22 verified behavior`. May fold into Commit 2 per pacing memory (commits at natural checkpoints, not every task).

---

### Task 7 — Pre-review readiness (~2 min)

**Goal:** Branch is ready for `/workflows:review`.

**Steps:**
1. `git status` — clean working tree.
2. `git log` — review commit messages for clarity.
3. Confirm BC-6545 still Backlog — Corinne decides whether to move to In Progress before review or after.

**Verification:** Branch state clean, commits readable, plan + transcript on disk.

---

## Validation criteria (definition of done)

- [ ] Test 2a + 2b run, responses recorded verbatim in `docs/dogfood/bc-6545/f22-test-transcript.md`.
- [ ] Verdict classified.
- [ ] Workspace 13 clean — no `BC-6545 F22-test-*` campaigns, no `bc-6545-f22-test@brite.co` lead remaining.
- [ ] 4 spec lines updated per the verdict (or wording-softened per fallback).
- [ ] `plugin.json` + `marketplace.json` both at `0.3.22`.
- [ ] `./scripts/validate.sh` green.
- [ ] Working tree clean. Commits readable.
- [ ] Plan + transcript on disk.

---

## Risk + fallback summary

- **Activation-path blocker (Task 1 step 6):** Activating a campaign in Email Bison may require sequence steps + senders + schedule, which expands the test beyond 5 min. Fallback: pivot to wording-softening, file follow-up issue noting the test-recipe gap.
- **Cleanup-path blocker (Task 3):** If lead can't be detached before delete, or campaigns can't be deleted while leads attached, may leave residue. Fallback: archive instead of delete; document the residue in transcript.
- **Verdict ambiguity:** If Test 2a returns something the three-possibility framework doesn't cover, capture the response verbatim, classify as "novel" in the transcript, defer spec edit until next operator review.

---

## Out of scope

- Spec changes outside the 4 cited lines (no scope expansion to adjacent F-rows).
- BC-6514 segmentation-axis redesign (separate ticket; would be the upstream architectural fix that makes F22 *truly* irrelevant).
- BC-6557 smart-merge research (separate ticket; tabled this session).
- Filing follow-up issues for any verdict-specific spec corrections — those are next-session work, not BC-6545's scope.
