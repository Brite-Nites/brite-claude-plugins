# BC-10730 — Tighten flow-inventory BUILT criterion (operator-consumable)

**Linear:** [BC-10730](https://linear.app/brite-nites/issue/BC-10730)
**Branch:** `holden/bc-10730-tighten-built-criterion`
**Worktree:** `.claude/worktrees/bc-10730-built-criterion`
**Plugin:** `flow-architecture` — bump `1.2.1` → `1.2.2` (patch — rubric refinement).

## Goal

Tighten the inventory `implemented` (✓ BUILT) tag from "code exists + tests exist + sandbox URL exists" to **"an operator can consume the sub-flow through its intended surface, not merely that the API is callable."** Cite the 6 iter-3 drift corrections as dirty cases and `data-quality-migration` + `ops-hardening` as clean references.

Affects two skill files (canonical + incremental-add path) and adds one fixture + one vslice that locks the criterion mechanically.

## Out of scope (per BC brief + workstream conventions)

- Handbook page edit (`how-we-work/operating-standards/flow-driven-architecture.md`) — cross-repo PR adds session complexity; defer to a sibling BC unless the criterion edit naturally fits a 3-5 line gloss without other handbook churn.
- Parking-lot #7 (`--auto-accept-priors`) re-evaluation — documented as a trigger note inside the rubric edit, NOT promoted to a v1.2 BC inside this PR.
- BC-10729 (Q27/Q29 amendments + audit gate) — separate scope, separate PR.

## Tasks

### Task 1 — Edit `plugins/flow-architecture/skills/flow-inventory-codebase-scan/SKILL.md` § 6 (Phase 4 synthesis)

**File:** `plugins/flow-architecture/skills/flow-inventory-codebase-scan/SKILL.md`
**Section:** § 6 — Phase 4 — synthesis (retrofit-specific) → 4-tag implementation-status taxonomy table + new prose.

Edit shape:

1. Replace the `implemented` (check) row definition from "Code exists + tests exist + sandbox URL exists." → "**Operator can consume through intended surface.** Code exists + tests exist + sandbox URL exists + a user-facing entry point (page / dialog / menu item / scheduled job UI) routes to the underlying primitive. API existence alone does NOT satisfy this tag."
2. Add a new subsection § 6.1 `### BUILT criterion — operator-consumable, not just API-callable` directly under the taxonomy table. Contents:
   - The verbatim criterion sentence.
   - A worked-examples table mapping the 6 iter-3 corrections + 2 clean references to the four tags.
   - The Phase 5 confirmation-interview note (auto-accept-priors is contraindicated until drift-correction rate hits ~0).
   - The parking-lot #7 re-evaluation trigger note (verbatim from BC-10730 AC #5).
   - Cross-link to `flow-inventory-add` (same criterion mirrored there).
   - Cross-link to the fixture (`tests/fixtures/synthetic-built-criterion-drift/`).

Worked-examples table content (cite source: `docs/design-rationale/brand-hub-dogfood-findings.md` § Iter-3 cumulative outcome summary):

| Sub-flow | Inventory said | Actual surface | Correct tag |
|---|---|---|---|
| `asset-content-libraries-03` | ✓ BUILT | Anchor pointed at `CreativeToolsClient.tsx` (creative-tools library, not request pipeline) | ✗ NOT BUILT |
| `creative-operations-03` | ⚠ PARTIAL | No request-level kanban view exists | ✗ NOT BUILT |
| `creative-operations-05` | ⚠ PARTIAL | Anchor pointed at `/api/approval/route.ts` (image-level approval, not request-level QC) | ✗ NOT BUILT |
| `analytics-dashboard-01` | ✓ BUILT | API present (`/api/search-logs/dashboard`), no `.tsx` consumes it | ⚠ PARTIAL |
| `access-governance-01` | ✓ BUILT ("Clerk upgrade") | Actual code is Payload native auth + Google OAuth `beforeLogin` — planned vs current | ⚠ PARTIAL |
| `access-governance-05` | ✓ BUILT ("Feature flags") | Actually image-flagging triage; Brand Hub has no feature-flag system | ⚠ PARTIAL |
| `data-quality-migration` (6 sub-flows) | ✓ BUILT / ⚠ PARTIAL mix | All anchors verified; CLI-only patterns flagged honestly | unchanged — reference clean inventory |
| `ops-hardening` (8 sub-flows) | mix BUILT / PARTIAL / NOT BUILT | All anchors verified; Droidor-implemented sub-flows honestly tagged NOT BUILT for Brand Hub team's role | unchanged — reference clean inventory |

**Verification:** Read-after-write; grep for "operator can consume" returns ≥ 1 hit in the file; the 4-tag table's `implemented` row no longer has the old short definition.

### Task 2 — Edit `plugins/flow-architecture/skills/flow-inventory-add/SKILL.md` § 6 (User-confirmation gates)

**File:** `plugins/flow-architecture/skills/flow-inventory-add/SKILL.md`
**Section:** Insert a new § 7 `### Status-tag selection (operator-consumable criterion)` between current § 6 (User-confirmation gates) and current § 7 (Downstream regen trigger). Renumber § 7 → § 8.

Contents:

- The verbatim operator-consumable criterion (so the file is self-contained for the incremental-add path).
- A short cross-link to the canonical rubric in `flow-inventory-codebase-scan/SKILL.md` § 6.1.
- A note that `sub-flow-add` mode SHOULD apply the criterion when prompting the user for the `notes_or_status_tag` field (the incremental-add path is where drift accumulates one row at a time; no Phase 5 wholesale-confirmation safety net).
- A reference to the fixture for the worked example.

**Verification:** Read-after-write; grep for "operator can consume" returns ≥ 1 hit; § 7 of the original (Downstream regen trigger) is preserved verbatim and renumbered § 8.

### Task 3 — Create fixture `plugins/flow-architecture/tests/fixtures/synthetic-built-criterion-drift/`

**Directory tree:**

```
plugins/flow-architecture/tests/fixtures/synthetic-built-criterion-drift/
├── README.md                                                  # Documents the criterion the fixture exercises
├── docs/product/master-flow-inventory.md                      # Reference inventory with ✓-API-but-no-UI row classified ⚠ PARTIAL
└── src/app/
    ├── api/search-logs/dashboard/route.ts                     # Empty stub — API endpoint exists
    └── (frontend)/(app)/search/page.tsx                       # Decoy unrelated page (does NOT import the route)
```

**`README.md` contents (≤30 lines):**

- Names BC-10730 + the operator-consumable criterion.
- States the fixture's scenario: a sub-flow whose API route exists but has no `.tsx` consumer — mirrors `analytics-dashboard-01` from iter-3 batch 2 corrections.
- Lists the expected `implemented` (✓ BUILT) vs `partially-implemented` (⚠ PARTIAL) classification: must be ⚠ PARTIAL.
- Lists the assertions the vslice locks (file presence, no-consumer grep, inventory-row regex).
- Cross-link to `docs/design-rationale/brand-hub-dogfood-findings.md` § Iter-3 cumulative outcome.

**`master-flow-inventory.md` contents:**

- One H3 section `### \`analytics-dashboard\` — Analytics & Insights (1 flows)` (lowercase + backtick + em-dash per Q20 amendment 2).
- A 4-column table with one row: `| analytics-dashboard-01 | Search analytics dashboard | Internal ops | ⚠ partially-implemented (API present at /api/search-logs/dashboard/route.ts, no UI consumer per BC-10730 operator-consumable criterion) |`.

**`route.ts` contents (empty Next.js route handler stub, ~10 lines):**

- A no-op `GET` handler returning `{ ok: true }` so the file exists as a clear API endpoint without depending on imports.

**`page.tsx` contents (~10 lines):**

- A trivial React component that does NOT import the route — proves the absence-of-UI-consumer signal.

**Verification:** All 4 files exist; grep for `/api/search-logs/dashboard` inside `page.tsx` returns 0 matches.

### Task 4 — Add vslice `plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh`

**File:** new bash script — bash 3.2 + python3-stdlib + hermetic env per `tests/README.md` § Constraints. Structure matches `run-inventory-only-rescaffold-vslice.sh`.

Sections + assertion sketch (~12 assertions):

1. **Fixture presence (3 assertions):** README.md, master-flow-inventory.md, route.ts, page.tsx all exist.
2. **API-without-UI signal (2 assertions):** `route.ts` content matches Next.js route handler shape; grep of `/api/search-logs/dashboard` inside `.tsx` files returns 0 (no consumer).
3. **Inventory classifies as ⚠ PARTIAL (3 assertions):** inventory contains the `analytics-dashboard-01` row; row contains `partially-implemented` or `⚠ PARTIAL`; row does NOT contain `✓ implemented` or `✓ BUILT`.
4. **Rubric documents the criterion (4 assertions):** `flow-inventory-codebase-scan/SKILL.md` contains literal `operator can consume`; flow-inventory-codebase-scan SKILL.md cross-links the fixture path; `flow-inventory-add/SKILL.md` contains literal `operator can consume`; flow-inventory-add SKILL.md cross-links the canonical rubric in flow-inventory-codebase-scan.

Final line: `RESULT pass=N fail=N skip=N` (matches `test-helper-scripts.sh` contract for validate.sh hookup if it's later promoted).

**Verification:** `bash plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh` returns exit 0 with the expected pass count and no fails.

### Task 5 — Bump plugin version 1.2.1 → 1.2.2

**Files:**

1. `plugins/flow-architecture/.claude-plugin/plugin.json` → `"version": "1.2.2"`.
2. `.claude-plugin/marketplace.json` → flow-architecture entry `"version": "1.2.2"` (already located at line 38 of marketplace.json).

Per BC-6000: bump MUST be in the same commit as the SKILL.md edits.

**Verification:** `diff plugin.json marketplace.json` substring `1.2.2` matches both files.

### Task 6 — Update `plugins/flow-architecture/tests/README.md` to list the new vslice

**File:** `plugins/flow-architecture/tests/README.md` § Layout table.

Add one row after the `run-audit-smoke.sh` row:

```
| `run-built-criterion-fixture-vslice.sh` (BC-10730) | bash v-slice | Operator-consumable BUILT criterion against `fixtures/synthetic-built-criterion-drift/`. Locks the rubric tightening from BC-10730. |
```

**Verification:** Grep `BC-10730` in `tests/README.md` returns ≥ 1 hit.

## Verification (full pass)

- [ ] `bash plugins/flow-architecture/tests/run-built-criterion-fixture-vslice.sh` exits 0.
- [ ] `bash plugins/flow-architecture/tests/test-helper-scripts.sh` exits 0 (unchanged from pre-edit — defends against regression).
- [ ] `bash plugins/flow-architecture/tests/run-inventory-only-rescaffold-vslice.sh` exits 0 (unchanged).
- [ ] `bash scripts/validate.sh` exits 0.
- [ ] `grep -n "operator can consume" plugins/flow-architecture/skills/flow-inventory-codebase-scan/SKILL.md` returns ≥ 1.
- [ ] `grep -n "operator can consume" plugins/flow-architecture/skills/flow-inventory-add/SKILL.md` returns ≥ 1.
- [ ] `grep -n "1.2.2" plugins/flow-architecture/.claude-plugin/plugin.json .claude-plugin/marketplace.json` returns both files.

## Review + ship

- `/workflows:review` loop, expect 1-2 iters (skill-content + new fixture).
- Squash iter-fix commits into the version-bumping commit before push (BC-6000 discipline).
- PR title: `flow-architecture 1.2.2: tighten inventory BUILT criterion (operator-consumable)`.
- PR body: one bare `Closes BC-10730`; convert every other BC reference to markdown link.
- Pre-merge audit: `gh pr view <N> --json body --jq '.body' | sed -E 's/\[BC-[0-9]+\]\([^)]+\)//g' | grep -nE '\bBC-[0-9]+\b'` → only `Closes BC-10730` line.
- Squash-merge via `gh pr merge --squash --body-file <clean.txt>` to scrub any bare BC refs from commit messages.

## Post-merge

- Confirm BC-10730 status = Done.
- Verify these unchanged: BC-7053, BC-7054, BC-7057, BC-6000, BC-11099, BC-7713, BC-10352, BC-10728, BC-9971, BC-10729.
- Report back to tracker: PR URL + squash SHA + iter count + version-bump confirmation + fixture/vslice paths + handbook-page deferral status.
