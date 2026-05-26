# synthetic-cross-domain-deps fixture

V-slice fixture set for the Q29 amendment 2 `cross-domain-deps-bidirectional`
cross-cutting gate (BC-10729). Exercises the bidirectional doc ↔ Linear
consistency contract enforced by `/flow:audit` Phase C against story-doc
`## Cross-domain dependencies` sections (Q27 amendment 1 mod 4).

Four fixtures cover the three BC-10729 § AC cases plus the FAIL_BOTH branch
the evaluator reports when both halves fail simultaneously (added per review
feedback to close a mutation-testing coverage gap):

| Fixture | Doc state | Linear state | Expected gate verdict |
|---|---|---|---|
| `pass-bidirectional/` | doc bullet `asset-unification-02 blockedBy creative-operations-01` | Linear `blockedBy` BC-10360 → BC-10371 | **PASS** — 1:1 mirror |
| `fail-doc-orphan/` | doc bullet `asset-unification-02 blockedBy ops-hardening-99` | Linear has no matching `blockedBy` | **FAIL_DOC_ORPHAN** — doc → Linear half |
| `fail-linear-orphan/` | doc has no `## Cross-domain dependencies` section | Linear has `blockedBy` BC-10360 → BC-10371 | **FAIL_LINEAR_ORPHAN** — Linear → doc half |
| `fail-both/` | doc bullet `asset-unification-02 blockedBy ops-hardening-99` (orphan) | Linear `blockedBy` BC-10360 → BC-10371 (orphan in inverse direction) | **FAIL_BOTH** — both halves fail simultaneously |

Linear state is captured as a static JSON mock under each fixture's
`.flow/linear-state-mock.json` for headless reference; the live `/flow:audit`
Phase C check reads Linear via MCP, not from this mock. The mock shape mirrors
the per-domain `list_issues({label: "domain:<slug>"})` batched response that
`linear-children-match` + `parent-l3-summary-populated` already consume —
each parent issue carries an extracted `blockedBy[]` array of other parent
issue IDs (same-domain siblings + discipline children are excluded).

## Harness

`plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh` exercises
the doc-side parse contract + the set-comparison logic. The harness:

1. Validates the doc-side regex extracts cross-domain bullets correctly from
   the PASS + FAIL_DOC_ORPHAN fixtures (FAIL_LINEAR_ORPHAN's doc has no
   section, so the regex finds 0 matches — also a valid extraction).
2. Loads the Linear-state mock JSON from each fixture.
3. Runs the bidirectional set-comparison: every doc-side `(this, blocker)`
   tuple must appear in Linear's `parents[this].blockedBy` set, and every
   Linear `(this, blocker)` tuple between FDA parents must appear in the
   doc's bullet set.
4. Asserts the verdict matches the table above per fixture.

The harness is filesystem-only (no Linear MCP access from CI). The live
`/flow:audit` Phase C check evaluates the same predicate against real
Linear state.

## See also

- Q27 amendment 1 (LOCKED 2026-05-26 per BC-10729): adds the
  `## Cross-domain dependencies` section to the story-doc template.
- Q29 amendment 2 (LOCKED 2026-05-26 per BC-10729): adds the
  `cross-domain-deps-bidirectional` cross-cutting consistency gate.
- `plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md`
  § Cross-cutting consistency gates — canonical gate enumeration.
- `plugins/flow-architecture/commands/audit.md` § Phase C — runner contract.
- `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`
  — Source-of-truth dependency graph from iter-3 dogfood.
