# flow-architecture tests/

Filesystem-only test surface for the FDA plugin's bash helper scripts +
their fixtures.

## Layout

| File | Type | Coverage |
|---|---|---|
| `test-helper-scripts.sh` (BC-10728) | bash unit tests | 4 helper scripts under `scripts/` — `flow-detect-mode.sh`, `flow-detect-fda-shape.sh`, `flow-resume-breadcrumb.sh`, `flow-classify-domain-state.sh`. Section 4 includes the BC-10352 regression-lock fixture (lowercase + backtick-wrap + em-dash inventory shape) per Q40 R3 promotion criterion. Wired into `scripts/validate.sh` Section 2b'. |
| `run-greenfield-vslice.sh` (BC-7057) | bash v-slice | Phase 1 surface against `fixtures/synthetic-greenfield/`. CI advisory job `vslice-greenfield`. |
| `run-inventory-only-rescaffold-vslice.sh` (BC-9971) | bash v-slice | Four-outcome classifier (`absent` / `inventory-only` / `journey-exists` / `fully-scaffolded-fs`) against `fixtures/synthetic-inventory-only-domain/` + sibling fixtures. Schema updated to Q20 amendment 2 (BC-10352) on 2026-05-22. |
| `run-audit-smoke.sh` (BC-7059) | bash smoke | `/flow:audit` phase A/B/C smoke against `fixtures/audit-clean-shape/` + `fixtures/audit-broken-shape/`. |
| `run-built-criterion-fixture-vslice.sh` (BC-10730) | bash v-slice | Operator-consumable BUILT criterion against `fixtures/synthetic-built-criterion-drift/`. Locks the rubric tightening in `flow-inventory-codebase-scan/SKILL.md` § 6.1 + `flow-inventory-add/SKILL.md` § 7. Section 4 uses a triad of catchphrase + structural-clause + negative-case greps against both SKILL.md files to defend against rubric-gutting edits. Wired into `scripts/validate.sh` Section 2b'''. |
| `run-mode-classifier-eval.sh` (BC-7059) | bash eval | Mode-classifier evaluation against `fixtures/mode-classifier-eval.json`. |
| `test-clone-drift.sh` (BC-7060) | bash regression | `scripts/check-clone-drift.sh` three-path classifier (match / trivial / substantive). |
| `test-deprecate-legacy-contracts.sh` (BC-10219) | bash contract tests | `/flow:deprecate-legacy` command markdown, `flow-legacy-cross-reference` SKILL.md flag changes, Q59 design-rationale lock. 56 assertions across 7 sections: file presence, two-pass detection logic, pre-comms gate enforcement, sub-step ordering, AskUserQuestion gates, review doc schema, cross-reference skill + Q59 integration. Wired into `scripts/validate.sh` Section 2b''''''. |
| `fixtures/` | dir | Synthetic project shapes + JSON eval datasets. |

## Constraints

- **bash 3.2 compatible** (macOS default). Per FDA parking-lot #32:
  - No bash-4-only constructs (`mapfile`, `${var,,}` lowercasing, associative arrays).
  - Guard `"${arr[@]}"` of arrays that may be empty under `set -u` (BC-6905).
- **python3 stdlib only** (FDA Q32). No `PyYAML`, no `requests`, no `jq` dep.
- **Hermetic env** — every harness `unset`s `LINEAR_ISSUE_COUNT` / `FLOW_GH_AUTH_CACHE` / `FLOW_SHAPE_CACHE` / `_FLOW_SHAPE_*` at top so parent-shell state can't influence helper behavior.
- **Tests-first discipline** (BC-10728 § AC#2): bash tests for new schema cases land BEFORE the schema fix; pre-fix run must FAIL with the regression observable.

## Per-script coverage matrix (test-helper-scripts.sh)

| Helper | Assertions | Coverage area |
|---|---|---|
| `flow-detect-fda-shape.sh` | 5 | pristine repo all-no, populated repo intent/inventory/flows yes, empty `flows/` dir → no, breadcrumb presence, invalid REPO_ROOT exit 1 |
| `flow-resume-breadcrumb.sh` | 10 | read missing → EXISTS=no, fresh in_flight → STALE=no, aged → STALE=yes+age, malformed JSON → STALE=yes+parse-error, completed status → STALE=yes+status-completed, abandoned status → STALE=yes+status-abandoned, write happy-path, write malformed → exit 3, write missing input → exit 3, usage error → exit 2 with usage message |
| `flow-detect-mode.sh` | 8 | pristine → greenfield, LINEAR_ISSUE_COUNT=42 → retrofit, =5 → greenfield, malformed count → graceful, intent+inventory → retrofit, full shape → incremental-add, fresh breadcrumb → resume, stale completed breadcrumb → fall-through |
| `flow-classify-domain-state.sh` (BC-10352 lock) | 15 | axis-1 lowercase, axis-2 backtick-wrap, axis-3 em-dash, full four-outcome cycle on iter-2 shape, UPPERCASE rejection (regex-literal-anchored), schema injection guards (underscore, leading-digit, empty, slash, space, dot-dot), missing inventory diagnostic, prefix-match defense, EOF-no-newline, bare H3 still matches, usage error |

Total: **38 assertions** (sum at runtime via `RESULT pass=N` contract line).

## Adding a new test

1. Append a new section to `test-helper-scripts.sh` with `section "N/M" "purpose"` framing.
2. Use `new_scratch` to allocate a per-test scratch dir (cleanup-on-exit trap auto-removes).
3. Use `run_capture` for stdout/stderr/exit interrogation (sets `$STDOUT`, `$STDERR`, `$EXIT`).
4. Both `pass "label"` + `fail "label …diag"` increment counters that flow into the final `RESULT pass=N fail=N` line consumed by `validate.sh` Section 2b'.
5. If the new test catches a new bug class, file a sibling Linear BC + extend Section 4 (or add a new section) so the regression is locked.

## Cross-reference

- `plugins/flow-architecture/scripts/` — the 4 helper scripts under test.
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md` § Q20 amendment 2 — the BC-10352 schema lock these tests defend.
- `scripts/validate.sh` Section 2b' — CI wiring.
- BC-10728 — the parking-lot #54 promotion that authored this harness.
- BC-10352 — the v1.1.x dogfood bug Section 4's fixture catches.
