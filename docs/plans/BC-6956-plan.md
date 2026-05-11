# BC-6956 — flow-architecture scripts/ bash helpers

> Linear: <https://linear.app/brite-nites/issue/BC-6956>
> Branch: `holden/bc-6956-flow-architecture-implement-scripts-bash-helpers`
> Worktree: `.claude/worktrees/bc-6956-flow-architecture-scripts-bash-helpers/`
> Memory: `project_fda_plugin_interview.md` Q30.6 (line 292) + Q12.5 (line 76) + Q31.3/Q31.5 (line 306/310) + Q32 (line 344) + Q36.3 (line 357)

## Scope

Four bash helper scripts at `plugins/flow-architecture/scripts/`, names locked by Q30.6 (verbatim — do not re-derive):

1. `flow-detect-mode.sh` — emits `greenfield|retrofit|incremental-add|resume` (Q12 mode classification, filesystem-derivable signals + optional `LINEAR_ISSUE_COUNT` env hint for Q36.3 step-4 heuristic)
2. `flow-detect-fda-shape.sh` — emits presence flags for FDA artifacts (`intent.md` / inventory / flows / journeys / breadcrumb)
3. `flow-resume-breadcrumb.sh` — `read` (stale check per Q31.3) + `write` (atomic-rename + parse-verify per Q31.5) subcommands
4. `flow-context-load.sh` — orchestrates the 3 helpers + emits the Q12.5 10-field structured preamble verbatim

## Constraints (Q32 dependency surface)

- **bash 3.2+** (macOS default — Apple stopped bundling bash 4 due to GPL3). No `declare -A`, no `mapfile`, no `${var,,}`, no other bash-4-only features.
- **python3 3.6+** for JSON parse-verify (no `jq` per Q32).
- **git 2.x+** for repo-root detection.
- **gh** soft (auth check only).
- Every script: `#!/usr/bin/env bash` + `set -euo pipefail` (CLAUDE.md macOS bash 3.2 + `set -u` array-empty guard rule applies).

## Path canon (Q12.2 / Q12.4 / Q31.4)

- `docs/product/intent.md`
- `docs/product/master-flow-inventory.md`
- `docs/product/flows/INDEX.md` + `docs/product/flows/<domain>/*.md`
- `docs/product/journeys/<domain>.md`
- `docs/plans/.flow-phase-state.json` (breadcrumb)
- `.flow/config.json` (Linear config, Q36.6 atomic write)

## Tasks

### T1 — `flow-detect-mode.sh`

**Logic (filesystem-first; Linear-issue-count optional env hint per Q36.3 step 4):**

1. Resolve `REPO_ROOT` (argv `$1` or `git rev-parse --show-toplevel`).
2. Source FDA-shape signals (sub-process invoke `flow-detect-fda-shape.sh`) → `INTENT_EXISTS` / `INVENTORY_EXISTS` / `FLOWS_DIR_EXISTS` / `BREADCRUMB_EXISTS`.
3. Decision tree:
   - `BREADCRUMB_EXISTS=yes` + breadcrumb `status=in_flight` + not stale (`flow-resume-breadcrumb.sh read` → `STALE=no`) → emit `resume`
   - `INTENT_EXISTS=yes` + `INVENTORY_EXISTS=yes` + `FLOWS_DIR_EXISTS=yes` → emit `incremental-add`
   - `INTENT_EXISTS=yes` + `INVENTORY_EXISTS=yes` + `FLOWS_DIR_EXISTS=no` → emit `retrofit` (Q12 edge: intent + inventory + zero-domains-with-full-FDA)
   - No FDA artifacts:
     - If `${LINEAR_ISSUE_COUNT:-}` is set and ≥ 10 → emit `retrofit` (Q36.3 step 4 heuristic)
     - Else → emit `greenfield`

All 4 mode strings must literally appear in the script (AC grep).

### T2 — `flow-detect-fda-shape.sh`

Emit KEY=VALUE lines to stdout:

```
INTENT_EXISTS=yes|no
INVENTORY_EXISTS=yes|no
FLOWS_DIR_EXISTS=yes|no
JOURNEYS_DIR_EXISTS=yes|no
BREADCRUMB_EXISTS=yes|no
```

Path checks (all relative to `REPO_ROOT`):

| Flag | Check |
|---|---|
| `INTENT_EXISTS` | `test -f docs/product/intent.md` |
| `INVENTORY_EXISTS` | `test -f docs/product/master-flow-inventory.md` |
| `FLOWS_DIR_EXISTS` | `test -d docs/product/flows` AND directory not empty (at least one `*.md` underneath, INDEX.md counts) |
| `JOURNEYS_DIR_EXISTS` | `test -d docs/product/journeys` AND at least one `*.md` underneath |
| `BREADCRUMB_EXISTS` | `test -f docs/plans/.flow-phase-state.json` |

### T3 — `flow-resume-breadcrumb.sh`

Two subcommands.

**`read [path]`** — defaults `path` to `<REPO_ROOT>/docs/plans/.flow-phase-state.json`. Emits:

```
EXISTS=yes|no
STATUS=in_flight|completed|abandoned|unknown
LAST_UPDATED=<iso-or-empty>
STALE=yes|no
STALE_REASON=age|status-completed|status-abandoned|none
```

Stale conditions (Q31.3): `last_updated > 7 days` ago OR `status == "completed"` OR `status == "abandoned"`. Otherwise `STALE=no`.

JSON parse via python3 (no `jq`).

**`write <path>`** — reads JSON from stdin; performs Q31.5 atomic-rename + parse-verify:

1. Create `.tmp` via `mktemp "${path}.tmp.XXXXXX"` (symlink-safe; mode-600; same-dir so the subsequent `mv` is a same-FS atomic rename).
2. Write stdin to the `.tmp`.
3. python3 parse-verify the `.tmp` file (`json.load`).
4. Snapshot the `.tmp` content into `$pre`.
5. `mv` `<path>.tmp.XXXXXX` → `<path>` (atomic on same filesystem, POSIX).
6. Read back `<path>` into `$post` and assert `pre == post` (content-match). By transitivity (pre parsed as valid JSON above + `pre == post`) the post-rename file is still valid JSON, so a separate post-rename `json.load` is redundant. The content-match **detects** (does not prevent) external tampering between mv and read — on mismatch the corrupted file is left at `<path>` and exit 3 signals the caller to investigate.

On any failure: explicit `if !` checks around `mktemp`, `cat`, parse-verify, and `mv` remove `.tmp` and exit non-zero with a stderr diagnostic. `<path>` stays untouched until the `mv` succeeds.

The `cmd_read` path uses a conservative read-contract: malformed JSON, unparseable `last_updated`, and embedded newlines in `status`/`last_updated` values all soft-fail with `STALE=yes` + a specific `STALE_REASON` (rather than hard-exit), so callers fall through to artifact-driven classification instead of bricking on a single corrupted state file.

### T4 — `flow-context-load.sh`

Orchestrator. Sources the 3 helpers (sub-process invocation; resolve siblings via `$(dirname "${BASH_SOURCE[0]}")`) and emits the Q12.5 10-field preamble verbatim to stdout:

```
MODE=<mode>
LINEAR_PROJECT_ID=<id-or-empty>
LINEAR_PROJECT_NAME=<name-or-empty>
REPO_ROOT=<absolute-path>
INTENT_EXISTS=<yes|no>
INVENTORY_EXISTS=<yes|no>
FLOWS_DIR_EXISTS=<yes|no>
BREADCRUMB_EXISTS=<yes|no>
GH_AUTH=<yes|no>
LINEAR_MCP=<unknown>
```

- `LINEAR_PROJECT_ID` / `LINEAR_PROJECT_NAME`: read from `<REPO_ROOT>/.flow/config.json` via python3; empty when config absent.
- `REPO_ROOT`: `git rev-parse --show-toplevel` (argv `$1` overrides).
- `GH_AUTH`: `yes` if `gh auth status` exit code 0, else `no` (soft per Q32).
- `LINEAR_MCP=unknown`: bash can't probe MCP tooling. The orchestrator (LLM) probes via `mcp__plugin_workflows_linear-server__list_projects` and replaces this line in its own context. Sentinel `unknown` makes that hand-off explicit.

The 10 field names must literally appear in the script (AC grep).

### T5 — Plugin version bump

`plugins/flow-architecture/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` entry: 0.2.1 → 0.2.2. Same commit (BC-6000 hygiene).

## Acceptance criteria (verbatim from issue)

- 4 `test -f` checks: `flow-detect-mode.sh`, `flow-detect-fda-shape.sh`, `flow-resume-breadcrumb.sh`, `flow-context-load.sh`
- `ls plugins/flow-architecture/scripts/*.sh | wc -l` → `4`
- `grep -lE "(declare -A|mapfile|\$\{[a-zA-Z_]+,,)" plugins/flow-architecture/scripts/*.sh` → empty
- 10 separate greps in `flow-context-load.sh`: `MODE`, `LINEAR_PROJECT_ID`, `LINEAR_PROJECT_NAME`, `REPO_ROOT`, `INTENT_EXISTS`, `INVENTORY_EXISTS`, `FLOWS_DIR_EXISTS`, `BREADCRUMB_EXISTS`, `GH_AUTH`, `LINEAR_MCP`
- 4 separate greps in `flow-detect-mode.sh`: `greenfield`, `retrofit`, `incremental-add`, `resume`
- Every script: `#!/usr/bin/env bash` + `set -euo pipefail`

## Out of scope

- Bash unit tests (parking lot #54, v1.1)
- Smoke tests for command trigger resolution (parking lot #55, v1.1)
- Helper invocations from consumer skills (those land with BC-6957 / BC-6959)
- `verify-bash-compat.sh` defensive script — not in Q30.6 lock

## Re-address before starting

- ✅ `bash --version` → 3.2.57 on macOS target
- ✅ Brite bash convention (root `scripts/check-prereqs.sh` + cadence inline) confirms `#!/usr/bin/env bash` + `set -euo pipefail` + `printf` helpers
- ✅ Cadence has no `scripts/` dir — FDA pioneers the gstack pattern per Q30.6
