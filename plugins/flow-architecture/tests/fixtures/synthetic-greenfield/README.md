# synthetic-greenfield fixture

Minimal greenfield project used by `run-greenfield-vslice.sh` (BC-7057) to exercise `/flow:start-project` Phase 1 surface end-to-end.

The fixture is intentionally **documentation-only at the domain level today** — the planned 3-domain × ~5-sub-flow inventory exists in this README as a target shape, not as code. The four FDA helper scripts (`flow-context-load.sh`, `flow-detect-fda-shape.sh`, `flow-detect-mode.sh`, `flow-resume-breadcrumb.sh`) only need the `package.json` + `.flow/config.json` + `docs/plans/` shell to operate; sub-skill bodies (BC-6959) will populate `docs/product/` artifacts in later runs.

## Planned inventory (target state once BC-6959 lands)

Three domains the harness expects `/flow:start-project` to produce when sub-skills exist:

1. **`assets`** — image upload, browse, edit, share, archive (5 sub-flows).
2. **`account`** — sign-in, profile, settings, billing, sign-out (3 sub-flows actively asserted; remaining 2 documentation-only).
3. **`admin`** — user roster, permissions, audit log (3 sub-flows; harness asserts 2 actively).

Total target: 3 domains × ~5 sub-flows = ~13 sub-flow stories; ≈ 60-100 discipline children once `/flow:start-project` Phase 4 scaffolds the Linear tree.

For BC-7057 v0.2.8 the harness only checks fixture **shape** + helper **behavior**, not the LLM-produced inventory or per-flow doc content.

## Build / lint / test contract

`npm run build`, `npm run lint`, `npm test` all exit 0 with no real code (echo-then-exit-0 stubs). Q8 sub-criterion 5 (build && lint && test pass on the fixture) is satisfied trivially today; the harness asserts these run cleanly under `npm` so future fixture-shape regressions surface.

## Hermetic-CI handling

`.flow/config.json` carries stub UUIDs (`00000000-0000-0000-0000-000000000000`). The harness does NOT call Linear MCP — it bypasses flow-preflight's Linear-MCP probe by setting `LINEAR_ISSUE_COUNT=0` and skipping the SKILL.md body (LLM-only anyway). No live Linear writes from CI.

## See also

- `plugins/flow-architecture/tests/run-greenfield-vslice.sh` — the harness consuming this fixture.
- `plugins/flow-architecture/tests/vslice-report.md` — coverage matrix + extension protocol.
- `plugins/flow-architecture/commands/start-project.md` — the orchestrator the harness future-tests once BC-6959 sub-skills land.
- `plugins/flow-architecture/skills/flow-preflight/SKILL.md` — `.flow/config.json` schema (Q36 7-step bootstrap output).
