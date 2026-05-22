---
name: flow-preflight
description: Foundation sub-skill for the flow-architecture plugin (implements CDR-023). Runs at the start of every FDA orchestrator (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`, `/flow:audit`) to verify the environment, discover existing FDA artifacts on the filesystem, classify the run mode, confirm Linear scope (writing `.flow/config.json` on first run via the embedded Q36 7-step bootstrap), and emit the Q12.5 structured preamble that downstream sub-skills consume. Read-only EXCEPT the atomic-rename `.flow/config.json` write on first successful confirmation or stale-config replacement.
user-invocable: false
disable-model-invocation: true
allowed-tools: mcp__plugin_workflows_linear-server__list_projects, mcp__plugin_workflows_linear-server__list_teams, AskUserQuestion, Bash, Read
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q7, Q12, Q31.5, Q32, Q36"
  related-locks: "memory:60 (Q7), memory:70-78 (Q12), memory:310 (Q31.5), memory:344 (Q32), memory:346-368 (Q36), memory:370 (Q36 audit trail)"
---

# flow-preflight

Foundation sub-skill consumed by every FDA orchestrator. Verifies the environment, discovers FDA artifacts, classifies the run mode, confirms Linear scope, and emits a structured preamble for downstream sub-skills.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). It runs as the first step inside `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`, and `/flow:audit`. Sub-skills downstream (`flow-inventory-codebase-scan`, `flow-linear-scaffold`, `flow-doc-author`, `flow-journey-author`, `flow-regen-index`, ...) read this skill's preamble output rather than re-running discovery.

**Read-only contract** with two narrow exceptions, both governed by the same Q31.5 atomic-rename pattern (Section 4.4): (a) successful first-run bootstrap via Section 6 writes `.flow/config.json`; (b) stale-config detection in Path A (Section 4.1) re-enters the bootstrap and replaces `.flow/config.json` via the same atomic-rename. Nothing else mutates filesystem or Linear state.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md`. Specifically: Q12 (memory:70-78) locks the 5 responsibilities; Q31.5 (memory:310) locks the atomic-rename mechanism; Q32 (memory:344) amends Q12 with explicit dependency-version checks; Q36 (memory:346) locks the 7-step embedded bootstrap and its 6-refinement audit trail at memory:370. **DO NOT re-derive from these locks** — re-litigation already resolved at lock time.

## Helper scripts

The four bash helpers under `scripts/` (per Q30.6, shipped via BC-6956) carry the heavy lifting:

| Helper | Role |
|---|---|
| `scripts/flow-context-load.sh` | Emits the Q12.5 10-field preamble. Calls the three siblings below internally. |
| `scripts/flow-detect-fda-shape.sh` | Probes `docs/product/` for intent / inventory / flows / breadcrumb. |
| `scripts/flow-detect-mode.sh` | Classifies one of 4 modes; honours `LINEAR_ISSUE_COUNT` env var for the Q36.3 step 4 heuristic. |
| `scripts/flow-resume-breadcrumb.sh` | `read` and `write` subcommands; `write` performs Q31.5 atomic-rename + parse-verify + content-match. |

All helpers are bash 3.2+ compatible (Q32) and use `python3` 3.6+ for JSON parsing (no `jq` per Q32).

## Scope assumption (CDR-014 / CDR-023 partition)

flow-preflight assumes the consumer project is a **UI-bearing build** — the only scope FDA covers per CDR-023. Non-UI-bearing projects use CDR-014's Phase Pattern with `/workflows:fix-milestone --migrate ...`, not FDA. The orchestrators that dispatch flow-preflight (`/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`) are responsible for that upstream determination — flow-preflight does NOT re-ask "is this UI-bearing?" inside Section 6.4's mode interview. If a non-UI-bearing project reaches `/flow:start-project` by mistake, the user can cancel at the 6.5 mode-confirmation gate per Q36.5 fail-closed semantics.

---

## 1. Environment checks

Five fail-closed checks. Any failure stops orchestrator execution with a specific remediation hint.

### 1.1 Linear MCP reachable

Call `mcp__plugin_workflows_linear-server__list_projects` with `limit: 1`. Cadence Phase 0.1 precedent.

- Success → log `Linear MCP: OK`.
- Failure → stop with: `"Linear MCP unreachable. Run /workflows:smoke-test to diagnose, then /flow:<orchestrator> to retry."`

### 1.2 Repo root detected

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] || { echo "flow-preflight: REPO_ROOT not resolvable" >&2; exit 1; }
```

`scripts/flow-context-load.sh` performs the same probe internally; this check provides the early fail-closed signal before any helper invocation.

### 1.3 `docs/product/` exists OR offer to bootstrap

```bash
[ -d "$REPO_ROOT/docs/product" ] && PRODUCT_DIR_EXISTS=yes || PRODUCT_DIR_EXISTS=no
```

If `PRODUCT_DIR_EXISTS=no`, the project is pre-bootstrap. Continue into Section 6 — the embedded Q36 first-run bootstrap will create `.flow/config.json` and dispatch the chosen orchestrator, which is responsible for creating `docs/product/intent.md` (greenfield) or proposing the legacy cross-reference doc (retrofit). flow-preflight itself never creates `docs/product/`.

### 1.4 `gh` auth — soft warn

```bash
if gh auth status >/dev/null 2>&1; then
  GH_AUTH=yes
else
  GH_AUTH=no
  echo "flow-preflight: gh CLI not authenticated. \`/flow:audit\` and any post-deploy GitHub probes will skip the gh-CLI path." >&2
fi
export FLOW_GH_AUTH_CACHE="$GH_AUTH"   # passed through to flow-context-load.sh in Section 5
```

Soft-warn only — does not stop execution. Mirrors cadence Phase 0.4 pattern. `gh auth status` hits the OS keychain (~300ms cold) and on some `gh` versions performs a network call; **export `FLOW_GH_AUTH_CACHE` once here** so `flow-context-load.sh` (Section 5) reuses the result rather than re-probing — BC-6956 task-3 precedent (env-var cache passthrough; measured ~9× speedup on the helper-side, 0.464s → 0.051s).

### 1.5 Version requirements (Q32 amendment to Q12)

Q32 expanded Q12.1 with explicit dependency floors. Verify each — fail-closed if any is missing or below floor.

| Dependency | Floor | Probe |
|---|---|---|
| **bash 3.2+** | 3.2 | `bash --version | head -1` — assert major ≥ 3 (macOS default is 3.2; treat 3.0 / 3.1 as a fail). |
| **python3 3.6+** | 3.6 | `python3 --version` — assert `(major, minor) >= (3, 6)`. Required for Q31.5 JSON parse-verify and `.flow/config.json` reads. |
| **git 2.x+** | 2.0 | `git --version` — assert major ≥ 2. Required for `git rev-parse --show-toplevel` (1.7+ has it but 2.x is the documented floor). |

`jq` is **NOT** required — `python3` handles all JSON. `gh` is **soft** (1.4).

---

## 2. FDA-artifact discovery

Read-only delegation to `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-context-load.sh "$REPO_ROOT"`, which internally calls `flow-detect-fda-shape.sh`. The six artifacts probed:

1. `docs/product/intent.md`
2. `docs/product/master-flow-inventory.md`
3. `docs/product/flows/INDEX.md`
4. `docs/product/flows/<domain>/*.md` (any sub-flow story doc)
5. `docs/product/journeys/<domain>.md` (any domain journey doc)
6. `docs/plans/.flow-phase-state.json` (resume breadcrumb)

These probes are read-only and make no decisions. Their results feed Section 3 (mode classification) and Section 5 (preamble emission).

---

## 3. Mode classification

Four modes per Q12.3 + Q36.3 step 4 heuristic. Delegated to `scripts/flow-detect-mode.sh`, which honours `LINEAR_ISSUE_COUNT` if the orchestrator passes it.

| Mode | Trigger |
|---|---|
| `greenfield` | No FDA artifacts AND (no `LINEAR_ISSUE_COUNT` OR count < 10). |
| `retrofit` | Intent + inventory present but zero domains with full FDA shape (Q12 edge case); OR no FDA artifacts AND `LINEAR_ISSUE_COUNT` ≥ 10 (Q36.3 step 4 heuristic). |
| `incremental-add` | Full FDA shape present (intent + inventory + flows) AND no in-flight non-stale breadcrumb (i.e., breadcrumb absent OR stale OR completed OR abandoned — anything except in-flight + fresh, per `flow-detect-mode.sh`'s actual cascade). **Note hyphenated form** — `incremental-add` with hyphen, NOT `incremental`. |
| `resume` | In-flight breadcrumb present at `docs/plans/.flow-phase-state.json` AND not stale per Q31.3. |

### 3.1 Stale breadcrumb (Q31.3)

`scripts/flow-resume-breadcrumb.sh read` emits `STALE=yes` with a `STALE_REASON` when any of the following hold:

- `last_updated > 7 days ago` (`STALE_REASON=age`)
- `status == "completed"` (`STALE_REASON=status-completed`)
- `status == "abandoned"` (`STALE_REASON=status-abandoned`)
- malformed JSON (`STALE_REASON=parse-error`) or unparseable timestamp (`STALE_REASON=timestamp-unparseable`) — soft-fail per BC-6956 task-1 precedent

When stale, prompt via `AskUserQuestion`:

```
Found a {STALE_REASON} resume breadcrumb at docs/plans/.flow-phase-state.json. How should I proceed?
  - Discard breadcrumb + start fresh (Recommended)
  - Force-resume (override staleness)
  - Cancel
```

User picks → discard re-runs mode classification with breadcrumb signals removed; force-resume drops through to `resume` mode; cancel exits cleanly.

**The user-confirmation step in Section 6 step 5 is the authoritative mode signal** — the heuristic-derived mode here is tentative and may be overridden by user input.

---

## 4. Linear scope confirmation

Two paths depending on whether `.flow/config.json` exists.

### 4.1 Path A — config exists (already-bootstrapped)

Consume `LINEAR_PROJECT_ID` and `LINEAR_PROJECT_NAME` directly from Section 5's preamble — `flow-context-load.sh` already parses `.flow/config.json` and emits both fields when the file exists. **Do not re-read `.flow/config.json`** in Path A; the preamble is the canonical exposure.

Validate `LINEAR_PROJECT_ID` still resolves by calling `mcp__plugin_workflows_linear-server__list_projects` with a `query` filter scoped to the cached `LINEAR_PROJECT_NAME` (cheap; bounded to a few results) and matching against the cached `LINEAR_PROJECT_ID`. If the project ID no longer resolves (deleted, archived, or moved teams), warn the user and re-prompt via Path B's bootstrap flow — the new config write replaces the stale one via Q31.5 atomic-rename (same pattern as first-run; the read-only contract carves out **either** first-run write **or** stale-config replacement, both governed by Section 4.4). Skip the user gate when fresh.

### 4.2 Path B — config absent (first-run)

Dispatch into Section 6 (Q36.3 7-step bootstrap). After the bootstrap completes successfully, `.flow/config.json` exists and Path A's checks pass on the next run.

### 4.3 v1 schema (5 fields, per Q12.4)

```json
{
  "linear_project_id": "<uuid from list_projects>",
  "linear_project_name": "<string>",
  "linear_team_key": "<e.g., BC for Brite Company>",
  "fda_first_setup_at": "<ISO-8601 timestamp at first successful confirmation>",
  "fda_plugin_version": "<read from $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json>"
}
```

Parking-lot fields deferred to v1.1+ per Q12.4: `preferred_mode_override`, `app_classifier_cache`, `last_inventory_regen_at`, `linear_team_id` (UUID).

### 4.4 Atomic write (Q31.5 atomic-rename)

Mirror `scripts/flow-resume-breadcrumb.sh`'s `cmd_write` contract exactly. Build the JSON with `python3 json.dump()` (never a shell heredoc — `PROJECT_NAME` etc. come from Linear and may contain `"`, `\`, newlines, or control bytes), parse-verify **before** `mv`, content-match **after** `mv`. Pass values via env, not argv, to keep them off the process listing:

```bash
mkdir -p "$REPO_ROOT/.flow"
DEST="$REPO_ROOT/.flow/config.json"

# mktemp: mode 600 + O_EXCL via the XXXXXX suffix; same-dir for atomic mv.
if ! TMP="$(mktemp "$DEST.tmp.XXXXXX")"; then
  echo "flow-preflight: mktemp failed for $DEST" >&2
  exit 3
fi

# Build the JSON with python3 — never a shell heredoc. json.dump escapes
# user-controlled strings; env-passed values stay off the process listing.
if ! PROJECT_ID="$PROJECT_ID" PROJECT_NAME="$PROJECT_NAME" \
     TEAM_KEY="$TEAM_KEY" NOW_ISO="$NOW_ISO" \
     PLUGIN_VERSION="$PLUGIN_VERSION" \
     python3 - "$TMP" <<'PY'
import json, os, sys
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump({
        "linear_project_id":   os.environ["PROJECT_ID"],
        "linear_project_name": os.environ["PROJECT_NAME"],
        "linear_team_key":     os.environ["TEAM_KEY"],
        "fda_first_setup_at":  os.environ["NOW_ISO"],
        "fda_plugin_version":  os.environ["PLUGIN_VERSION"],
    }, fh, indent=2)
PY
then
  rm -f "$TMP"
  echo "flow-preflight: json.dump failed for $DEST" >&2
  exit 3
fi

# Parse-verify BEFORE atomic mv — if the file we just wrote isn't valid
# JSON for any reason, never clobber the existing config.
if ! python3 - "$TMP" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    json.load(fh)
PY
then
  rm -f "$TMP"
  echo "flow-preflight: parse-verify failed for $DEST" >&2
  exit 3
fi

# Snapshot tmp content for the post-rename content-match check.
PRE="$(cat "$TMP")"

# Atomic rename — POSIX-guaranteed on same filesystem.
if ! mv "$TMP" "$DEST"; then
  rm -f "$TMP"
  echo "flow-preflight: mv failed for $DEST" >&2
  exit 3
fi

# Content-match DETECTS (does not prevent) external tampering between
# mv and read. By transitivity with the pre-mv parse-verify, the post-
# rename file is valid JSON — no separate post-rename json.load needed.
POST="$(cat "$DEST")"
if [ "$PRE" != "$POST" ]; then
  echo "flow-preflight: content-match detected pre ≠ post-rename for $DEST" >&2
  exit 3
fi
```

Reference implementation: see `scripts/flow-resume-breadcrumb.sh`'s `cmd_write` function — the explicit-if-checks style (rather than `trap`) is the canonical Q31.5 cleanup contract (BC-6956 task-1 precedent: "explicit if-checks keep failure modes auditable; preferred over a trap, which would obscure which step triggered the abort"). Atomic-rename guarantees `.flow/config.json` is either absent or fully populated — never partial. The `mktemp "$DEST.tmp.XXXXXX"` form with same-directory placement makes the temp file symlink-safe (mode 600 + O_EXCL + unique suffix).

**Threat-model caveat — destination symlink:** the temp file is symlink-safe, but the destination `.flow/config.json` is not pre-checked for symlinkness. A local attacker who already has write access to `.flow/` could pre-stage a symlink redirecting the `mv` outside the repo. This is consistent with the reference impl (`flow-resume-breadcrumb.sh` does not pre-check either) and is dominated by the larger surface a local attacker with `.flow/` write access already has. Not a v1 blocker; tracked as a defense-in-depth candidate for v1.1 if a real incident surfaces.

---

## 5. Output structured preamble

Invoke the helper and echo the 10-field preamble verbatim into the LLM context (gstack pattern per Q12.5):

```bash
LINEAR_ISSUE_COUNT="${LINEAR_ISSUE_COUNT:-}" \
  bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-context-load.sh" "$REPO_ROOT"
```

Expected output — one `KEY=VALUE` line per field, exactly 10:

```
MODE=greenfield|retrofit|incremental-add|resume
LINEAR_PROJECT_ID=<uuid from .flow/config.json, empty when config absent>
LINEAR_PROJECT_NAME=<string from .flow/config.json, empty when config absent>
REPO_ROOT=<absolute path>
INTENT_EXISTS=yes|no
INVENTORY_EXISTS=yes|no
FLOWS_DIR_EXISTS=yes|no
BREADCRUMB_EXISTS=yes|no
GH_AUTH=yes|no
LINEAR_MCP=unknown
```

`LINEAR_MCP` is emitted as `unknown` by the helper — the orchestrator probes Linear connectivity itself (Section 1.1) and replaces this line in its own context with `LINEAR_MCP=yes` or `LINEAR_MCP=no` based on the probe outcome. This split keeps the bash helper offline-runnable.

Downstream sub-skills (`flow-inventory-codebase-scan`, `flow-linear-scaffold`, `flow-doc-author`, `flow-journey-author`, `flow-regen-index`, `flow-legacy-cross-reference`) read this preamble and **must not re-run discovery** — Q12.5's whole point is one probe per orchestrator run.

---

## 6. First-run bootstrap (per-project)

Embedded per Q36.6 user lock — bootstrap lives **inside** flow-preflight, not as a dedicated `flow-bootstrap` sub-skill. v1.1 may refactor to dedicated if Section 6 grows unwieldy (parking lot #34).

**Scope:** per-project first-run only. Per-org bootstrap (CDR-023 + operating-standards page + about-handbook PRs) is parked at parking lot #33; FDA maintainers handle org-level setup manually until v1.1+.

**Trigger:** Section 4.2 — `.flow/config.json` is absent.

### 6.1 — Welcome message

Emit a one-paragraph welcome explaining bootstrap scope:

> "I'll set up `.flow/config.json` for this project, ask which Linear project this maps to, figure out greenfield-scaffold vs retrofit existing work vs incremental-add to an existing FDA shape, and hand off to the right `/flow:` orchestrator. This is a one-time per-project setup."

### 6.2 — _(Reserved — see 6.3a/3b for the Linear two-step.)_

Q36.3 originally had step 2 reserved during drafting; the audit trail (memory:370 refinement 2) split the original step 3 into 3a/3b. The reservation is preserved here verbatim per Q36 lock to keep the step numbering aligned with the design-rationale memory.

### 6.3a — Linear project resolution

Call `mcp__plugin_workflows_linear-server__list_projects` (`orderBy: updatedAt`, no team filter — Brite operates one team `BC` in v1; cross-team support is a v1.1 candidate). Take the top 3-4 most-recently-active projects. Present via `AskUserQuestion`:

```
Which Linear project does this repo correspond to?
  - <project_name_1> (Recommended — most recently updated)
  - <project_name_2>
  - <project_name_3>
  - <project_name_4>
  - Other (search)
```

If the user picks "Other (search)", run a follow-up `AskUserQuestion` taking a free-text query and pass it to `list_projects` `query` filter; present up to 4 matches.

Capture from the chosen project:
- `project_id` (uuid)
- `project_name` (string)
- `team_id` (uuid; from `project.teams[0].id` in the response)

### 6.3b — Team fetch

`list_projects` does **NOT** include `team_key` natively — verified at Q36 lock against `plugins/cadence/commands/weekly.md`. A separate `list_teams` lookup is required.

Call `mcp__plugin_workflows_linear-server__list_teams` once and cache for the session (cadence Phase 0 precedent). Match against `team_id` from 6.3a; extract `team_key` (e.g., `BC` for Brite Company).

### 6.4 — Mode classification interview

Combine Q12 FDA-artifact discovery (consume directly from the **Section 5 preamble** — `INTENT_EXISTS` / `INVENTORY_EXISTS` / `FLOWS_DIR_EXISTS` / `BREADCRUMB_EXISTS`; do NOT re-invoke the detect helpers here, per BC-6956 task-3's `FLOW_SHAPE_CACHE` env-var passthrough discipline) with the Q36.3 step 4 `LINEAR_ISSUE_COUNT` heuristic. Concrete recommendation logic:

| Signal | Recommended mode |
|---|---|
| No FDA artifacts AND `LINEAR_ISSUE_COUNT` < 10 (or unset) | `greenfield` |
| No FDA artifacts AND `LINEAR_ISSUE_COUNT` ≥ 10 | `retrofit` |
| FDA artifacts present AND in-flight breadcrumb | `resume` |
| FDA artifacts present AND no in-flight non-stale breadcrumb (absent / stale / completed / abandoned) | `incremental-add` |

The 10-issue threshold is **heuristic**. The user confirmation in step 6.5 is the authoritative signal, not the threshold.

**Ownership note for `LINEAR_ISSUE_COUNT`:** the **orchestrator** (not flow-preflight) is responsible for computing the count via the Linear MCP and passing the result in via env var before invoking flow-preflight. `list_issues` is intentionally absent from this skill's `allowed-tools` — if the env var is unset at runtime, flow-preflight treats it as 0 and degrades to `greenfield` (correct for empty projects). The threshold IS the cap (count of exactly 10 means "≥ 10"; counting the full backlog is wasteful when the heuristic only needs to distinguish "< 10" from "≥ 10") — that's the only contract this skill depends on. The MCP-call signature is the orchestrator's concern: see `commands/retrofit-project.md` Phase 1 pre-preflight setup for the live implementation, which works around the broken `list_issues project:` filter (`gotcha_linear_list_issues_project_filter`, BC-9026).

### 6.5 — Mode confirmation (authoritative signal)

`AskUserQuestion`:

```
Recommended: <mode>. Confirm or override?
  - Confirm <mode>
  - Override → pick a different mode
  - Cancel
```

If "Override" is picked, follow up with a four-option `AskUserQuestion` listing the 4 modes (greenfield / retrofit / incremental-add / resume) and let the user choose. The chosen mode supersedes the heuristic recommendation.

### 6.6 — Atomic config write

Apply Section 4.4's atomic-rename pattern with the 5 v1 fields. Concrete values:

| Field | Source |
|---|---|
| `linear_project_id` | 6.3a `project_id` |
| `linear_project_name` | 6.3a `project_name` |
| `linear_team_key` | 6.3b `team_key` |
| `fda_first_setup_at` | `date -u +%Y-%m-%dT%H:%M:%SZ` (ISO-8601 UTC) |
| `fda_plugin_version` | `python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"` per Q36.4 |

### 6.7 — Dispatch to chosen orchestrator

Hand off cleanly based on the confirmed mode:

| Mode | Hand-off |
|---|---|
| `greenfield` | Suggest `/flow:start-project`. |
| `retrofit` | Suggest `/flow:retrofit-project`. |
| `incremental-add` | Suggest `/flow:add-domain` (new domain milestone) or `/flow:add-sub-flow` (new sub-flow under existing domain). Ask the user which scope. |
| `resume` | Re-emit the preamble with `MODE=resume`; the calling orchestrator owns breadcrumb consumption. |

flow-preflight exits cleanly after the suggestion — orchestrator dispatch is the caller's responsibility.

### 6.8 — Failure / cancellation (Q36.5)

**Fail-closed; no partial state on disk.** Precise per-failure behaviour:

- User cancels at any `AskUserQuestion` (6.3a / 6.3b / 6.5 / sub-prompt) → exit cleanly; **don't write `.flow/config.json`**; project remains pre-bootstrap. Re-running `/flow:<orchestrator>` re-enters Section 6 from the top.
- Linear API error (`list_projects` / `list_teams` non-200, or auth failure) → surface error verbatim; suggest `/workflows:smoke-test` then `/flow:<orchestrator>` re-run.
- Filesystem write failure (out-of-disk, EACCES on `.flow/`, mktemp failure) → surface error; the explicit `if ! …; then rm -f "$TMP"; exit 3; fi` cleanup checks in Section 4.4 ensure no `.tmp.XXXXXX` debris is left behind. Atomic-rename + parse-verify (Q31.5) means `.flow/config.json` is either absent or fully populated — never partial.

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` — canonical 2,306-line interview record. Q12 / Q31.5 / Q32 / Q36 are the locks this skill implements.
- `docs/design-rationale/fda-plugin-architecture-overview.md` — synthesis overview (reading aid).
- `plugins/flow-architecture/scripts/` — the four BC-6956 helpers this skill orchestrates.
- `plugins/flow-architecture/CONTRIBUTING.md` — plugin-specific conventions (bash 3.2 floor, empty `.mcp.json`, source-of-truth pointer).
- `plugins/cadence/commands/weekly.md` § Phase 0 + § 0.5 — precedent for fail-closed preflight + breadcrumb resume + AskUserQuestion gating.
- Handbook CDR-023 — Flow-Driven Architecture (the policy this plugin implements; Q33 lock in the interview record links the canonical handbook path).
