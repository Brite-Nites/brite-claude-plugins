# BC-11890 — Make workflows pre-commit quality hook advisory (warn, never block)

**Issue:** BC-11890 (High) · Project: Brite Skill Packs · Team: Brite Company
**Branch:** `holden/bc-11890-make-workflows-pre-commit-quality-hook-advisory-warn-never`
**Worktree:** `.claude/worktrees/bc-11890` (created from `origin/main` @ `f16cfb1e`)

## Goal

Demote the workflows-plugin pre-commit quality hook from **block → warn**: it must
never emit `{"ok":false}`, must surface the linter output it currently swallows, and
must print a clear advisory header before that output. CI remains the authoritative gate.

## Key facts established during scoping

- **Stale-checkout correction:** the repo root checkout is bare and stale (at `6333eaa8`).
  `origin/main` is at `f16cfb1e` (BC-11889, PR #393, shipped today). All planning/edits
  use `origin/main` content, not the root checkout.
- **"3rd hook" is stale:** BC-11889 dropped the Haiku `type:prompt` Bash security hook, so
  the pre-commit quality hook is now the **2nd** hook in the `PreToolUse → Bash` matcher.
  Locate it by its pre-edit `statusMessage: "Running pre-commit quality checks..."`, not
  by index (this change renames that field to `"Pre-commit advisory (warn-only)..."`).
- **Current version is 3.31.0** (not 3.30.0 as the stale checkout showed). Bump from 3.31.0.
- **No existing test breaks.** `test-hooks.sh` only tests the `COMMIT_REGEX` *trigger
  detection* (unchanged) — it never asserts the hook returns `ok:false`.
  `test_pre_commit_bump.sh` tests a *different* script (`scripts/pre-commit.sh`, the
  version-bump git hook) — unrelated.
- **Hook contract:** `type:command` hook stdout MUST be the JSON verdict. So linter output
  goes to **stderr** (fd 2); only `{"ok":true}` goes to stdout.

## Tasks

### Task 1 — Rewrite the quality hook command (`plugins/workflows/hooks/hooks.json`)
The `PreToolUse → Bash` matcher's 2nd hook. Changes vs. current:
- Keep the `git commit` detection regex **identical** (`COMMIT_REGEX` — test depends on it).
- Keep the `git diff --cached` staged-file gathering + NUL-safe `printf '%b' | xargs -0`
  pattern + the `OLD_IFS=$IFS; IFS=$'\n'; … IFS=$OLD_IFS` idiom (CLAUDE.md bash-3.2 note).
- For each linter (eslint, tsc, ruff): **capture** stdout+stderr into a var; on non-zero
  exit, print a one-time advisory banner to stderr, then a `── <tool> ──` sub-label and the
  captured output to stderr. (Buffer-then-replay so the banner reliably precedes output and
  only appears on failure — satisfies "header before output" + "clean file → no advisory".)
- Drop the `errors` counter and the `{"ok":false,...}` branch entirely.
- **Always** end with `echo '{"ok":true}'`.
- Update `statusMessage` → `"Pre-commit advisory (warn-only)..."`.

Advisory banner text (generic, covers all three linters):
`⚠️  Pre-commit advisory: quality checks reported issues below (commit will proceed). Run linters locally or check CI to verify.`

Edit performed via a Python targeted-replace helper (computes JSON escaping correctly,
keeps the diff to the two changed values), then validated with `python3 -m json.tool`.

### Task 2 — Version bump (same commit, per CLAUDE.md cache-staleness rule)
- `plugins/workflows/.claude-plugin/plugin.json`: `3.31.0` → **`3.32.0`** (MINOR — behavioral
  change to a hook; mirrors BC-11889's MINOR for a comparable hook change).
- `.claude-plugin/marketplace.json` `workflows` entry: `3.31.0` → `3.32.0` (must match).

### Task 3 — Add a hermetic regression test (`scripts/test_precommit_advisory.sh`)
Locks the central invariant ("always `ok:true`") so a future edit can't silently re-block.
- Extracts the quality hook command from `hooks.json` (python3, no `jq` dependency).
- Runs it in a temp git repo with a staged JS file, using a PATH-shimmed `npx`/`eslint`
  that exits non-zero with a known error string (hermetic — no real toolchain/network).
- Asserts: **(a)** stdout == `{"ok":true}` on lint failure, **(b)** stderr contains the
  advisory banner, **(c)** stderr contains the linter output, **(d)** clean-file case →
  stdout `{"ok":true}` and **empty** stderr (no advisory).
- Wire into `scripts/validate.sh` as a new section mirroring §2c/§2d.
- `git check-ignore -v` the new file (APFS case-insensitive `.gitignore` gotcha).

### Task 4 — Validate + manual smoke
- `./scripts/validate.sh` green (incl. §2b version consistency, §2c, §2d, `lint_hooks.py`).
- Manual smoke per AC: stage a JS file with a lint error → `git commit` proceeds AND the
  ESLint error is visible; stage a clean file → no advisory text. (Run via the extracted
  hook + INPUT, the faithful reproduction of a `PreToolUse` invocation.)

## Acceptance criteria (from issue)
- [ ] Quality hook never emits `"ok":false` regardless of linter exit codes
- [ ] eslint/tsc/ruff output visible on stderr (not swallowed)
- [ ] Advisory header printed before linter output on failure
- [ ] `statusMessage` conveys non-blocking ("Pre-commit advisory (warn-only)...")
- [ ] `plugin.json` version bumped + `marketplace.json` entry matches
- [ ] `./scripts/validate.sh` passes (incl. `lint_hooks.py`)
- [ ] Manual smoke (dirty → commits + error visible; clean → no advisory)

## Out of scope
Removing linter invocations; touching `scripts/pre-commit.sh`; the BC-11752 brite-core
centralization (separate issue, comment already posted there).
