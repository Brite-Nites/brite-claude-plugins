---
flow_index: skip
last_reviewed: 2026-05-22
---

# flow-architecture/templates/

Project-side toolchain templates shipped by the `flow-architecture` plugin (BC-11029). The umbrella that started this directory: brite-roster [PR #8](https://github.com/Brite-Nites/brite-roster/pull/8) (merged 2026-05-20) — the second `/flow:retrofit-project` dogfood — had to hand-author 1,426 lines of bash + .mts because the plugin shipped the doc-tree authoring layer cleanly but not the verification toolchain. This directory closes that gap.

## Contents

```
templates/
├── scripts/
│   ├── verify-docs.sh                    # Umbrella runner (build/lint/test, links, orphans, FM, INDEX drift, freshness, Linear refs)
│   ├── regenerate-flow-index.sh          # Thin shell wrapper around the .mts
│   ├── regenerate-flow-index.mts         # Regenerates docs/product/flows/INDEX.md from front-matter
│   ├── verify-linear-references.mts      # Confirms every doc's Linear ref resolves (opt-in, requires LINEAR_API_KEY)
│   ├── normalize-fda-frontmatter.mjs     # TODO-skeleton one-shot frontmatter normalizer (populate data tables before use)
│   └── lib/
│       ├── fda-title.mts                 # FDA-issue title parser (label-hygiene gate dependency)
│       └── linear-graphql.mts            # Linear GraphQL helpers (paginate + auth)
├── .flow/
│   ├── config.json                       # Schema reference for the plugin-emitted config (NOT copied — flow-preflight owns the runtime write)
│   └── scaffold-log/
│       └── SCHEMA.md                     # Frontmatter + body schema for per-domain scaffold logs
└── README.md                             # This file
```

## How these templates land in your project

The `/flow:retrofit-project` orchestrator, during Phase 1 (preflight + bootstrap), copies these templates into your project's working tree AFTER `.flow/config.json` is written by `flow-preflight` and BEFORE the Phase 1 breadcrumb advances to Phase 2. See `commands/retrofit-project.md` § Phase 1 templates-scaffold for the orchestrator flow.

**You own the scripts after they land.** Edit them, replace them, add to them. The plugin will NOT overwrite the copies in your project on subsequent `/flow:retrofit-project` runs — unless you pass `--overwrite-scripts`. See § Idempotency below.

## Placeholders substituted at scaffold time

The orchestrator runs a sed-substitution pass against the copied files before `chmod +x`'ing the shell scripts:

| Placeholder | Substituted from | Used in |
|---|---|---|
| `<LINEAR_PROJECT_ID>` | `.flow/config.json` `linear_project_id` | `scripts/lib/linear-graphql.mts` (export `PROJECT_ID`) |
| `<LINEAR_ORG_SLUG>` | parsed from Linear project URL (`https://linear.app/<slug>/...`) | `scripts/regenerate-flow-index.mts` (`LINEAR_ORG` constant) |
| `<PROJECT_NAME>` | `.flow/config.json` `linear_project_name` | `scripts/regenerate-flow-index.mts` (`HEADER_BODY`) |
| `<EXPECTED_FDA_ISSUE_COUNT>` | `0` (default — gate disabled) | `scripts/verify-linear-references.mts` (`EXPECTED_FDA_ISSUE_COUNT`) |
| `<LINEAR_TEAM_KEY>` | `.flow/config.json` `linear_team_key` | `.flow/config.json` schema reference only |

## Idempotency

Default behavior (no flag): if any of the 9 target paths already exists in your project, the orchestrator HALTS and prints the conflict list. Re-run with `--overwrite-scripts` to replace ALL 9 files atomically.

This is intentional — the templates are starting points, not authoritative replacements. If you've customized your `scripts/verify-docs.sh` and re-run retrofit, the orchestrator will not silently erase your changes.

## Opting into the label-hygiene gate

The label-hygiene check inside `verify-linear-references.mts` (parent/child issues missing `domain:<x>` or `type:<discipline>` labels) is gated on a populated `FDA_DOMAINS` set in `scripts/lib/fda-title.mts`. Out of the box, the set is empty — the gate is a no-op. To enable:

1. Open `scripts/lib/fda-title.mts`.
2. Replace the empty `FDA_DOMAINS` set with your project's 3-letter domain codes (matching `docs/product/master-flow-inventory.md`).
3. Optionally bump `EXPECTED_FDA_ISSUE_COUNT` in `scripts/verify-linear-references.mts` to your expected parent+child count to enable the count gate.
4. Run `bash scripts/verify-docs.sh` and address findings.

## Option C migration plan (planned end-state)

The current shape (Option A) ships canonical impl in `plugins/flow-architecture/templates/` and copies into projects. The planned end-state (Option C, deferred to v1.x / v2 per Q58) ships the impl in `plugins/flow-architecture/scripts/` and installs a 6-line `scripts/verify-docs.sh` wrapper in projects that `exec`s the plugin script. The migration cost when Option C lands: each project's `scripts/verify-docs.sh` becomes a 6-line wrapper around the plugin script; bug fixes propagate via plugin version bump rather than per-project edits.

If you depend on a specific behavior of these scripts, the long-term solution is to land your improvements upstream as plugin amendments before Option C migration.

## Runtime dependencies

- `bash` (3.2+ — macOS-compatible).
- `node` (18+ recommended — for `tsx` to run the `.mts` files).
- `npx` (ships with npm).
- `gray-matter` npm package (resolved via `tsx` import; add to your `devDependencies` if not already present).

## Related

- BC-11029 — this BC (templates ship + retrofit Phase 1 integration).
- BC-6956 — plugin-internal bash helpers (`scripts/flow-*.sh`) — DIFFERENT LAYER from this directory.
- Q58 — design-rationale lock for templates + Option C migration trigger.
- Q29.7 — verify-docs.sh consumer-project-ownership framing (PRESERVED by Q58, not overridden).
