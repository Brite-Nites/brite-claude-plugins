# BC-6434 — SessionStart `command` hooks fail to fire in fresh sessions

**Linear:** [BC-6434](https://linear.app/brite-nites/issue/BC-6434)
**Branch:** `holden/bc-6434-sessionstart-command-hooks-fail-to-fire-in-fresh-claude-code`
**Plan author:** writing-plans skill, 2026-04-29

## Goal

Classify the root cause of SessionStart `command` hooks failing to fire in fresh Claude Code sessions when cwd is outside the plugin's home directory. Apply a targeted fix once classification is in. Validation (original): a fresh session opened in `~/Projects/work/brite-nites/brite-salesforce/` shows both the workflows `Brite Session Context` banner and the revops `RevOps Active` banner.

**Outcome (post-diagnosis):** Goal redefined. The original "show banner" criterion is unreachable from `hooks.json` alone — see `## Diagnosis` for the upstream UI regression (Claude Code [#24425](https://github.com/anthropics/claude-code/issues/24425)). Achievable goal becomes: classification + upstream issue cite + CLAUDE.md gotcha + Linear update.

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

> **Note:** Tasks 1–7 below describe the instrumentation→repro→classify→fix loop that ran on 2026-04-29. Path A revert was selected after Task 5 — see `## Diagnosis`. This section is reference-only history of the executed loop.

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
- Reconciliation-table pattern: BC-6434 is an additional surface for the issue-vs-ground-truth amendments-table track that reached architecture-9 at BC-2717 (chain BC-5947 → BC-5806 → BC-5832 → BC-2717, with BC-5906 reaffirming). Treat as durability evidence at architecture-9, not a promotion candidate. BC-6434's specific shape — hypothesis-vs-evidence diagnosis — is a subtle variant of spec-vs-ground-truth and may warrant a separate sub-pattern note if a 2nd instance of the diagnosis-table shape appears.
- Memory entry under Gotchas if the routing/registration is platform-side and we now know its workaround

## Diagnosis

Repro run 2026-04-29 17:10 in `cwd=~/Projects/work/brite-nites/brite-salesforce/`. Two fresh `claude` invocations produced four log entries (each session fires the `SessionStart:startup` hook twice, ~22s apart — `17:10:30` and `17:10:52`).

### Evidence collected

| Layer | Status | Evidence |
|---|---|---|
| Hook fires when cwd ≠ plugin home | ✅ | `/tmp/revops-banner.log` and `/tmp/workflows-banner.log` populated with timestamp + cwd lines after fresh session in `brite-salesforce/` |
| Script execution + stdout | ✅ | Both logs contain full banner content (`RevOps Active` + `🔧 Brite Session Context`) |
| Hook stdout reaches model context (skill activation works) | ✅ | Fresh session reproduced both reminders verbatim when asked: `SessionStart:startup hook success: RevOps Active …` and `SessionStart:startup hook success: 🔧 Brite Session Context …`. Skill activation independently proven in [BC-6315](https://linear.app/brite-nites/issue/BC-6315) Phase 1 (5/5 fixtures activated correct skills in same cwd). |
| **Visible terminal block above first prompt** | ❌ | Splash → `❯ hello` with no banner block in between, in v2.1.123 |

### Root cause

Claude Code v2.1.123 (and likely earlier in the v2.1.x line; precise window pinned by upstream issue) no longer renders `SessionStart` `command`-type hook stdout as a visible terminal block. Hook stdout is routed only to the model's `<system-reminder>` channel. Tracked upstream as [anthropics/claude-code#24425](https://github.com/anthropics/claude-code/issues/24425).

This is a **platform behavior**, not a config issue. Documented (post-research, agent-confirmed via Anthropic docs) as the intentional designed channel: hooks → model context. Anthropic's recommended channel for **user-visible** session context in current v2.1.x is the **statusline** (`statusLine` setting in `settings.json`) or a user-invoked **slash command** — neither of which is what the original BC-6434 issue asked for.

### Hypothesis disposition

| # | Hypothesis (per BC-6434 issue body) | Verdict |
|---|---|---|
| 1 | 3-second timeout on cold session | **Rejected.** revops `timeout: 3` AND workflows `timeout: 5` both fire successfully and produce full banner stdout (logs prove it). |
| 2 | Claude Code v2.1.123 routing regression | **Confirmed (with refinement).** Routing still reaches the model — only the user-visible terminal block is gone. Confirmed by upstream issue #24425. |
| 3 | Hook registration when cwd ≠ plugin root | **Rejected.** `/reload-plugins` reports 14 hooks; logs prove invocation in non-plugin cwd. |

### Severity reclassification

Original issue priority: **High** (advertised UX entry point degrades to "user has to know command exists"). Post-diagnosis: **Low–Medium**. The agentic UX is fully intact — Claude has the banner content via system-reminder, skills activate, commands are discoverable to the model. The only loss is human-visible signaling, which has documented alternative channels (statusline, slash commands) for plugin authors who want to invest.

### Resolution path chosen

Path A from the brainstorm gate: revert instrumentation, accept the diagnosis, file upstream. Bump versions per BC-6000 same-commit rule. Update Linear BC-6434 with diagnosis + downgrade priority. Add CLAUDE.md gotcha. Add comment to upstream issue #24425 with our repro evidence.

Path B (instruction-injection workaround) and Path C (statusline-based discovery) both deferred — the platform's recommended channel is statusline, but it is a larger investment that should be a separate Linear issue if/when humans-don't-see-banner becomes a real friction. For now, the model's continued ability to surface SF context preserves the validated agentic UX from BC-6315.

## Out of scope

- Removing the workflows banner emoji 🔧 — separate PR (covered by feedback memory `feedback_no_emojis_in_generated_content.md`)

## Verification — objective criteria

| # | Test | Pass criteria |
|---|---|---|
| T1 | Bump discipline (revert state) | revops `0.2.5` AND workflows `3.29.4` in plugin.json + marketplace.json mirrors, both bumps in revert commit (`git log -1 --stat 206fa48`). Intermediate `0.2.4`/`3.29.3` instrumentation bumps in `fc0df30` are part of the audit trail, not the shipped state. |
| T2 | Diagnosis section written | `grep '## Diagnosis' docs/plans/BC-6434-plan.md` matches |
| T3 | CLAUDE.md gotcha lands | `grep '24425' CLAUDE.md` matches |
| T4 | Validate + guardrails clean | `./scripts/validate.sh && ./scripts/check-guardrails.sh --claude-md CLAUDE.md` exit 0 |

## Related

- BC-6315 — RevOps Plugin Validation Phase 1 (origin)
- BC-6425 — F1 tracking issue (friction #1 = this bug)
- BC-5806 — original revops banner ship; precedent for tee-wrap perf budget + reconciliation-table pattern
- BC-6000 — same-commit version-bump rule (informs Task 1+2+3 commit shape)
