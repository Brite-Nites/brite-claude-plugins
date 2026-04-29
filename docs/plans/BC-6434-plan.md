# BC-6434 — SessionStart `command` hooks fail to fire in fresh sessions

**Linear:** [BC-6434](https://linear.app/brite-nites/issue/BC-6434)
**Branch:** `holden/bc-6434-sessionstart-command-hooks-fail-to-fire-in-fresh-claude-code`
**Plan author:** writing-plans skill, 2026-04-29

## Goal

Classify the root cause of SessionStart `command` hooks failing to fire in fresh Claude Code sessions when cwd is outside the plugin's home directory. Apply a targeted fix once classification is in. Validation: a fresh session opened in `~/Projects/work/brite-nites/brite-salesforce/` shows both the workflows `Brite Session Context` banner and the revops `RevOps Active` banner.

## Issue-vs-ground-truth reconciliation

Per BC-5806 task-3 (codify spec drift in a table at the top of the plan, grep-verifiable):

| # | Spec text (BC-6434) | Ground truth (2026-04-29) | Resolution |
|---|---|---|---|
| 1 | "neither `revops` 'RevOps Active' banner nor `cadence` '🔧 Brite Session Context' banner" | The `🔧 Brite Session Context` banner is emitted by **`workflows`**, not cadence. `find plugins/cadence -name 'hooks*'` returns no results — cadence has no hooks. The `printf '🔧 Brite Session Context\\n…'` literal lives in `plugins/workflows/hooks/hooks.json` line 67. | Investigation scope is **revops + workflows**, not 3 plugins. Fix targets both `plugins/revops/hooks/hooks.json` and `plugins/workflows/hooks/hooks.json`. |
| 2 | Hypothesis 1: 3-second timeout | revops hook `timeout: 3`, but workflows banner hook `timeout: 5` and **also** does not fire in `brite-salesforce/` cwd per BC-6425 evidence. A 5s budget should comfortably exceed any cold-start latency. | Hypothesis 1 weakened by counter-evidence on workflows. Investigation re-prioritizes: instrument first, do not bump-and-ship a timeout patch as the leading guess. |

## Investigation strategy

User-approved at brainstorm Step 5 (one question at a time):

1. **Instrument first**, classify before fixing — tee-wrap each hook command so the entry-point invocation is recorded to a logfile independent of Claude Code's session-output path.
2. **Tee-wrap shape** — the hook `command` becomes `bash $SCRIPT | tee -a /tmp/<plugin>-banner.log` (or equivalent for the inline-printf workflows banner). Stdout still flows to Claude Code; tee siphons a copy to disk. Behavior-preserving when routing works.
3. **Repro loop** — land instrumentation on the BC-6434 branch with version bumps; user runs `/reload-plugins`, opens fresh `claude` session in `~/Projects/work/brite-nites/brite-salesforce/`, types any prompt, exits, pastes log file contents back here.
4. **Version-bump sequence** — one bump per commit. Instrument bumps revops 0.2.3→0.2.4 + workflows 3.29.2→3.29.3 (and marketplace.json mirrors); the eventual fix bumps again to .5/.4.

## Classification matrix

After the user runs the repro and pastes log contents, classify based on what `/tmp/revops-banner.log` and `/tmp/workflows-banner.log` show:

| revops log | workflows log | Diagnosis | Next step |
|---|---|---|---|
| Has banner output | Has banner output | Hook **ran**, output **dropped** by Claude Code session-routing | File Claude Code upstream issue; open a separate Linear bug citing version + repro; instrumentation stays as a feature flag pending upstream fix |
| Empty / file does not exist | Empty / file does not exist | Hook **did not run** at all → registration / cwd-binding issue | Inspect plugin loader behavior; consider workaround like absolute-path commands; possible upstream issue but our config may be the cause |
| Has output | Empty | revops hook fires, workflows does not (or vice-versa) | Differential — compare the two `hooks.json` configs for what's structurally different (timeout, command shape, prompt-type sibling hooks blocking the banner step) |
| Has output but truncated mid-banner | (same) | Hook ran but timed out → bump timeout 3→10s | Apply timeout fix; ship |

## Tasks

### Task 1 — Instrument revops SessionStart hook

**File:** `plugins/revops/hooks/hooks.json`

Change the single hook's `command` field from:
```json
"command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/sfdx-banner.sh\""
```
to:
```json
"command": "{ printf '[%s] revops hook fired in cwd=%s\\n' \"$(date '+%Y-%m-%dT%H:%M:%S%z')\" \"$PWD\" >> /tmp/revops-banner.log; bash \"${CLAUDE_PLUGIN_ROOT}/hooks/sfdx-banner.sh\" | tee -a /tmp/revops-banner.log; }"
```

Rationale:
- Pre-banner timestamp+cwd line proves "hook fired at all" even in non-SFDX cwds where `sfdx-banner.sh` exits silently.
- `tee -a` siphons stdout to file while preserving routing to Claude Code session.
- Curly-brace group keeps both side-effects under the single `bash -c` the hook evaluator wraps the command in.

**Bump:** `plugins/revops/.claude-plugin/plugin.json` `0.2.3` → `0.2.4` AND `.claude-plugin/marketplace.json` line 32 `0.2.3` → `0.2.4`.

**Verification:**
```bash
./scripts/validate.sh
# Expect: hooks-lint passes, plugin.json schema passes, version drift check OK
```

### Task 2 — Instrument workflows banner hook

**File:** `plugins/workflows/hooks/hooks.json` (the SessionStart hook at lines 64-70 — the banner one, NOT the telemetry init at 73 or the Context7 instructions at 78).

Change the banner hook's `command` from `printf '🔧 Brite Session Context\\n\\n'; ...` (a single inline `printf` chain) to wrap the entire chain so its output is teed:

```json
"command": "{ printf '[%s] workflows banner hook fired in cwd=%s\\n' \"$(date '+%Y-%m-%dT%H:%M:%S%z')\" \"$PWD\" >> /tmp/workflows-banner.log; { <existing inline printf chain unchanged>; } | tee -a /tmp/workflows-banner.log; }"
```

Important: do NOT touch the other two SessionStart hooks (telemetry init, Context7 instructions). Only wrap the banner step. The other steps may have their own routing behavior worth preserving as a control.

**Bump:** `plugins/workflows/.claude-plugin/plugin.json` `3.29.2` → `3.29.3` AND `.claude-plugin/marketplace.json` line 14 `3.29.2` → `3.29.3`.

**Verification:** `./scripts/validate.sh` passes; `jq . plugins/workflows/hooks/hooks.json` re-parses cleanly.

### Task 3 — Validate + commit instrumentation

**Verification:**
```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

**Commit shape:** single commit on `holden/bc-6434-sessionstart-command-hooks-fail-to-fire-in-fresh-claude-code`, message:

> BC-6434: instrument SessionStart hooks for cwd-dependent fire diagnostics
>
> Tee-wrap revops + workflows banner hooks with timestamped /tmp logs. Bumps revops 0.2.3→0.2.4 + workflows 3.29.2→3.29.3 per BC-6000 cache-keyed-by-version rule. Diagnostic only — removed in fix commit once root cause is classified.

Push to origin so user's local plugin cache (user-scope install) can re-resolve via `/reload-plugins`.

### Task 4 — User runs repro

**Steps for user:**
1. `/reload-plugins` in this session OR exit and reopen Claude Code
2. `cd ~/Projects/work/brite-nites/brite-salesforce/`
3. `rm -f /tmp/revops-banner.log /tmp/workflows-banner.log` (wipe prior diagnostic noise)
4. `claude` (fresh session)
5. Type any prompt (e.g. `hello`), wait for response, exit
6. `cat /tmp/revops-banner.log` and `cat /tmp/workflows-banner.log` — paste contents back to me

**Expected outputs (one of these states):**
- Both files contain timestamp + banner text → routing regression
- Both files empty/missing → registration regression
- One populated, one empty → differential bug
- Truncated → timeout

### Task 5 — Classify root cause

Apply the classification matrix from earlier in this plan against the log state. Write the verdict and rationale into a new section of this plan doc titled `## Diagnosis` before moving to fix.

### Task 6 — Apply targeted fix

Branches by diagnosis:

- **Routing regression:** keep instrumentation in place (it's now a feature, not a bug — diagnostic logging surface for hook execution). File a separate Linear issue tagged with `claude-code-upstream` and a Claude Code GitHub issue with the repro. Do not remove the tee-wrap.
- **Registration regression:** investigate workaround. Most likely candidate: the `${CLAUDE_PLUGIN_ROOT}` substitution may not resolve when cwd is outside the plugin repo (untested hypothesis). Alternative invocation forms to try: hardcoded absolute path, or wrapping in `cd "${CLAUDE_PLUGIN_ROOT}" && bash hooks/sfdx-banner.sh`.
- **Differential bug:** identify the structural difference; converge the working hook's pattern into the failing one.
- **Timeout:** bump revops 3s → 10s and workflows banner 5s → 10s. Remove tee-wrap.

### Task 7 — Validate fix + bump again

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

Bump versions a second time:
- If fix touches revops only: revops 0.2.4 → 0.2.5
- If fix touches workflows only: workflows 3.29.3 → 3.29.4
- If both: bump both
- Update marketplace.json mirrors

User reruns Task 4's repro to confirm both banners now fire.

### Task 8 — Compound learnings (defer to /workflows:ship)

`compound-learnings` skill activates during ship. Likely candidates:
- New gotcha: hook execution behavior when cwd is outside plugin home directory
- Promotion-track entry on BC-5806 task-3 reconciliation-table pattern (this is the **3rd surface** — promote pattern-application 7/10 → 8/10)
- Memory entry under Gotchas if the routing/registration is platform-side and we now know its workaround

## Out of scope

- Fixing other revops-validation issues (BC-6436, BC-6437, BC-6438) — separate work
- BC-6435 brite-salesforce CLAUDE.md §170 drift — different repo
- BC-6316 eval harness — parallel work stream
- Removing the workflows banner emoji 🔧 (covered by feedback memory `feedback_no_emojis_in_generated_content.md` but not a BC-6434 concern; if Task 2 instrumentation incidentally lands a strip, fine; if not, leave for a separate small PR)

## Verification — objective criteria

| # | Test | Pass criteria |
|---|---|---|
| T1 | Instrumentation lands | `git log --oneline holden/bc-6434...main \| head -3` shows instrumentation commit; `./scripts/validate.sh` exit 0 |
| T2 | Cache-bump discipline | `grep '"version"' plugins/revops/.claude-plugin/plugin.json` returns `0.2.4` AND marketplace.json mirrors AND same-commit per `git log -1 --stat` |
| T3 | Repro produces signal | At least one of `/tmp/revops-banner.log` or `/tmp/workflows-banner.log` is populated OR explicitly empty after fresh-session run; classification matrix applies |
| T4 | Diagnosis section written | `grep '## Diagnosis' docs/plans/BC-6434-plan.md` matches before any fix commits |
| T5 | Fix verified by user re-repro | Fresh session in `brite-salesforce/` shows `RevOps Active` banner AND `Brite Session Context` banner |
| T6 | Validate + guardrails clean post-fix | `./scripts/validate.sh && ./scripts/check-guardrails.sh --claude-md CLAUDE.md` exit 0 |

## Related

- BC-6315 — RevOps Plugin Validation Phase 1 (origin)
- BC-6425 — F1 tracking issue (friction #1 = this bug)
- BC-5806 — original revops banner ship; precedent for tee-wrap perf budget + reconciliation-table pattern
- BC-6000 — same-commit version-bump rule (informs Task 1+2+3 commit shape)
