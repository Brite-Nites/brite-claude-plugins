# BC-9027 — flow-architecture P2: security hook blocks heredoc-pipe breadcrumb write

**Linear:** [BC-9027](https://linear.app/brite-nites/issue/BC-9027) (P2, milestone "Flow-Driven Architecture Plugin v1.1")
**Fix path chosen:** (a) — refactor `flow-resume-breadcrumb.sh` to accept input-path arg; deprecate stdin.
**Plugin:** `plugins/flow-architecture/` (currently `v1.0.4` → bump to `v1.0.5`).

## Goal

Eliminate the `python3 <<'PY' | bash $HELPER write ...` pipe pattern that the workflows security-hook classifier flags as "piped download/execution". After this change, every orchestrator writes JSON to a `mktemp` file first, then calls `$HELPER write <state-path> <input-path>` — no stdin pipe to flag.

## Non-goals

- Touching the workflows plugin's security-hook allowlist (path b, declined).
- Keeping stdin as a fallback (path a with `[input-path]` optional, declined).
- Any change to the breadcrumb JSON schema, the atomic-rename + parse-verify + content-match contract, or the Q31.5 lock.

## Tasks

### T1 — Refactor helper (`scripts/flow-resume-breadcrumb.sh`)

**File:** `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh`

Change `cmd_write` signature:

- Current: `write <state-path>` reads JSON from stdin via `cat > "$tmp"`.
- New: `write <state-path> <input-path>` reads JSON by `cp -- "$input" "$tmp"` (or equivalent atomic copy). Stdin path removed entirely.
- Add input-path required-arg check; usage() updated to match.
- Comment header (lines 14-15) reworded: stdin is gone.

Preserve verbatim: mktemp staging with `${path}.tmp.XXXXXX` (symlink-attack safety), parse-verify via python3, atomic `mv`, content-match check, exit codes (0 / 2 / 3).

**Acceptance:** `bash scripts/flow-resume-breadcrumb.sh write /tmp/state.json` (missing input arg) exits 2 with usage. `bash scripts/flow-resume-breadcrumb.sh write /tmp/state.json /tmp/missing.json` exits 3 with clear error. Happy-path round-trip writes valid JSON, leaves no `.tmp` file behind.

### T2 — Update `commands/retrofit-project.md`

**Sites:**
- Line 91 (top "Resume contract" mention) — prose only, edit "pipe it through the helper" → "write JSON to a temp file then pass both paths to the helper".
- Lines 258-278 (the canonical example) — rewrite the code block:

```bash
BREADCRUMB_PATH="$REPO_ROOT/docs/plans/.flow-phase-state.json"
TMP_JSON=$(mktemp -t flow-breadcrumb.XXXXXX)
python3 > "$TMP_JSON" <<'PY'
import json, sys, datetime
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump({...}, sys.stdout)
PY
bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh" write "$BREADCRUMB_PATH" "$TMP_JSON"
rm -f "$TMP_JSON"
```

Rationale prose at line 278 stays — the `<<'PY'` is still single-quoted (shell-injection rationale unchanged). Add one sentence noting the file intermediate is what the security hook needs to stay silent.

- Line 600 ("Final breadcrumb write" narrative) — no code; ensure narrative references "file-arg helper call" rather than "pipe through helper".

### T3 — Update `commands/add-domain.md`

Same edits as T2: line 65 top mention, lines 223-227 code block + prose, line 418 final-write narrative.

### T4 — Update `commands/add-sub-flow.md`

Same edits: line 81 top mention, lines 230-234 code block + prose, line 407 final-write narrative.

### T5 — Update `commands/start-project.md`

Same edits: line 50 top mention, lines 199-203 code block + prose, line 448 final-write narrative.

### T6 — Update prose in `commands/office-hours.md` + `commands/audit.md`

- `office-hours.md:294` — replace "Construct the JSON via single-quoted python heredoc (`<<'PY'`) so user-typed strings cannot expand into the shell" with the file-intermediate pattern note (preserving the heredoc rationale).
- `audit.md:133` and `audit.md:305` — narrative mentions of `flow-resume-breadcrumb.sh write`; verify no stale stdin-pipe references; tweak if present.

### T7 — Update `tests/run-greenfield-vslice.sh`

**Site:** lines 258-283 (Section 5 of vslice).

Current pattern writes a heredoc to the helper via pipe. Migrate to:

```bash
TMP_BREADCRUMB=$(mktemp)
python3 > "$TMP_BREADCRUMB" <<'PY'
# json.dump(...)
PY
"$SCRIPTS_DIR/flow-resume-breadcrumb.sh" write "$BREADCRUMB" "$TMP_BREADCRUMB"
rm -f "$TMP_BREADCRUMB"
```

### T8 — Version bump (BC-6000 same-commit rule)

- `plugins/flow-architecture/.claude-plugin/plugin.json`: `"version": "1.0.4"` → `"1.0.5"`.
- `.claude-plugin/marketplace.json`: matching `flow-architecture` entry version bump.

Both in the same commit as the code changes per BC-6000 cache-propagation rule.

### T9 — Validate

- `./scripts/validate.sh` exits 0 (CI-equivalent, includes hook lint + plugin-install cross-check).
- `bash plugins/flow-architecture/tests/run-greenfield-vslice.sh` — Section 5 (write/read round-trip) and Section 5b (5 soft-fail paths) both PASS.
- Manual smoke: write the breadcrumb in a scratch worktree from the file-arg call — confirm the security hook stays silent (this is the original symptom).

## Risk + rollback

- **Risk:** missed call site silently uses stdin → helper fails fast with "input-path required" usage error (exit 2). Loud, not silent.
- **Rollback:** revert single commit; old stdin-pipe pattern restored. No on-disk state to migrate (the breadcrumb JSON schema is unchanged).
- **Cross-cutting:** no Q-lock amendment needed — Q31.5 lock specifies "mktemp + python3 json.dump + parse-verify + content-match" without prescribing stdin vs file-arg. The atomic-rename + parse-verify contract is preserved verbatim.

## Acceptance criteria (mirror BC-9027 AC)

1. Fresh-session `/flow:retrofit-project` Phase 1 breadcrumb write executes without security-hook intervention. *Verified by:* manual smoke (T9) — no prompt, no block.
2. `commands/retrofit-project.md:253-269` corrected to file-arg pattern. *Verified by:* T2 diff.
3. `flow-resume-breadcrumb.sh` updated to match. *Verified by:* T1 diff + `scripts/validate.sh`.
4. Plugin version bumped same-commit. *Verified by:* T8 diff + scripts/validate.sh plugin-version cross-check.

## Out of scope (separate BC follow-ups)

- BC-9026 P1 (`list_issues` project filter) — separate.
- BC-9028 P3 (AskUserQuestion one-question-per-turn) — separate.
- v1.1 milestone hardening (full quality-gate sweep) — separate.
