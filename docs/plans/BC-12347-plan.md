# Plan: BC-12347 + BC-12348 — RevOps forceignore pre-flight + doctor semver guard

**Issues:** BC-12347 (High) + BC-12348 (Medium), children of BC-12345
**Branch:** `BC-12347/revops-forceignore-preflight-and-doctor-semver`

## Context

Two companion guards for the revops deploy commands:

- **BC-12347**: `.forceignore` silently drops components from deploys. Add a pre-flight check that intersects the deploy set against `.forceignore` patterns and warns/halts before the dry-run. Named Credential exclusions are expected (label them); all others warn + gate.
- **BC-12348**: `/revops:doctor` only checks `sf` CLI major version == 2. CLI 2.134.x has an OAuth token-exchange bug — teammates on 2.134.x pass doctor but can't authenticate. Fix: parse full semver, gate at ≥ 2.135.7.

Both commands have `disable-model-invocation: true` and existing `<!-- eval-waiver: ... -->` annotations — no new evals required.

## Tasks

### Task 1 — BC-12348: Update doctor.md sf CLI semver check (15 min)

**File:** `plugins/revops/commands/doctor.md`
**Location:** Lines 36–43, the sf CLI probe inside the bash block.

Replace the major-only check with full semver parsing:
1. Extract `X.Y.Z` from `@salesforce/cli/X.Y.Z` in `sf --version` output using `grep -oE`
2. Compare to `2.135.7` minimum using `awk` semver comparator
3. `< 2.135.7` → `FAIL "sf CLI" "version $sf_ver is below minimum 2.135.7 (2.134.x OAuth token-exchange bug) — npm install -g @salesforce/cli@latest"`
4. `≥ 2.135.7`, major == 2 → `PASS "sf CLI" "$sf_ver"`
5. major ≠ 2 → `FAIL` (existing behavior retained)

**Verify:** Read the updated bash block and confirm the semver comparison logic is correct.

### Task 2 — BC-12347a: Add `.forceignore` pre-flight to deploy-prod.md (25 min)

**File:** `plugins/revops/commands/deploy-prod.md`
**Location:** Insert as new **Phase 1.4** between current Phase 1.3 (clean tree) and current Phase 1.4 (intent confirmation → renumbered to 1.5).

Logic:
1. Narrate: `Phase 1.4/7: .forceignore pre-flight...`
2. If deploy mode is `reconcile`: skip (user opted in to full-tree; print advisory note)
3. Compute PR-diff paths (`main~1..main`, `--diff-filter=ACMRT`, `force-app/` only) — same range as Phase 2.1 but read-only
4. If no `.forceignore` file: skip with note
5. Read `.forceignore` patterns, skip blank lines and comments
6. For each deploy path, check if it matches any pattern using bash glob/string matching
7. Separate: NC exclusions (pattern or path contains `namedCredential`) → `(expected: placeholder URLs — handled by /revops:post-deploy-runbook Phase 5)`; all others → warnings
8. If NC-only: print advisory and proceed (no gate)
9. If non-NC exclusions exist:
   - List excluded paths with remediation: `temporarily comment out the matching .forceignore line, run the deploy, then restore it`
   - Gate via `AskUserQuestion`:
     - `Continue — I've resolved the .forceignore conflict` → proceed
     - `Halt — fix .forceignore first` → halt cleanly

**Verify:** Read the inserted Phase 1.4 and confirm bash logic, gate wording, and that Phase 1.5 (intent) is correctly renumbered.

### Task 3 — BC-12347b: Add `.forceignore` pre-flight to deploy-sandbox.md (20 min)

**File:** `plugins/revops/commands/deploy-sandbox.md`
**Location:** Insert as new **Phase 1.3** after current Phase 1.2 (sandbox alias confirm).

Logic: Same as Task 2 but:
- Diff range: `${MERGE_BASE}..HEAD` (branch-diff mode) or `main~1..main` (if on main)
- Skip in `reconcile` mode
- Narrate: `Phase 1.3/6: .forceignore pre-flight...`
- Target references `brite-sandbox`

**Verify:** Read the inserted Phase 1.3 section.

### Task 4 — Bump plugin version (5 min)

**Files:**
- `plugins/revops/.claude-plugin/plugin.json`: `0.5.11` → `0.5.12`
- `.claude-plugin/marketplace.json`: revops entry `0.5.11` → `0.5.12`

**Verify:** `./scripts/validate.sh` (or at minimum the plugin version lint passes).

## Acceptance Criteria

### BC-12347
- [ ] deploy-prod + deploy-sandbox pre-flight detects deploy-set ∩ .forceignore
- [ ] Warns with excluded paths + remediation before any deploy
- [ ] NC exclusions treated as expected (labeled, not blocking)

### BC-12348
- [ ] doctor parses full semver, not just major
- [ ] `< 2.135.7` → WARN/FAIL with npm remediation
- [ ] `≥ 2.135.7` → PASS
