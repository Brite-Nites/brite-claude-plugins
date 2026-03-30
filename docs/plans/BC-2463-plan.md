# Plan: BC-2463 — Cross-skill contract validator

**Issue**: [BC-2463](https://linear.app/brite-nites/issue/BC-2463)
**Branch**: `holden/bc-2463-cross-skill-contract-validator`
**Pattern**: Follows `scripts/test-skill-triggers.sh` (bash + embedded Python)

## Overview

Build `scripts/test-contracts.sh` that parses 6 contract blocks in `docs/workflow-spec.md` and validates them against actual skill/command files. Catches broken handoffs — the most dangerous class of inner-loop bugs.

## Contract blocks to validate

| # | Contract ID | Type | Lines | Key validation |
|---|------------|------|-------|----------------|
| 1 | `inner-loop-chain` | chain | ~1301-1400 | from/to exist, handoff connectivity |
| 2 | `artifact-registry` | registry | ~1404-1524 | producer/consumer exist |
| 3 | `post-plan-chain` | chain | ~1528-1566 | from/to exist, handoff connectivity |
| 4 | `project-start-chain` | structural | ~1570-1600 | trait values consistent |
| 5 | `context-skill-standard` | structural | ~1605-1660 | spec file exists |
| 6 | `decision-trace` | structural | ~1666-1760 | spec file + storage paths exist |

## Name resolution rules

- Skills: `plugins/workflows/skills/<name>/SKILL.md`
- Commands (e.g. `session-start`, `/workflows:review`): `plugins/workflows/commands/<name>.md` (strip `/workflows:` prefix)
- Parenthetical commands (e.g. `"ship (command)"`): extract name before ` (`, resolve as command
- `null`: terminal node, skip
- Issue references (e.g. `"BC-1944 (trait-conditional...)"`: skip (not a file)
- Parenthetical qualifiers like `"session-start (command, Step 2)"`: extract name before ` (`, resolve as command

---

## Tasks

### Task 1: Script skeleton + YAML extraction (3 min)

**Files**: `scripts/test-contracts.sh` (create)

**Steps**:
1. Create `scripts/test-contracts.sh` with shebang, `set -euo pipefail`, same helper functions as `test-skill-triggers.sh` (`pass`, `fail`, `section`)
2. Define `REPO_ROOT` and `SPEC_FILE="$REPO_ROOT/docs/workflow-spec.md"`
3. Write embedded Python that extracts text between `<!-- spec:contract:<name> -->` and the next `---` or `<!-- spec:` marker
4. Parse extracted blocks as YAML (within ```yaml fences)
5. Output JSON: `{"contract_id": "<name>", "type": "<chain|registry|structural>", "data": <parsed_yaml>}`

**Verify**:
- `bash scripts/test-contracts.sh` runs without errors and prints extracted contract names
- All 6 contracts are found: `inner-loop-chain`, `artifact-registry`, `post-plan-chain`, `project-start-chain`, `context-skill-standard`, `decision-trace`

### Task 2: Name-to-path resolution + chain file validation (3 min)

**Files**: `scripts/test-contracts.sh` (edit)

**Steps**:
1. Add Python function `resolve_name(name, repo_root)` that maps entity names to file paths using the resolution rules above
2. For chain contracts (`inner-loop-chain`, `post-plan-chain`): iterate `sequence` entries, resolve `from` and `to`, verify files exist
3. Output `PASS:<contract_id>: <from> → <to> file exists` or `FAIL:<contract_id>: <name> resolves to <path> which does not exist`

**Verify**:
- All chain `from`/`to` entries resolve and pass
- Deliberately rename a skill dir → test catches it → revert

### Task 3: Artifact registry producer/consumer validation (3 min)

**Files**: `scripts/test-contracts.sh` (edit)

**Steps**:
1. For `artifact-registry` contract: iterate `artifacts` entries
2. Resolve `producer` to file path, verify it exists
3. Resolve each entry in `consumers` list, verify each exists
4. Skip entries with issue references (e.g., `"BC-1944 (...)"`) and `"session-start (via CLAUDE.md @import)"` — these are annotations, not file references

**Verify**:
- All producers and consumers that are actual skills/commands resolve and pass
- Annotation-style references are skipped without error

### Task 4: Structural contract validation (3 min)

**Files**: `scripts/test-contracts.sh` (edit)

**Steps**:
1. For `context-skill-standard`: verify `spec` file exists (`docs/designs/BC-1966-context-skill-standard.md`)
2. For `decision-trace`: verify `spec` file exists (`docs/designs/BC-1955-decision-trace-spec.md`), verify `storage.index` path exists (`docs/precedents/INDEX.md`)
3. For `project-start-chain`: verify `valid-traits` list is non-empty (structural integrity check)
4. Print results in same PASS/FAIL format

**Verify**:
- All structural checks pass
- Delete a spec file → test catches it → revert

### Task 5: CI integration + end-to-end validation (2 min)

**Files**: `.github/workflows/validate-plugin.yml` (edit)

**Steps**:
1. Add new step after "Test skill trigger matching": `- name: Test cross-skill contracts` / `run: bash scripts/test-contracts.sh`
2. Run full validation: `bash scripts/test-contracts.sh`
3. Run existing tests to confirm no regressions: `bash scripts/validate.sh && bash scripts/test-hooks.sh && bash scripts/test-skill-triggers.sh`

**Verify**:
- `bash scripts/test-contracts.sh` passes with 0 failures
- Summary line shows total/passed/failed counts
- All other test scripts still pass
- CI workflow has the new step in correct position

---

## Acceptance criteria (from issue)

- [ ] `bash scripts/test-contracts.sh` passes with 0 failures
- [ ] CI workflow includes new step
- [ ] Deliberate break (rename a skill) → test catches it → revert
- [ ] All other tests still pass
