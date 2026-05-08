# BC-6785 — Round-5 Launch-Campaign Dogfood Transcript

**Date:** 2026-05-08 (setup) / TBD (execution)
**Workspace:** `emailbison-personal` (workspace 13 — production personal-email outbound workspace)
**Issue:** [BC-6785](https://linear.app/brite-nites/issue/BC-6785)
**Round:** 5th iteration of convergent-dogfood chain (BC-5826 → BC-5906 → BC-6308 → BC-6554 → THIS)
**Branch:** `corinne/bc-6785-bc-6554-round-5-launch-campaign-dogfood-re-walk-after-liquid`
**Plan:** `docs/plans/BC-6785-plan.md` (co-located in this worktree)
**Format:** mirrors round-4 (BC-6554) shape — full hypothesis-by-phase walk Phases 2-11, R-1 through R-28 (R-28 added at plan-gate), per-row 3-way verdict protocol, side-flow invocations + close.

---

## Header — Walk parameters

- **Leads (main walk):** 9 (round-3 verbatim — `dogfood-test-{01..06}@gmail.com|outlook.com|brite.co` + `info|sales|contact@dogfoodtest.com`).
- **Liquid leads (R-25 ★):** 3 net-new — `r5-liquid-A@britenites.com`, `r5-liquid-B@britenites.com`, `r5-liquid-C@britenites.com`.
- **Single-lead test (R-22 / R-23 ★):** `corinne+bc-6785-r5@britenites.com` (plus-addressed per Isolation Discipline).
- **Entity:** TBD at Phase 1 (likely `brite-labs` per round-4 default).
- **Preset:** list-building.
- **Offer-tier:** 2 (round-4 default).
- **Activate flag:** OFF for multiplicative-grid + side-flow campaigns; ON for single-lead test campaign only (R-23 ★, Phase 11 ACTIVATE).
- **Gate-2 choice (main walk):** "Include all" (round-4 default).
- **Walks scheduled:** 7 invocations — main multiplicative + R-9 decoy pre-create + R-25 ★ Liquid live-test + R-24 empty-default sad + R-26 lowercase-token sad + R-27 (a) `--no-host-lookup` + (b) `--no-segment` rejection + R-22 single-lead build.

## Isolation discipline (production-workspace overlay — applied to every R-row)

Workspace 13 is the production personal-email outbound workspace. Round-5 mutations are isolated for clean removal at close:

- **Lead tag**: every round-5 lead carries `bc-6785-r5`.
- **Campaign name prefix**: every round-5 campaign starts with `BC-6785 |` (sub-prefixes `MAIN`, `DECOY`, `LIQUID`, `SINGLE-LEAD`, `EMPTY-DEFAULT`, `LOWERCASE-TOKEN`, `NO-HOST-LOOKUP`).
- **No new custom variables**: R-28 sibling-endpoint probe uses existing `RECENCY_ANCHOR` (UPPERCASE-cased existing name); other R-rows must reuse the 15 perm vars only.

---

## Outcome summary (populated at close)

| Category | Count |
|---|---|
| Total R-rows (incl. R-28 added at plan-gate) | 28 |
| ✅ Expected | TBD |
| ⚠️ Unexpected | TBD |
| 🔴 Refuted / round-6 follow-up | TBD |
| ⏭️ Deferred | 1 (R-13 — BC-6545 spec-read suffices) |

**Termination decision:** TBD (zero blocking findings → terminate; ≥1 → file round-6).

---

## Inputs used

- **Main-walk CSV:** `docs/dogfood/bc-6554-round-5/test-leads.csv` — 9 leads, copied verbatim from round-3 / round-4.
- **Clean copy artifact:** `docs/dogfood/bc-6554-round-5/test-copy.json` — round-3 corrected (bare `step_2.subject` per BC-6301).
- **Liquid live-test artifact:** `docs/dogfood/bc-6554-round-5/test-copy-liquid.json` — BC-6781 rewritten with canonical `{% assign %}` form.
- **Side-flow variants (built during walk):**
  - `test-copy-empty.json` — R-24 sad-path (empty default + naked body token).
  - `test-copy-lowercase.json` — R-26 sad-path (single lowercase `{first_name}`).
  - `test-copy-naked-liquid.json` — R-25 ★ regex tightening sub-test.
  - `test-copy-single-lead.json` — R-22 single-lead Phase 11 artifact.
  - `test-leads-liquid.csv` — R-25 ★ 3-lead variant.

---

## Workspace pre-state (recorded 2026-05-08, ~11:14 MT)

### Workspace identity

| Field | Value |
|---|---|
| `instance_url` | `https://personal.outbase.so` |
| `active_workspace.id` | `13` |
| `active_workspace.name` | `BriteNites Team` |
| `active_workspace.is_primary` | `true` |
| `user.email` | `outbasepersonal-bison-api-user-for-team-2@emailbison.com` |

✅ Workspace identity confirmed = 13.

### Lead count (production background)

| Field | Value |
|---|---|
| Total leads | **14,701** (981 pages × 15/page) |
| Status of recent (id 14690-14704) | `unverified`, `tags=Google`, `emails_sent=2, opens=0, replies=0` (consistent with campaign 21's footprint) |
| First-page sample (top 3) | id 14704 `oldcampmonique@gmail.com` / id 14703 `daryarestaurantinfo@gmail.com` / id 14702 `bouvardiaburbank@gmail.com` |
| Round-5 collision check | 0 results for `dogfood-test-` and 0 for `dogfoodtest.com` (synthetic test emails are unique) |

### Campaign count (production background)

| Field | Value |
|---|---|
| Total campaigns | **21** (1 completed, 1 test-completed, 19 archived) |
| Active production campaign | id 21 — `FY26, M3 \| Restaurants & Bars America 250 \| Personal Emails \| All ESPs` (status `completed`, 1233 leads, 2433 sent, 48 replies) |
| `BC-6785` campaigns | 0 (cleanability baseline — must return to 0 at Task 13 close) |

### Permanent custom variables (cleanability baseline)

| ID | Name | Created | Source |
|---|---|---|---|
| 1 | company address | 2025-11-14 | round-1 era |
| 2 | company linkedin url | 2025-11-14 | round-1 era |
| 3 | company phone | 2025-11-14 | round-1 era |
| 4 | company website | 2025-11-14 | round-1 era |
| 5 | person job title | 2025-11-14 | round-1 era |
| 6 | person linkedin url | 2025-11-14 | round-1 era |
| 7 | recency_anchor | 2026-04-27 | round-2 |
| 8 | vertical_descriptor | 2026-04-27 | round-2 |
| 9 | specific_friction | 2026-04-27 | round-2 |
| 10 | proof_point_company | 2026-04-27 | round-2 |
| 11 | proof_point_number | 2026-04-27 | round-2 |
| 12 | proof_point_timeframe | 2026-04-27 | round-2 |
| 13 | free_asset_noun | 2026-04-27 | round-2 |
| 14 | sender_first_name | 2026-04-27 | round-2 |
| 15 | empty_test_var | 2026-05-01 | round-3 T11 |

✅ 15 entries match expected roster exactly. `meta.total: 15`, `meta.per_page: 15`, single page (Laravel pagination shape held).

### Pre-state row — 3-way verdict

> **R-pre-state output:** Workspace 13 confirmed (id=13, primary, `BriteNites Team`). Production lead count 14,701 (expected 0 per issue body); production campaign count 21 (expected 0). Custom variable roster = 15 / matches expected exactly. 0 collisions on `dogfood-test-` and `dogfoodtest.com` lead-search.
>
> **Expected per spec:** Issue body § "Workspace state at start of round-5" — "0 leads, 0 campaigns, 15 permanent custom variables."
>
> **Verdict:** ⚠️ **Unexpected (re-framed)** — issue body's "0 leads, 0 campaigns" claim was archaeological (referred to round-4 cleanup of round-4 mutations, not workspace emptiness). Operator confirmed 2026-05-08: workspace 13 is the production personal-email outbound workspace; the 14,701 leads + 21 campaigns are real production data and must remain intact. Custom variable roster matches expected and is the only workspace-state metric round-5 must hold constant.
>
> **Proposed framing:** **spec drift** — issue body (and round-4 transcript before it) propagated an inaccurate pre-state assumption. Mitigation applied at this plan-gate: Isolation Discipline overlay added to plan + transcript (lead tag `bc-6785-r5`, campaign name prefix `BC-6785 |`, no-new-custom-variables rule, plus-addressed operator email).
>
> **Recorded as ⚠️ + plan amended.** Round-5 proceeds against production-populated workspace 13 under the Isolation Discipline.

---

## R-rows (to be populated through Tasks 2-12)

### Phase 2 (multiplicative grid)

- **R-1** — ✅ **Expected.**
  - **Output:** Email-type detection: 4 personal + 2 professional + 3 role per the static lists (19 role-prefix + 12 free-mail entries; tiebreak personal-beats-role applied to no leads in this set). ESP detection via parallel `dig MX +short`: gmail.com → Google (`gmail-smtp-in.l.google.com.`), outlook.com → Microsoft (`outlook-com.olc.protection.outlook.com.`), brite.co → Google (Workspace, `aspmx.l.google.com.` + googlemail.com aliases), dogfoodtest.com → Unknown (no MX records returned) → rolled into Other in the 3-bucket grid. 9-cell grid built: Professional|Google=2, Role|Other=3, Personal|Google=2, Personal|Microsoft=2, all other 5 cells=0. F12 prune dropped the 5 empty cells (Professional|Microsoft, Professional|Other, Role|Google, Role|Microsoft, Personal|Other). 4 surviving cells.
  - **Expected per spec:** Issue body R-1 (BC-6307 + BC-6654 multiplicative segmentation): "9 leads tagged: 4 personal + 2 professional + 3 role per the 19+12 entry static lists; 9-cell grid constructed by joining email-type tags with ESP MX classification; F12 prune drops 5 empty cells."
  - **Match:** Every part — counts, cell-shape, prune behavior. No surprises.
  - **Operator gate-2 choice:** "Include all" (matches round-4; preserves multiplicative test surface for R-8★ in Task 5).

### Phase 2 — surviving 4-cell grid (post-include_all + post-F12-prune)

| | Google | Microsoft | Other |
|---|---|---|---|
| **Professional** | 2 (`dogfood-test-05/06@brite.co`) | 0 (skipped) | 0 (skipped) |
| **Role**         | 0 (skipped) | 0 (skipped) | 3 (`info|sales|contact@dogfoodtest.com`) |
| **Personal**     | 2 (`dogfood-test-01/02@gmail.com`) | 2 (`dogfood-test-03/04@outlook.com`) | 0 (skipped) |

### Phase 2 — F-IV-3 finding (outside R-1-28 set, surfaced at Phase 1 step 10)

- **F-IV-3** — ⚠️ Spec drift / regex case-sensitivity bug (round-6 candidate).
  - **What:** § Input validation IV-3 dogfood-path detection regex requires `<worktree-name>` to match `[a-z0-9._-]+` (lowercase only). Worktree convention from `git-worktrees` skill is uppercase Linear-issue-ID (`BC-6785`), which the regex rejects.
  - **Effect:** auto-detection falls through to `docs/campaigns/{entity}/` (production audit-trail directory) — actively defeats IV-3's stated intent of preventing dogfood metadata from polluting production.
  - **Mitigation for round-5:** manual override at Phase 1 step 10 — metadata written to `<worktree>/dogfood/BC-6785-2026-05-08.json` (worktree-local) per IV-3's intent.
  - **Fix size:** one-character regex change (`[a-z0-9._-]+` → `[A-Za-z0-9._-]+`).
  - **Round-6 candidacy:** if round-5 closes convergent, file as a standalone follow-up rather than triggering round-6 by itself; if round-5 files round-6 anyway, fold in.

### Phase 3 (VARIABLES)

- **R-2** — TBD
- **R-3** — TBD
- **R-4 ★** — TBD

### Phase 4 (UPLOAD)

- **R-5 ★** — TBD
- **R-28** — TBD (sibling-endpoint case-asymmetry spot-check)
- **R-6** — TBD
- **R-7** — TBD

### Phase 5 (CAMPAIGN CREATE)

- **R-8 ★** — TBD
- **R-9** — TBD
- **R-10** — TBD
- **R-11** — TBD

### Phase 6 (ATTACH LEADS)

- **R-12** — TBD
- **R-13** — ⏭️ Deferred (BC-6545 spec-read suffices; live-fire requires pre-poison setup not justified for institutional-memory-only check).

### Phase 7 (ATTACH SENDERS)

- **R-14** — TBD
- **R-15** — TBD
- **R-16** — TBD

### Phase 8 (SCHEDULE)

- **R-17** — TBD

### Phase 9 (SEQUENCE)

- **R-18** — TBD
- **R-19** — TBD

### Phase 10 (PREVIEW — first live-walk in chain)

- **R-20** — TBD
- **R-21 ★** — TBD

### Phase 11 (ACTIVATE — first live-walk in chain)

- **R-22** — TBD
- **R-23 ★** — TBD (round-5 main walk closes here)

### Side-flows

- **R-24** — TBD (BC-6556 fail-closed gate)
- **R-25 ★** — TBD (BC-6781 + BC-6782 paired Liquid live-test)
- **R-26** — TBD (BC-6548 lowercase-token sad-path)
- **R-27** — TBD ((a) `--no-host-lookup` + (b) `--no-segment` rejection)

---

## Round-5 follow-up candidates (populated at close)

TBD.

---

## Loop-closing decision (populated at close)

TBD.
