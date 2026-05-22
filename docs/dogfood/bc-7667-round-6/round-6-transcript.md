---
issue: BC-7667
title: BC-6785 round-6 launch-campaign dogfood — full re-validation walk
chain_position: 6 of N (predecessor: BC-6785 round-5, convergent close)
worktree: .claude/worktrees/BC-7667-round-6
branch: corinne/bc-7667-round-6
base_commit: c424acd
started: 2026-05-22
operator: Corinne Brewer
workspace: emailbison-personal (workspace 13)
keystones: R-A, R-B, R-8, R-21, R-23, R-25 (6)
side_flows: R-24, R-25, R-26, R-27
deferred: R-13 (F22 allow_parallel_sending — spec-read suffices per round-4/5 precedent)
inputs:
  csv: docs/dogfood/bc-6308/test-leads.csv (9 leads)
  copy_clean: docs/dogfood/bc-6308/test-copy.json
  copy_liquid: docs/dogfood/bc-6554/test-copy-liquid.json
  single_lead_artifact: TBD per round-5 pattern (operator email)
---

# Round-6 transcript — BC-7667

Convergent re-validation walk after BC-6785 round-5 + 3 follow-ups (BC-7597, BC-7598, BC-7599) landed. Loop-closing rule: 0 blocking findings → marketing plugin launch-campaign is production-ready; chain stays terminated at round-5.

Per-R-row protocol: surface output + expected + 3-way verdict (✅ / ⚠️ / 🔴), operator confirms framing before recording.

## Findings table

| R-row | Phase | Type | Verdict | Notes |
|-------|-------|------|---------|-------|
| R-A ★ | 1 PRE-FLIGHT | BC-7599 fix-val | ✅ | spec-read; live-fire at R-21 |
| R-B ★ | 1 PRE-FLIGHT | BC-7597 fix-val | ✅ | spec-read; live-fire on metadata write |
| R-1   | 2 grid construction | regression | ✅ | 4P/2P/3R; brite.co=Google via dig; 5 empty cells |
| R-2   | 3 VARIABLES | regression | ✅ | meta.per_page=15 confirmed |
| R-3   | 3 VARIABLES | regression | ⚠️ | +1 net-new var (`territory` id 16, 2026-05-19) — out-of-band drift |
| R-4   | 3 VARIABLES | regression | ✅ | 8 artifact UPPERCASE → 8 EB-stored lowercase matches; BC-6780 holds |
| R-5   | 4 UPLOAD | regression | ✅ | 9 leads created IDs 15143-15151; id+uuid both present; lowercase names accepted |
| R-6   | 4 UPLOAD | regression | ✅ | re-POST existing 422 confirmed; **2 side-findings** for loop close |
| R-7   | 4 UPLOAD | spec-read | ✅ | wrapper-vs-API gate clarity intact at all 4 gate sites |
| R-8 ★ | 5 CAMPAIGN CREATE | regression keystone | ✅ | 4 campaigns IDs 53-56 per BC-6514 naming; 3rd keystone of 6 |
| R-9   | 5 CAMPAIGN CREATE | regression | ✅ | pre-list returns 4 matches; branched gate-5 path would fire |
| R-10  | 5 CAMPAIGN CREATE | regression | ✅ | plain_text=true PATCHed on all 4 campaigns |
| R-11  | 5 CAMPAIGN CREATE | regression | ✅ | BC-6544 omit-resets-bool fires; restored via re-PATCH |
| R-12  | 6 ATTACH LEADS | regression | ✅ | 9 leads attached to 4 campaigns; counts 2/3/2/2 match R-1 grid |
| R-13  | 6 ATTACH LEADS | DEFERRED | ⏭️ | per round-4/5 carryover (spec-read suffices) |
| R-14  | 7 ATTACH SENDERS | regression | ✅ | 772 connected senders, 52 pages, per_page=15, lowercase filter |
| R-15  | 7 ATTACH SENDERS | regression | ✅ | 15 senders × 4 campaigns attached (page 1 only) |
| R-16  | 7 ATTACH SENDERS | regression | ✅ | post-attach Δ visible sub-second via sender-emails endpoint |
| R-17  | 8 SCHEDULE | regression | ✅ | template id 3 → clones 28-31, BC-6303 field naming intact |
| R-18  | 9 SEQUENCE | regression | ✅ | bare step_2.subject → "Re: " auto-prepended; variant=false ok |
| R-19  | 9 SEQUENCE | regression | ✅ | wait clamped 0→1; thread_reply bool; UPPERCASE tokens accepted |
| R-20  | 10 PREVIEW | regression | ✅ | Mode 1 local render, 5 sanity checks pass |
| R-21 ★ | 10 PREVIEW | regression + BC-7599 live-fire | ✅ | 4th keystone — test-send fired w/o marketing-context.md |
| R-21b | 10 PREVIEW | BC-7598 doc-claim live-val | ✅ | spec doc-claim intact; 1 side-finding (test-copy-liquid.json stale) |
| R-22  | 11 ACTIVATE | regression | _pending_ | |
| R-23 ★ | 11 ACTIVATE | regression keystone | _pending_ | round-6 closes here |
| R-24  | side-flow | BC-6556 sad-path | _pending_ | |
| R-25 ★ | side-flow | BC-6781 keystone | _pending_ | |
| R-26  | side-flow | BC-6548 sad-path | _pending_ | |
| R-27  | side-flow | BC-6514/host-lookup | _pending_ | |

---

## Phase 1 PRE-FLIGHT

### R-A ★ — BC-7599 fix-validation (spec-read)

**Hypothesis:** with NO `docs/marketing-context.md` present in the worktree, `--test-send corinne@britenites.com` should pass IV-5 (email-format regex only) and proceed to Phase 10 Mode 2 without halting. The pre-fix strict-halt on missing file is removed.

**Evidence:**
- `docs/marketing-context.md` absent in worktree (`ls` → No such file or directory).
- `launch-campaign.md:75` (IV-5) — regex + structured-JSON only; cross-refs ADR-011 for allowlist removal; zero mention of `marketing-context.md` as a gate.
- ADR-011 § Decision (2026-05-11): *"Remove IV-5's domain allowlist check. Retain IV-5's email-format regex and structured-JSON construction."* `docs/marketing-context.md` stub explicitly deleted in PR #285.
- IV-5 regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` matches `corinne@britenites.com`.

**Expected:** Phase 1 IV-5 passes on regex alone; per-send safety = Phase 10 Mode 2 step 4 operator-confirm. No marketing-context.md required.

**Verdict:** ✅ Expected. Spec layer confirms BC-7599 fix-validation. Live-fire deferred to R-21 (EB `call_api` test-email path).

### R-B ★ — BC-7597 fix-validation (spec-read)

**Hypothesis:** with worktree path containing uppercase Linear ID, IV-3 regex matches case-insensitively per BC-7597 fix; metadata write path resolves to `.claude/worktrees/<name>/dogfood/`.

**Evidence:**
- Worktree path: `<repo-root>/.claude/worktrees/BC-7667-round-6` (uppercase `BC-7667` segment).
- `launch-campaign.md:71` (IV-3) — regex `[A-Za-z0-9._-]+` matches both A–Z and a–z (per BC-7597 PR #279 fix from prior `[a-z0-9._-]+`).
- Manual char-class test on `BC-7667-round-6`: all 15 chars in class (`B`, `C`, `-`, `7`, `6`, `6`, `7`, `-`, `r`, `o`, `u`, `n`, `d`, `-`, `6`). Match.
- IV-8 dogfood-path confinement (line 89) cross-references IV-3 — metadata writes to `<repo-root>/.claude/worktrees/<worktree>/dogfood/`.

**Expected:** Phase 1 step 10 writes metadata to `<repo-root>/.claude/worktrees/BC-7667-round-6/dogfood/` (NOT default `docs/campaigns/{entity}/`). The uppercase ID is preserved verbatim — no case-folding in the extracted `<worktree-name>`.

**Verdict:** ✅ Expected. BC-7597 regex fix confirmed at spec layer. The round-5 manual-override workaround is obsolete. Live-fire validation occurs at Phase 1 step 10 metadata write.

---

**Phase 1 PRE-FLIGHT close:** 2 keystones ✅ (R-A, R-B). Both spec-reads pass. Live-fire surfaces deferred to R-21 (BC-7599) and Phase 1 step 10 metadata write (BC-7597).

---

## Phase 2 — HOST LOOKUP

### R-1 — multiplicative grid construction (regression)

**Hypothesis:** 4 personal + 2 professional + 3 role; 9-cell grid built; F12 drops 5 empty cells under `include_all`.

**Step 1 evidence — per-lead email-type tags:**
- 4 personal: leads 1,2 (gmail.com), leads 3,4 (outlook.com) — domain-in-free-list match
- 2 professional: leads 5,6 (brite.co) — neither role-prefix nor free-domain
- 3 role: leads 7 (info@), 8 (sales@), 9 (contact@) — all on dogfoodtest.com (non-free) with role-prefix local-parts

**Step 2 evidence — live `dig MX` per unique domain:**
- gmail.com → `gmail-smtp-in.l.google.com` → **Google** (literal)
- outlook.com → `outlook-com.olc.protection.outlook.com` → **Microsoft** (literal + `*.protection.outlook.com` MX pattern)
- brite.co → `aspmx.l.google.com` + `aspmx2/3.googlemail.com` → **Google** (matches `aspmx.l.google.com` MX pattern)
- dogfoodtest.com → _no MX records_ → **Unknown** → rolls to **Other** in 3-bucket plan

**Step 3 grid (pre-gate-2, 9 cells, raw counts):**

|              | Google | Microsoft | Other |
|--------------|--------|-----------|-------|
| professional | 2      | 0         | 0     |
| role         | 0      | 0         | 3     |
| personal     | 2      | 2         | 0     |

Non-empty: 4 cells. Empty: 5 cells.

**Step 4b F12 (post-gate, projected):** under `include_all` → drops 5 empty cells, 4 campaigns. Under `default` → drops 8 cells, 1 campaign (`professional|Google`=2).

**Verdict:** ✅ Expected. All three step-1/step-2/step-3 sub-claims match round-5 regression baseline. F12 5-empty-cell count holds under `include_all`. Metadata write (step 4d) verified later at R-8.

---

## Phase 3 — VARIABLES

### R-2 — `list_custom_variables` Laravel pagination (regression)

**Hypothesis:** Laravel `?page=N` paginated meta with hardcoded `per_page: 15`.

**Evidence (live `GET /api/custom-variables`):**
- `meta.current_page: 1`, `meta.last_page: 2`, `meta.per_page: 15`, `meta.total: 16`, `meta.to: 15`
- `meta.links[]` URL pattern: `https://personal.outbase.so/api/custom-variables?page=1` / `?page=2`
- Page 2 fetched via `?page=2` query → returned 1 remaining var (vertical_descriptor id 8)

**Verdict:** ✅ Expected. `per_page: 15` hardcoded; `?page=N` URL pattern; multi-page span when total >15.

### R-3 — 15 permanent vars retention ⚠️ REFUTED (net-new: +1)

**Hypothesis:** all 15 round-5 permanent vars present; net-new from round-5 = 0.

**Evidence:** 16 total vars in workspace 13 across 2 pages — all 15 round-5 vars retained ✅, but **`territory` (id 16, created 2026-05-19)** is net-new since round-5 close (2026-05-11).

**Verdict:** ⚠️ Unexpected, non-blocking.

**Framing:** Out-of-band workspace state change (NOT spec drift, NOT EB behavior change, NOT round-6 agent error). 8-day window between rounds; some interim marketing activity created `territory`. Round-6 inherits live state — loop-close cleanup baseline shifts from 15 → 16 vars.

### R-4 — Case-insensitive UPPERCASE→lowercase var matching (BC-6780 regression)

**Hypothesis:** 8 artifact UPPERCASE vars → 8 "existing → reuse" classifications; zero POSTs; zero 422s.

**Evidence:**

| Artifact UPPERCASE | `.lower()` | EB-stored | classification |
|--------------------|-----------|-----------|----------------|
| RECENCY_ANCHOR | recency_anchor | id 7 ✅ | existing → reuse |
| VERTICAL_DESCRIPTOR | vertical_descriptor | id 8 ✅ | existing → reuse |
| SPECIFIC_FRICTION | specific_friction | id 9 ✅ | existing → reuse |
| PROOF_POINT_COMPANY | proof_point_company | id 10 ✅ | existing → reuse |
| PROOF_POINT_NUMBER | proof_point_number | id 11 ✅ | existing → reuse |
| PROOF_POINT_TIMEFRAME | proof_point_timeframe | id 12 ✅ | existing → reuse |
| FREE_ASSET_NOUN | free_asset_noun | id 13 ✅ | existing → reuse |
| SENDER_FIRST_NAME | sender_first_name | id 14 ✅ | existing → reuse |

Spec confirmation at `launch-campaign.md:414`: lowercase compare → existing → reuse, no POST attempted on match.

**Verdict:** ✅ Expected. All 8 reuse cleanly. Zero POSTs needed. BC-6780 logic intact.

---

**Phase 3 close:** R-2 ✅, R-3 ⚠️ (workspace drift, non-blocking), R-4 ✅. Workspace 13 has 16 vars (was 15 in round-5 baseline; `territory` added out-of-band). All copy-artifact UPPERCASE vars resolve to existing lowercase storage; no mutations needed in Phase 3.

**Workspace context note (operator-clarified 2026-05-22):** `emailbison-personal` (workspace 13) is the live production EB instance for BriteNites, **not** an isolated dogfood sandbox — operator uses it for both real campaign sending and dogfood testing. The BC-7667 issue body's "0 leads, 0 campaigns" pre-state assumption was aspirational at file-time and is **not** representative of how this workspace actually operates. Live counts at round-6 start: **15,073 leads, 21 campaigns** (1 active: campaign 52 FY26 M05 Brite Recruiting Trade Companies; 1 completed: campaign 21 FY26 M3 Restaurants 250; 18 archived FY25 M11; plus the round-5-era residue). R-3 ⚠️ ratifies state drift since round-5; framing widened from "+1 var" to "production-workspace evolution including a new campaign launch."

**Round-6 discipline going forward:**
- Round-6 leads upload as `dogfood-test-*@gmail.com / outlook.com / brite.co / dogfoodtest.com` per the test CSV — distinct from production lead emails.
- Round-6 campaigns to be tagged or named with a `BC-7667 R6` marker for cleanup precision at loop close.
- Loop-close lead+campaign cleanup will use the round-6 tag/prefix; production state is untouched.

---

## Phase 4 — UPLOAD

### R-5 — Phase 4 happy-path bulk-create (regression)

**Hypothesis:** POST `/api/leads/multiple` accepts title/company; response includes both id (int) and uuid (str); per-lead `custom_variables[].name` lowercased per BC-6780; happy-path bulk-create succeeds.

**Evidence (live POST, 9 leads, 1 chunk):**
- 9 leads created IDs 15143–15151 (consecutive); all `status: unverified`; all uuids share `a1d779e0-` prefix (per-batch identifier).
- Each lead carries both `id` (int) and `uuid` (str) — confirms BC-6515 forward-compat doc claim at runtime.
- `title` populated from CSV `job_title`; `company` populated from CSV `company_name`.
- 8 custom_variables per lead, all stored lowercase (recency_anchor..sender_first_name) — BC-6780 lowercase-at-body-build rule holds.
- Side-observation: `overall_stats.replies` returns `[]` (array) for never-replied leads; spec example showed scalar `replies: 1`. Permissive runtime schema; no follow-up.

**Verdict:** ✅ Expected. All 4 primary sub-claims hold. BC-6515 + BC-6780 fix-validations both ratified at runtime.

### R-6 — Phase 4 atomic 422 on duplicate (regression) + 2 side-findings

**Hypothesis (round-5):** forced duplicate-email in chunk → all-or-nothing 422 (Sx-8 atomic rejection).

**Two scenarios run:**

| Scenario | Test | Actual result |
|----------|------|---------------|
| (a) Within-chunk duplicate | 2 rows with same email `bc7667r6-dup-test@dogfoodtest.com` in 1 POST | HTTP 201 success, **1 lead created** (id 15152), 2nd occurrence silently dropped |
| (b) Re-POST existing | 1 row with `dogfood-test-01@gmail.com` (= existing id 15143) | `{"error":"HTTP 422 Error"}` — atomic 422 |

**Round-5 transcript cross-ref** (`docs/dogfood/bc-6554-round-5/round-5-transcript.md:225–228`): round-5's R-6 tested scenario (b), not (a). The "in chunk" phrasing was ambiguous but their actual test was re-POST.

**Verdict on the round-5 R-6 hypothesis (b variant):** ✅ Expected. Atomic 422 on re-POST behavior confirmed.

**Side-finding A — within-chunk dedup undocumented (for loop close).** EB silently deduplicates within-chunk row duplicates: first occurrence created, subsequent dropped silently. Not in `email-bison.md § Known gotchas` (not in current Sx-1..Sx-15 set). 🟡 doc-gap, not a bug. Worth a gotcha doc add similar to BC-7598's pattern. File at loop close.

**Side-finding B — `launch-campaign.md:454` contradiction (for loop close).** Spec text reads: *"re-POST to POST /api/leads/multiple to merge against existing leads (server upserts in place by email match; verified BC-6785 round-5 R-28)"*. Two problems: (1) cited evidence misattributed — R-28 verified upsert-VARIANT endpoints don't exist, NOT that `/api/leads/multiple` upserts existing; (2) behavioral claim is wrong — re-POST returns HTTP 422 (verified live + round-5 R-6), not upsert. 🟡 spec correctness gap. File at loop close.

### R-7 — Phase 4 spec-read (BC-6304 wrapper-vs-API gate clarity)

**Hypothesis:** spec text differentiates wrapper-tool layer vs API-direct layer; two-call gate is agent-side, not vendor-side; identical shape at all gate sites.

**Evidence (4 gate sites grep-walked):**

| Site | Line | Wrapper-vs-API distinction |
|------|------|----------------------------|
| § Vendor confirmation gates via call_api (general principle) | 57 | ✅ Sx-9 + BC-6439 + BC-2707 |
| Phase 4 § Two-call gate (agent-side) | 438 | ✅ |
| Phase 6 § Two-call gate (agent-side) | 592 | ✅ + BC-6545 allow_parallel branch noted as a real vendor gate |
| Phase 11 step 2 § Agent-side per-campaign turn-structure | 928–954 | ✅ |

**Verdict:** ✅ Expected. BC-6304 task-1 fix from round-3 + BC-6439 closure (no migration path) ratified at all 4 sites.

---

**Phase 4 close:** R-5 ✅, R-6 ✅ (with 2 side-findings deferred to loop close), R-7 ✅. Workspace delta: +10 leads (9 from R-5 + 1 from R-6's within-chunk dedup probe) = 15,083 total. Zero blocking findings; 2 loop-close follow-ups queued.

---

## Phase 5 — CAMPAIGN CREATE

### R-8 ★ — multiplicative campaign create (KEYSTONE regression)

**Hypothesis:** BC-6514/BC-6654 multiplicative fix — 9-cell grid → ~4 surviving cells → naming `{base} | {Email-type} | {ESP}` → metadata `segments` map with `{email_type}|{esp}` keys.

**Evidence (live `create_campaign` × 4, pre-list returned 0 matches first):**

| Cell key | Campaign ID | Name | Status | Type | Lead-bucket |
|----------|-------------|------|--------|------|--------------|
| `professional\|Google` | 53 | `BC-7667 R6 \| MAIN \| Professional \| Google` | draft | outbound | 2 (15147, 15148) |
| `role\|Other` | 54 | `BC-7667 R6 \| MAIN \| Role \| Other` | draft | outbound | 3 (15149-15151) |
| `personal\|Google` | 55 | `BC-7667 R6 \| MAIN \| Personal \| Google` | draft | outbound | 2 (15143, 15144) |
| `personal\|Microsoft` | 56 | `BC-7667 R6 \| MAIN \| Personal \| Microsoft` | draft | outbound | 2 (15145, 15146) |

Naming follows `{base} | {Email-type-titlecased} | {ESP}` per BC-6514 (Email-type BEFORE ESP). Base = `BC-7667 R6 | MAIN`. IDs sequential 53–56.

**Metadata projection (would write at step 9):**
```json
"segments": {
  "professional|Google": {"email_type": "professional", "esp": "Google",    "count": 2},
  "role|Other":          {"email_type": "role",         "esp": "Other",     "count": 3},
  "personal|Google":     {"email_type": "personal",     "esp": "Google",    "count": 2},
  "personal|Microsoft":  {"email_type": "personal",     "esp": "Microsoft", "count": 2}
},
"campaign_ids": {
  "professional|Google": 53, "role|Other": 54,
  "personal|Google": 55,     "personal|Microsoft": 56
}
```

Empty cells (5 of 9) absent per F12 prune.

**Verdict:** ✅ Expected — KEYSTONE ✅. BC-6514 multiplicative-axis + BC-6654 schema rewrite ratified at runtime. 3rd of 6 keystones ✅ (R-A, R-B, R-8).

### R-9 — silent-duplicate guard / branched gate-5 (BC-6302/F20 regression)

**Hypothesis:** pre-create one decoy; verify branched gate-5 render.

**Evidence:** Post-R-8, `list_campaigns(search="BC-7667 R6")` returns the 4 campaigns just created (IDs 56, 55, 54, 53 in name-desc order). M=4 > 0 → branched gate-5 path would fire on a hypothetical Phase 5 re-run, surfacing the 4 IDs inline (≤10 → no `and {K} more` truncation).

**Verdict:** ✅ Expected. Pre-list substring-match returns all campaigns whose name begins with the base. Round-6 effectively tests with M=4 (stronger than round-5's single-decoy M=1). F20 silent-duplicate guard intact.

### R-10 — `plain_text: true` per-campaign (regression)

**Hypothesis:** `plain_text: true` PATCHed on every campaign post-create.

**Evidence (4 PATCHes to `/api/campaigns/{id}/update`):**

| Campaign | Response `plain_text` |
|----------|------------------------|
| 53 (Professional\|Google) | ✅ true |
| 54 (Role\|Other) | ✅ true |
| 55 (Personal\|Google) | ✅ true |
| 56 (Personal\|Microsoft) | ✅ true |

**Verdict:** ✅ Expected. All 4 PATCHes applied; `plain_text_applied: true` would be set in metadata.

### R-11 — BC-6544 PATCH-omit live test (regression)

**Hypothesis:** PATCH without `plain_text` field reverts it to `false`; re-PATCH with `plain_text: true` restores.

**Evidence (3-step on campaign 53):**

| Step | PATCH body | Response `plain_text` |
|------|------------|------------------------|
| 1. Baseline (post-R-10) | (R-10 set true) | true |
| 2. PATCH `{"name": "BC-7667 R6 \| MAIN \| Professional \| Google"}` (no plain_text) | **false** ⚠️ reverted |
| 3. PATCH `{"plain_text": true}` (restore) | true ✅ |

**Side-observation:** Attempted step 2 first with `{"max_emails_per_day": 500}` only — returned HTTP 422 (separate validation rule, possibly "cannot decrease from existing 1000"). Switched to `{"name": "<same name>"}` as the benign no-op for the omit-test. Not a BC-6544 issue.

**Verdict:** ✅ Expected. BC-6544 omit-resets-bool behavior fires deterministically on `plain_text`. Always-include rule documented at `launch-campaign.md:545+548` + `email-bison.md:273` is empirically necessary.

---

**Phase 5 close:** R-8 ★ ✅ keystone (4 campaigns 53–56), R-9 ✅, R-10 ✅, R-11 ✅. Workspace state: +4 campaigns (21 → 25 total; 4 round-6 + 21 production). Zero blocking findings.

---

## Phase 6 — ATTACH LEADS

### R-12 — lead bucket mapping (F21/BC-6303 regression)

**Hypothesis:** F21/BC-6303 lead bucket mapping; metadata `lead_ids_by_bucket` + `lead_attach_counts` populate per cell key.

**Evidence (4 POSTs to `/api/campaigns/{id}/leads/attach-leads`):**

| Cell key | Campaign ID | Lead IDs | Response | list_campaigns lead count |
|----------|-------------|----------|----------|----------------------------|
| `professional\|Google` | 53 | [15147, 15148] | success | 2 ✅ |
| `role\|Other` | 54 | [15149, 15150, 15151] | success | 3 ✅ |
| `personal\|Google` | 55 | [15143, 15144] | success | 2 ✅ |
| `personal\|Microsoft` | 56 | [15145, 15146] | success | 2 ✅ |

Total: 9 leads attached across 4 campaigns. Counts match R-1 grid cell counts exactly.

**Metadata projection (would write at step 7):**
```json
"lead_ids_by_bucket": {
  "professional|Google": [15147, 15148],
  "role|Other":          [15149, 15150, 15151],
  "personal|Google":     [15143, 15144],
  "personal|Microsoft":  [15145, 15146]
},
"lead_attach_counts": {
  "professional|Google": 2, "role|Other": 3,
  "personal|Google": 2,     "personal|Microsoft": 2
}
```

**Side-observation:** All 4 responses include `"Existing leads were not added"` suffix. Informational — EB checks for in-campaign duplicates pre-attach. No collisions hit here (fresh leads).

**Verdict:** ✅ Expected. F21/BC-6303 bucket map intact at runtime.

### R-13 — F22/BC-6545 `allow_parallel_sending` ⏭️ DEFERRED

Per issue body + round-4/5 carryover: spec-read suffices; live-fire requires pre-poison setup not justified for institutional-memory-only check. Spec at `email-bison.md:270` encodes BC-6545 behavior. Not counted as a verdict.

---

**Phase 6 close:** R-12 ✅, R-13 ⏭️ deferred. Workspace state: 10 dogfood leads (9 attached + 1 dup-probe orphan), 4 round-6 campaigns each with their assigned bucket leads. No senders, no schedule, no sequence yet.

---

## Phase 7 — ATTACH SENDERS

### R-14 — list_sender_emails pagination + lowercase status (F23/Sx-10/Sx-11 regression)

**Evidence (`GET /api/sender-emails?status=connected`):**
- `meta.per_page: 15` ✅ (Sx-10 hardcoded)
- `meta.total: 772` connected senders across `meta.last_page: 52` pages
- `meta.links[]` URL pattern `?page=N`
- Lowercase `status=connected` accepted with HTTP 200 success (Sx-11)
- Page 1 returns IDs 981–995, all `status: "Connected"`, all `type: microsoft_oauth`, all Outlook-tagged, all on `washington{festive|winter}lights.com` domains

**Verdict:** ✅ Expected. Sx-10 + Sx-11 + F23 all intact at runtime.

### R-15 — F24 partial-pool decision (15 senders × 4 campaigns)

**Evidence (4 POSTs to `/api/campaigns/{id}/attach-sender-emails` with sender_email_ids=[981..995]):**

| Campaign | Response |
|----------|----------|
| 53 (Professional\|Google) | success |
| 54 (Role\|Other) | success |
| 55 (Personal\|Google) | success |
| 56 (Personal\|Microsoft) | success |

All 4 attach calls returned `success: true` with "Sender emails successfully added to {campaign-name}".

**Verdict:** ✅ Expected. F24 partial-pool — 15 senders from page 1 attached to all 4 campaigns. No pagination loop needed at dogfood scale.

### R-16 — F26/R-15 eventual-consistency post-attach Δ (regression)

**Evidence:**
- `get_campaign(53)` returned `total_leads: 2` immediately (lead attach from R-12 visible).
- `GET /api/campaigns/53/sender-emails` returned 15 senders (`meta.total: 15`, all IDs 981–995) immediately after the R-15 POST.

**Verdict:** ✅ Expected. Both lead attach (R-12) and sender attach (R-15) Δ visible sub-second via read-back endpoints. F26 eventual-consistency intact.

---

**Phase 7 close:** R-14 ✅, R-15 ✅, R-16 ✅. Workspace state: 10 dogfood leads + 4 round-6 campaigns (each with 2-3 leads + 15 senders) + 21 production. No schedule, no sequence yet.

---

## Phase 8 — SCHEDULE

### R-17 — schedule template apply (F27/BC-6303 regression)

**Hypothesis:** workspace 13 has 1 template (id 3); template applied to all 4 campaigns; metadata field naming honors BC-6303 rename.

**Evidence:**

`GET /api/campaigns/schedule/templates` → 1 template:
- id 3, M-F 08:00–20:00 America/Denver, type "Schedule template", status "Not Started"

`POST /api/campaigns/{id}/create-schedule-from-template` × 4 with body `{"schedule_id": 3}`:

| Campaign | Schedule clone | type |
|----------|----------------|------|
| 53 | 28 | Campaign Schedule |
| 54 | 29 | Campaign Schedule |
| 55 | 30 | Campaign Schedule |
| 56 | 31 | Campaign Schedule |

Schedule properties cloned verbatim from template 3 (M-F 08-20 America/Denver).

**Metadata projection:**
```json
"schedule_template_id": 3,
"campaign_schedule_ids": {
  "professional|Google": 28, "role|Other": 29,
  "personal|Google": 30,     "personal|Microsoft": 31
}
```

Field naming honors BC-6303 — workspace-level `schedule_template_id` (singular, → template) vs per-campaign `campaign_schedule_ids` (plural, → clones). Distinct, no conflation.

**Verdict:** ✅ Expected. F27/BC-6303 schedule_template_id rename intact at runtime.

---

**Phase 8 close:** R-17 ✅. Workspace state: 4 round-6 campaigns now provisioned with leads + senders + schedule clones (28-31). Missing only the sequence (Phase 9 next).

---

## Phase 9 — SEQUENCE

### R-18 — BC-6301 variant boolean + auto-Re: prefix (regression)

**Hypothesis:** `"variant": false` boolean; step_2.subject submitted bare; post-create stored subject has single `Re: ` prefix.

**Evidence (4 sequences created via `POST /api/campaigns/v1.1/{id}/sequence-steps`):**

| Campaign | Sequence ID | Step 1 ID | Step 2 ID | Step 1 stored subject | Step 2 stored subject |
|----------|-------------|-----------|-----------|------------------------|------------------------|
| 53 | 28 | 50 | 51 | `{Quick\|Fast\|30s} {question\|check\|idea}` | `Re: {Quick\|Fast\|30s} {question\|check\|idea}` |
| 54 | 29 | 52 | 53 | (same as 53) | `Re: ` prepended |
| 55 | 30 | 54 | 55 | (same) | `Re: ` prepended |
| 56 | 31 | 56 | 57 | (same) | `Re: ` prepended |

All 4 sequences: `variant: false` accepted on both steps; step_2 submitted bare; stored step_2 carries exactly one `Re: ` prefix (no double-prepend); step_1 unchanged.

**Verdict:** ✅ Expected. BC-6301 variant fix + auto-Re: prefix behavior intact across all 4.

### R-19 — F29/F30 + BC-6548 (wait_in_days clamp, thread_reply, UPPERCASE tokens)

**Hypothesis:** `max(1, artifact.step_1.wait_in_days)` clamp; `thread_reply` boolean per v1.1 spec; UPPERCASE-only token rule passes happy path.

**Sub-claim verification (across all 4 sequences):**

| Sub-claim | Evidence | Verdict |
|-----------|----------|---------|
| wait_in_days clamp | artifact step_1 wait=0 → sent 1 (max(1,0)) → stored 1; step_2 wait=4 → stored 4 | ✅ F29 |
| thread_reply boolean | step_1 false, step_2 true, both stored verbatim per v1.1 schema | ✅ F30 / v1.1 honored |
| UPPERCASE tokens pass | Bodies contain {RECENCY_ANCHOR}, {COMPANY}, {FIRST_NAME}, {VERTICAL_DESCRIPTOR}, {SPECIFIC_FRICTION}, {PROOF_POINT_COMPANY}, {PROOF_POINT_NUMBER}, {PROOF_POINT_TIMEFRAME}, {FREE_ASSET_NOUN}, {SENDER_FIRST_NAME} all UPPERCASE; all 4 sequences created successfully with no 422 | ✅ BC-6548 happy path |

**Verdict:** ✅ Expected. All three sub-claims verified across all 4 sequences.

---

**Phase 9 close:** R-18 ✅, R-19 ✅. Workspace state: 4 round-6 campaigns now FULLY provisioned (leads + senders + schedule + sequence) — all `status: draft`. Ready for Phase 10 PREVIEW + R-21 keystone live-fire.

---

## Phase 10 — PREVIEW

### R-20 — Mode 1 local render (regression)

**Representative lead pick:** largest cell = `role|Other` (3 leads); first lead = id 15149 `info@dogfoodtest.com` (Info Account, Operations Manager, Test Dogfood Aquarium).

**step_1.subject rendered:** `"Quick question"` (spintax first-option pick).

**step_1.body rendered (first spintax + UPPERCASE token substitution):**

> Saw the downtown master-plan announcement at Test Dogfood Aquarium Info, and it lined up with a pattern we've been watching across municipalities.\<br>\<br>Most municipalities teams we work with run into downtown lighting specs getting stuck at design review, and one that solved it was Boulder Pearl Street, who ran 38% higher evening foot traffic in 2024.\<br>\<br>Happy to pull a short architectural lighting preview for Test Dogfood Aquarium if useful, no commitment.\<br>\<br>Best,\<br>Amanuel

**5 sanity checks (regex applied to rendered output):**

| Check | Regex | Result |
|-------|-------|--------|
| No unresolved `{VARIABLE}` | `\{[A-Z_]+\}` | ✅ no matches |
| No unresolved spintax | `\{[^{}]*\|[^{}]*\}` | ✅ no matches |
| No em-dash (—) | `—` | ✅ absent |
| No `<p>` tag | `<p>` | ✅ absent (only `<br>`) |
| No `{{` double-brace | `\{\{` | ✅ absent (artifact is bare-token, not Liquid) |

**Verdict:** ✅ Expected. Mode 1 local render passes all 5 sanity checks.

### R-21 ★ — Phase 10 Mode 2 test-send (KEYSTONE + BC-7599 live-fire)

**Hypothesis:** real `--test-send corinne@britenites.com` delivers 1 email; NO `docs/marketing-context.md` required to pass IV-5.

**Evidence (`POST /api/campaigns/sequence-steps/50/test-email` body `{"sender_email_id": 981, "to_email": "corinne@britenites.com"}`):**

```json
{"success": true, "data": {"success": true, "message": "Successfuly sent sequence test email"}}
```

**Sub-claim verification:**

| Sub-claim | Evidence | Verdict |
|-----------|----------|---------|
| BC-7599 live-fire | `docs/marketing-context.md` absent in worktree; Mode 2 fired anyway | ✅ pre-fix halt path gone |
| IV-5 email regex | `corinne@britenites.com` accepted; structured-JSON body | ✅ |
| EB render pipeline triggered | `success: true` | ✅ |
| Inbox delivery + `[test] ` prefix (BC-7598) + sender resolution (BC-6784) | observable in operator inbox post-walk | ⏳ async |

**Verdict:** ✅ Expected (API layer). 4th keystone of 6 ✅ (R-A, R-B, R-8, R-21). **BC-7599 fix-validation complete at API layer.** Inbox-side observations are post-walk async.

### R-21b — BC-7598 V4 Liquid whitespace doc-claim validation

**Hypothesis:** F-Liquid-Space V4 pattern (no strip-hyphens for inline mid-sentence `{% if %}`) is documented and verified.

**Evidence:** `email-copywriting/SKILL.md:293–317` contains the BC-7598 V4 doc claim:
- Section header: "Inline Liquid: do NOT use strip-hyphens (BC-7598)"
- "Broken" vs "Correct" worked examples included
- Attribution: "Verified live, 2026-05-11, via UI Preview Body (canonical Liquid-render verification surface per BC-6785 round-5). Four variants tested; only the no-strip-hyphens form rendered correctly."

**Side-finding C (loop-close):** `docs/dogfood/bc-6554/test-copy-liquid.json:17` still uses the **broken** `{%- if -%}` strip-hyphens form. File created pre-BC-7598; not updated to V4. Either update OR add an inline comment marking it as a deliberate "broken sample." Loop-close follow-up.

**Verdict:** ✅ Expected (spec layer). BC-7598 V4 doc claim intact with live-verification attribution. Round-5 finding + 2026-05-11 PR-time live verification already covers the inline-Liquid behavior; re-firing round-6 UI verification would be redundant.

---

**Phase 10 close:** R-20 ✅, R-21 ★ ✅ (4th keystone), R-21b ✅. Workspace state: 4 fully-provisioned draft campaigns + 1 test email en route. Round-6 progress: 22/27 R-rows done (R-13 deferred). 5 R-rows remain: R-22 + R-23 ★ (Phase 11) + R-24, R-25 ★, R-26, R-27 (side-flows).










