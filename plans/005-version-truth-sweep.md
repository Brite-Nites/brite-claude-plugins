# Plan 005: Version/metadata truth sweep — make README, ARCHITECTURE, and plugin manifests stop lying

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 04d87b12..HEAD -- README.md ARCHITECTURE.md CONTRIBUTING.md scripts/release.sh scripts/validate.sh plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
> If in-scope files changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (merge-order note: if plan 002 landed, validate.sh line numbers shifted — anchor on section names, not line numbers)
- **Category**: docs
- **Planned at**: commit `04d87b12`, 2026-07-02

## Why this matters

This repo's docs are read by Claude Code agents as instructions every session,
so wrong docs actively misdirect work. Today three surfaces disagree about the
flagship plugin's version (README says 3.24.0, the root `VERSION` file says
3.29.0, `plugins/workflows/.claude-plugin/plugin.json` says **3.41.1** — the
truth), the README's install command uses a CLI verb that doesn't exist,
its command/MCP tables are missing 5 commands and 1 server, ARCHITECTURE.md
undercounts skills, and 4 of 6 plugin manifests point `homepage`/`repository`
at a repo name that isn't the git remote. Additionally `scripts/release.sh`
crashes on stock macOS bash (uses `mapfile`, bash-4-only) — and its
single-VERSION model can no longer run at all against diverged per-plugin
versions, which is why CHANGELOG froze at 3.29.0 (2026-03-28). This plan makes
every factual claim true and applies the safe mechanical fix to release.sh; it
does NOT redesign the release process (that's a maintainer decision — see
plans/README.md "Findings awaiting decision").

## Current state

Verified facts (2026-07-02, origin/main @ 04d87b12):

- `README.md:5` — `**Current version:** 3.24.0` (truth: workflows plugin.json = 3.41.1).
- `README.md:49` — install command `claude plugins add https://github.com/Brite-Nites/brite-claude-plugins`.
  The actual CLI (per this repo's own CLAUDE.md gotcha and current Claude Code)
  is: `claude plugin marketplace add <url-or-org/repo>` then
  `claude plugin install <name>@<marketplace>`.
- `README.md` "Available Commands" tables list 21 distinct `/workflows:` commands;
  `plugins/workflows/commands/` contains 25 (+ `_shared/`). Missing rows:
  `analytics`, `audit-trail`, `flywheel-metrics`, `promote-precedent`, `report-issue`.
- `README.md:160-169` "MCP Servers" table lists exactly two servers
  (`sequential-thinking`, `linear-server`); `plugins/workflows/.mcp.json`
  registers three — the third is `gbrain-team` (stdio broker
  `scripts/gbrain-team-broker.sh` → Railway HTTP endpoint).
- `README.md` describes only the workflows plugin; the repo ships 6 plugins
  (workflows 3.41.1, marketing 0.13.9, cadence 0.6.1, revops 0.5.13,
  flow-architecture 1.2.32, brite-core 0.1.0 — versions from marketplace.json;
  re-read at execution time, they bump constantly).
- `ARCHITECTURE.md:11` — mermaid node says `22 auto-invoked skills`; actual
  count: `find plugins/workflows/skills -name SKILL.md | wc -l` → 24.
- `plugins/*/.claude-plugin/plugin.json` homepage/repository — three spellings:
  - cadence, flow-architecture, marketing, revops → `https://github.com/Brite-Nites/britenites-claude-plugins` (wrong repo name)
  - workflows → `https://github.com/brite-nites/brite-claude-plugins` (lowercase org)
  - core → `https://github.com/Brite-Nites/brite-claude-plugins` (canonical — matches `git remote -v`)
- marketplace.json vs plugin.json `description` fields diverge for
  flow-architecture and revops (validate.sh §2b compares only `version`).
- `scripts/release.sh:78` — `mapfile -t PLUGIN_JSONS < <(find ...)`; `mapfile`
  is bash-4-only, macOS stock bash is 3.2; the repo's own convention (used in
  validate.sh and pre-commit.sh) is `while IFS= read -r p; do arr+=("$p"); done < <(...)`.
- `CONTRIBUTING.md` § "Cutting a release" documents `scripts/release.sh` as the
  live process and says "Each plugin has its own version … `scripts/validate.sh`
  checks that each plugin's versions match across these two files. The
  `VERSION` file tracks the workflows plugin version. Per-plugin release
  support is tracked by BC-1728." — the first and last sentences are fine; the
  claim that `VERSION` tracks the workflows plugin is FALSE today (3.29.0 vs 3.41.1).
- Repo rule (CLAUDE.md): any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`
  requires a version bump. **plugin.json/marketplace.json metadata edits are
  the manifest itself** — bump each touched plugin's PATCH version in BOTH
  files anyway, so clients' caches pick up the corrected metadata.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Full gate | `bash scripts/validate.sh` | exit 0, `0 errors` |
| Current command inventory | `ls plugins/workflows/commands/ \| grep -v _shared \| sed 's/\.md$//'` | 25 names |
| Current skill count | `find plugins/workflows/skills -name SKILL.md \| wc -l` | 24 (re-check live) |
| Canonical remote | `git remote -v` | `Brite-Nites/brite-claude-plugins` |
| Syntax check | `bash -n scripts/release.sh` | silent |

## Scope

**In scope**:
- `README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md` (factual corrections only)
- `plugins/*/.claude-plugin/plugin.json` (homepage/repository/description + patch version bump)
- `.claude-plugin/marketplace.json` (matching version bumps + description sync)
- `scripts/release.sh` (the `mapfile` line only)
- `scripts/validate.sh` (extend §2b to also compare `description` and repo-URL equality — small, optional Step 6; skip if plan-002 conflicts loom)
- `plans/README.md` (status row)

**Out of scope**:
- Redesigning or deleting the release process / `VERSION` / `CHANGELOG.md`
  backfill (maintainer decision — DIR-2).
- Rewriting README's plugin-dev tutorial sections (only fix false claims).
- Any `plugins/*/{skills,commands,agents,hooks}` content.
- CHANGELOG.md (do not fabricate missing release entries).

## Git workflow

- **Bare-root repo**: `git worktree add <path> -b docs/version-truth-sweep origin/main`.
- Conventional commit, e.g. `docs: version/metadata truth sweep — README, ARCHITECTURE, manifests, release.sh bash-3.2 fix`.
- **Version-collision gotcha** (repo memory): before committing, `git fetch` and
  confirm each bumped version is exactly current+1 vs origin/main — parallel
  PRs bumping the same plugin collide.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: README factual fixes

- Line 5: replace the hardcoded version sentence with one that doesn't rot:
  `**Versions:** per-plugin — see [marketplace.json](.claude-plugin/marketplace.json).`
- Line 49 block: replace with the two-step real CLI (marketplace add, then
  `claude plugin install workflows@brite-claude-plugins`), and keep the
  settings.json alternative only if it matches current Claude Code docs — if
  unsure, drop it and link CONTRIBUTING.
- Commands tables: add the 5 missing commands with one-line descriptions taken
  from each command file's frontmatter `description:` (read
  `plugins/workflows/commands/<name>.md` head).
- MCP table: add the `gbrain-team` row (stdio, Bitwarden+OAuth broker, team
  knowledge base).
- Add a short "Plugins in this repo" table (6 rows: name, one-line purpose —
  source the one-liners from each plugin.json `description`, truncated) so the
  README stops implying a single-plugin repo. Do not enumerate versions here.

**Verify**: every `/workflows:<name>` in README resolves to a file:
`for c in $(grep -o '/workflows:[a-z-]*' README.md | sort -u | sed 's|/workflows:||'); do test -f plugins/workflows/commands/$c.md || echo "MISSING $c"; done` → no output.

### Step 2: ARCHITECTURE.md count fix

Line 11 (mermaid): `22 auto-invoked skills` → the live count from the command
above, phrased to rot slower: `24 auto-invoked skills` is fine (it's a diagram
label; exactness matters less than not being years stale — use the live count).

**Verify**: `grep -n "auto-invoked skills" ARCHITECTURE.md` shows the live count.

### Step 3: CONTRIBUTING.md release-section honesty

In § Versioning / "Cutting a release": replace the sentence claiming `VERSION`
tracks the workflows plugin with the observed truth, e.g.: "`VERSION` is
legacy — it froze at 3.29.0 (2026-03-28) when per-plugin versions diverged;
plugins version independently in their `plugin.json` + `marketplace.json`
(bumped per-PR). `scripts/release.sh` predates this model and currently
cannot run against diverged versions; per-plugin release support is tracked
by BC-1728." Keep the rest of the section.

**Verify**: `grep -n "3.29.0" CONTRIBUTING.md` → the new honest sentence.

### Step 4: Manifest URL + description sync + patch bumps

- Set `homepage` and `repository` in all 6 plugin.json files to
  `https://github.com/Brite-Nites/brite-claude-plugins` (byte-identical).
- For flow-architecture and revops, make marketplace.json `description` ==
  plugin.json `description` (choose the plugin.json wording — it's the richer
  one; copy it into marketplace.json).
- Bump PATCH version of every plugin.json you touched AND its marketplace.json
  entry (keep the two equal per plugin).

**Verify**: `bash scripts/validate.sh` → exit 0 (§2b version-consistency
passes); `python3 -c` one-liner comparing all six homepage fields → all equal.

### Step 5: release.sh bash-3.2 fix

Replace line 78's `mapfile -t PLUGIN_JSONS < <(find ...)` with:

```bash
PLUGIN_JSONS=()
while IFS= read -r p; do PLUGIN_JSONS+=("$p"); done < <(find "$REPO_ROOT/plugins" -name "plugin.json" -path "*/.claude-plugin/*")
```

This makes the script *parse* on bash 3.2. It will still refuse to run against
diverged versions (by design of its preflight) — that behavior stays; do not
"fix" the version check.

**Verify**: `bash -n scripts/release.sh` → silent;
`grep -c mapfile scripts/release.sh` → 0.

### Step 6 (optional — skip on any friction): extend validate.sh §2b

In the §2b python heredoc (search for `Section 2b — Version Consistency`),
extend the per-plugin check to also error when `description` differs between
plugin.json and its marketplace entry, and when any plugin.json
`homepage`/`repository` differs from the others. Follow the existing
errors-list pattern in that heredoc.

**Verify**: `bash scripts/validate.sh` → exit 0; then temporarily edit one
plugin.json description → re-run → §2b fails; revert.

### Step 7: Full gate + commit

`bash scripts/validate.sh` → exit 0. Commit per Git workflow (including the
fetch + version-collision check).

## Test plan

Step 6's negative test is the only new automated guard. The README command-
resolution loop (Step 1 verify) is the regression check for the tables; record
it in the commit message so future sweeps rerun it.

## Done criteria

- [ ] README contains no version number for the bundle; install commands use real CLI verbs; all `/workflows:` references resolve; MCP table has 3 rows; 6-plugin table present
- [ ] ARCHITECTURE.md skill count matches live count
- [ ] CONTRIBUTING release section states the observed truth
- [ ] All six plugin.json homepage/repository byte-identical and matching the git remote
- [ ] marketplace/plugin.json descriptions equal for all 6; versions equal per plugin; every touched plugin patch-bumped
- [ ] `grep -c mapfile scripts/release.sh` → 0; `bash -n` clean
- [ ] `bash scripts/validate.sh` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Live counts differ wildly from this plan's numbers (25 commands / 24 skills /
  6 plugins) — the tree has moved a lot; re-verify before writing.
- The real Claude Code CLI verbs differ from `claude plugin marketplace add` /
  `claude plugin install` in the installed CLI's `claude plugin --help` — use
  the help output as truth and note the discrepancy.
- Any plugin's marketplace vs plugin.json version is ALREADY unequal before
  your edits (someone else's collision — don't paper over it).
- You feel pulled to backfill CHANGELOG or redesign release.sh — that's DIR-2,
  explicitly out of scope.

## Maintenance notes

- The rot-resistant phrasing in Step 1 (point at marketplace.json instead of
  hardcoding) is deliberate — reviewers should reject future READMEs that
  hardcode a version.
- If DIR-2 later retires the bundle release process, CONTRIBUTING's release
  section and `VERSION`/`release.sh` get deleted together — this plan's Step 3
  wording already anticipates that.
- Step 6's §2b extension means future metadata drift fails CI — if it was
  skipped, file it as a follow-up.
