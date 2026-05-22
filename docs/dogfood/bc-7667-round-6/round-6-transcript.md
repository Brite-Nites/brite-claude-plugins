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
| R-2   | 3 VARIABLES | regression | _pending_ | |
| R-3   | 3 VARIABLES | regression | _pending_ | |
| R-4   | 3 VARIABLES | regression | _pending_ | |
| R-5   | 4 UPLOAD | regression | _pending_ | |
| R-6   | 4 UPLOAD | regression | _pending_ | |
| R-7   | 4 UPLOAD | spec-read | _pending_ | |
| R-8 ★ | 5 CAMPAIGN CREATE | regression keystone | _pending_ | |
| R-9   | 5 CAMPAIGN CREATE | regression | _pending_ | |
| R-10  | 5 CAMPAIGN CREATE | regression | _pending_ | |
| R-11  | 5 CAMPAIGN CREATE | regression | _pending_ | |
| R-12  | 6 ATTACH LEADS | regression | _pending_ | |
| R-13  | 6 ATTACH LEADS | DEFERRED | ⏭️ | per round-4/5 carryover |
| R-14  | 7 ATTACH SENDERS | regression | _pending_ | |
| R-15  | 7 ATTACH SENDERS | regression | _pending_ | |
| R-16  | 7 ATTACH SENDERS | regression | _pending_ | |
| R-17  | 8 SCHEDULE | regression | _pending_ | |
| R-18  | 9 SEQUENCE | regression | _pending_ | |
| R-19  | 9 SEQUENCE | regression | _pending_ | |
| R-20  | 10 PREVIEW | regression | _pending_ | |
| R-21 ★ | 10 PREVIEW | regression + BC-7599 live-fire | _pending_ | keystone |
| R-21b | 10 PREVIEW | BC-7598 doc-claim live-val | _pending_ | NEW |
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



