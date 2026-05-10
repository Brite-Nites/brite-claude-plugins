# BC-6906 Execution Plan — Production migration: tam-map → `bw-run.sh`

**Issue:** [BC-6906](https://linear.app/brite-nites/issue/BC-6906)
**Branch:** `holden/bc-6906-migrate-tam-map-mcps-cli-scripts-to-bw-run-wrapper-rewrite` (per Linear `gitBranchName`)
**Worktree:** `.claude/worktrees/bc-6906/`
**Design doc:** `docs/designs/BC-6906-bw-run-prod-migration.md`
**Predecessor:** [BC-6905 PR #258](https://github.com/Brite-Nites/brite-claude-plugins/pull/258) (spike GO).

## Task graph

```
T1 (wrapper) ──┬──> T3 (run tests) ──> T4 (.mcp.json) ──> T5 (setup-tam-map.md)
T2 (tests)  ──┘                              │
                                              ├──> T6 (tam-map README.md)
                                              ├──> T7 (tam-mapping SKILL.md)   [parallel]
                                              └──> T8 (list-building SKILL.md) [parallel]

T9 (CLAUDE.md gotcha)        [parallel with T5–T8]
T10 (CONTRIBUTING.md canon)  [parallel with T5–T8]
T11 (version bump) ──> T12 (validate.sh) ──> T13/T14 (manual smoke tests)
```

T1+T2 in parallel (subagents). T3 sequential. T4–T8 parallel after T3. T9+T10 parallel anytime. T11 last before validation.

---

## T1 — Implement production wrapper `plugins/marketing/scripts/bw-run.sh`

**Explore.** Read `scripts/spike-bw-run/bw-run.sh` (the POC) and `docs/research/bw-run-spike.md` § Q3 + § Adapt list items 1, 2, 6.

**Plan.** Promote the POC with three production deltas:
- **(a)** Auto-detect longest common prefix of item names; if ≥ 3 chars, batch via `bw list items --search <prefix>` + jq filter; else per-item `bw get password` (BC-6905 adapt-list item 1).
- **(b)** Empty-array guard `if [ "${#EXPORTS[@]}" -gt 0 ]; then ... fi` around the loop (BC-6905 adapt-list item 2).
- **(c)** Replace the spike's fragile `bw status | grep '"status":"unlocked"'` with `bw status | jq -e '.status == "unlocked"' >/dev/null` (BC-6905 adapt-list item 6).

**Execute.** Write `plugins/marketing/scripts/bw-run.sh`, ~80 lines. Header comment cites BC-6905 + design doc. `set -euo pipefail`. Preflight: `BW_SESSION` set + `bw status` reports unlocked + `command -v jq`. LCP function (≤10 lines, pure POSIX shell). Then the branch: batch path (single `bw list items --search`, jq parse + per-item resolve) or sequential path. `export KEY=value` per resolved item. Final `exec "$@"`. Make executable (`chmod +x`).

**Verify (4-level).**
1. **Build:** `bash -n plugins/marketing/scripts/bw-run.sh` (syntax check).
2. **Tests:** N/A here — covered by T3.
3. **AC:** wrapper passes 4 mandated test cases (T3 verifies).
4. **Integration:** wrapper file is executable: `[ -x plugins/marketing/scripts/bw-run.sh ]`.

---

## T2 — Implement `plugins/marketing/scripts/bw-run.test.sh` (parallel with T1)

**Explore.** Read `scripts/spike-bw-run/measure.sh` and `verify-q7.sh` for pure-bash assertion idiom continuity. Note BC-6905 task-2 (macOS bash 3.2 portability).

**Plan.** Single self-contained pure-bash test file. PATH-mocked `bw` stub via `mktemp -d`. `assert_eq <actual> <expected> <name>` helper tracks fail count; non-zero exit on any failure. Five test cases:
1. Locked vault → exits 1, stderr names remediation.
2. Missing item (batch search returns `[]`) → exits 3.
3. Multi-key batch (3 items, shared `tam-map-` prefix) → exactly 1 `bw list items --search` call (verified via `$STUB_CALL_LOG` counter); all 3 exports populated.
4. Divergent naming (2 items, no shared prefix ≥ 3 chars) → 2 `bw get password` calls (sequential fallback verified).
5. Usage error (missing `--` separator) → exits 2.

The `bw` stub records every invocation to `$STUB_CALL_LOG` (one line per call: `arg1 arg2 ...`) and emits scripted stdout based on first arg (`status`, `list`, `get`).

**Execute.** Write `plugins/marketing/scripts/bw-run.test.sh`, ~150 lines. Make executable.

**Verify.**
1. **Build:** `bash -n plugins/marketing/scripts/bw-run.test.sh`.
2. **Tests:** N/A here — T3 runs them.
3. **AC:** 5 cases cover the 4 mandated AC #1 cases.
4. **Integration:** `[ -x plugins/marketing/scripts/bw-run.test.sh ]`.

---

## T3 — Run test suite; confirm all green

**Explore.** None. Just run.

**Plan.** Execute the test script.

**Execute.** `bash plugins/marketing/scripts/bw-run.test.sh`.

**Verify.**
1. **Build:** Exit code 0.
2. **Tests:** Output ends with `5 run, 0 failed`.
3. **AC:** All 4 mandated AC #1 cases reflected in stdout.
4. **Integration:** No stub leak — `which bw` after the script runs returns the real `bw` (not the stub).

If any fail: STOP. Diagnose root cause before proceeding. Common failure modes: macOS bash 3.2 portability (BC-6905 task-2), jq syntax, or stub path ordering.

---

## T4 — Rewrite `plugins/marketing/.mcp.json` to wrap 3 MCPs through `bw-run.sh`

**Explore.** Read `plugins/marketing/.mcp.json` (current state).

**Plan.** Per design doc § ".mcp.json rewrite":
- `salesforce` entry: unchanged (uses SFDX local auth, not env vars).
- `spider`, `aiark`, `discolike`: rewrite each. `command` → `${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh`. `args` → `["KEY=tam-map-<key>", "--", <original command + args>]`. Drop the `env` block (wrapper fills env at runtime).

**Execute.** Edit the JSON. Preserve the `salesforce` entry verbatim.

**Verify.**
1. **Build:** `python3 -m json.tool plugins/marketing/.mcp.json >/dev/null` (valid JSON).
2. **Tests:** N/A.
3. **AC #2:** All 3 plugin-scoped MCPs wrapped via `bw-run.sh` — `grep -c bw-run.sh plugins/marketing/.mcp.json` == 3.
4. **Integration:** `salesforce` entry intact — `jq '.mcpServers.salesforce.command' plugins/marketing/.mcp.json` returns `"npx"`.

---

## T5 — Rewrite `plugins/marketing/commands/setup-tam-map.md` to ≤3 phases

**Explore.** Read current file (157 lines, 7 phases).

**Plan.** Per design doc § Fork 4 (Shape 2):
- Frontmatter `description`: update to "≤3 phases, no shell-profile edits, no Claude Code restart" framing.
- Phase 1 — Detect: probe MCP status + vault status (`bw status`) + 7-item presence (`bw list items --search tam-map-` returns ≥ 7) + deps (`npm`, `pip`, `jq`, `bw`) + auth state. Branch table at end of phase routes to: all-green → Phase 3, vault-locked → Phase 2b, items-missing → Phase 2a-admin-halt, deps-missing → Phase 2a, fresh-machine → Phase 2a then 2b.
- Phase 2 — Unlock & bootstrap:
  - **Step 2a [ONE-TIME, skip if done]:** check + run `bw login`, `npm install` in `plugins/marketing/scripts/tam-map/`, `pip install -r .../requirements.txt`, admin-provisioning check (halt-and-ask if items missing).
  - **Step 2b [PER-SESSION]:** `export BW_SESSION="$(bw unlock --raw)"`. Tell user to run this in the same shell that launched Claude Code.
- Phase 3 — Verify: copy current Phase 6a/6b/6c probes verbatim per issue spec.
- Closing message: brief — "tam-map ready. Wrapper handles env per spawn; rotate values in Bitwarden and the next MCP spawn picks them up. No restart needed."

Zero `~/.zshrc` references. Zero "restart Claude Code" references.

**Execute.** Full rewrite via Write (existing file is being substantially restructured).

**Verify.**
1. **Build:** Frontmatter parses (`grep -A2 '^---' setup-tam-map.md | head` shows valid YAML).
2. **Tests:** N/A.
3. **AC #4:** `grep -c '^## Phase' plugins/marketing/commands/setup-tam-map.md` ≤ 3.
4. **AC #5:** `grep -c '~/\.zshrc' plugins/marketing/commands/setup-tam-map.md` == 0.
5. **AC #6:** `grep -ci 'restart claude code' plugins/marketing/commands/setup-tam-map.md` == 0.
6. **Integration:** Phase 6 probe code blocks (the 6a/6b/6c bash) survive verbatim — `diff <(grep -A20 '^claude mcp list' OLD) <(grep -A20 '^claude mcp list' NEW)` should match.

---

## T6 — Create `plugins/marketing/scripts/tam-map/README.md` (new file)

**Explore.** Read the issue spec for the canonical-pattern intent. Confirm the file does not exist (`ls plugins/marketing/scripts/tam-map/README.md`).

**Plan.** Short README (~40 lines):
- Title: "tam-map scripts — invocation pattern"
- Section 1: "Required env vars and Bitwarden mapping" — table mapping each script to its `KEY=tam-map-<key>` pair.
- Section 2: "Canonical invocation" — code block per script showing `bw-run.sh KEY=item -- python <script> args`.
- Section 3: "Why the wrapper" — one paragraph linking to `CONTRIBUTING.md § Plugin secret-config canon` and `docs/research/bw-run-spike.md`.
- Section 4: "Related" — link to BC-5551 gotcha (CLAUDE.md L93), BC-6906 design doc.

**Execute.** Write the file.

**Verify.**
1. **Build:** File exists, non-empty.
2. **Tests:** N/A.
3. **AC:** Each of the 4 scripts (icypeas_client.py, spider_crawl.py, enrich_waterfall.py, verify_smtp.py) named in the table; tier_and_segment.py marked as "BC-6907 will replace this with an in-session skill."
4. **Integration:** Markdown link targets resolve (links to CONTRIBUTING.md, research doc).

---

## T7 — Update `plugins/marketing/skills/tam-mapping/SKILL.md` CLI invocations

**Explore.** Re-grep for invocation sites: `grep -n 'plugins/marketing/scripts/tam-map/.*\.py' plugins/marketing/skills/tam-mapping/SKILL.md`. Expected 5 hits (L198, L201, L299, L339, L459 from earlier audit; verify line numbers as they may shift).

**Plan.** For each invocation, prepend `plugins/marketing/scripts/bw-run.sh KEY=item -- ` per design doc § "CLI invocation rewrites":
- spider_crawl.py: `SPIDER_API_KEY=tam-map-spider-api-key`
- icypeas_client.py: `ICYPEAS_API_KEY=tam-map-icypeas-api-key`
- enrich_waterfall.py: `BLITZAPI_KEY=tam-map-blitzapi-key PROSPEO_API_KEY=tam-map-prospeo-api-key`
- verify_smtp.py: `MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key`
- tier_and_segment.py: leave unchanged (uses ANTHROPIC_API_KEY; out of scope per BC-6907).

**Execute.** 4 edits (5th left alone). Use Edit tool with surrounding-context strings to make replacements unique.

**Verify.**
1. **Build:** Skill frontmatter still valid: `head -10 plugins/marketing/skills/tam-mapping/SKILL.md` shows YAML.
2. **Tests:** N/A.
3. **AC #3:** `grep -c 'bw-run.sh' plugins/marketing/skills/tam-mapping/SKILL.md` ≥ 4.
4. **Integration:** No half-rewrites — `grep -n 'python plugins/marketing/scripts/tam-map/' plugins/marketing/skills/tam-mapping/SKILL.md` returns only the tier_and_segment.py site (if any) and the bw-run-wrapped sites.

---

## T8 — Update `plugins/marketing/skills/list-building/SKILL.md` CLI invocations (parallel with T7)

**Explore.** `grep -n 'plugins/marketing/scripts/tam-map/.*\.py' plugins/marketing/skills/list-building/SKILL.md`. Expected 4 hits (L140, L141, L229, L237).

**Plan.** Same pattern as T7. 3 distinct scripts referenced: `enrich_waterfall.py`, `verify_smtp.py`, plus a routing-table reference at L140 (skill-layer concern).

**Execute.** Edits matching T7's mapping.

**Verify.**
1. **Build:** Frontmatter intact.
2. **Tests:** N/A.
3. **AC #3:** `grep -c 'bw-run.sh' plugins/marketing/skills/list-building/SKILL.md` ≥ 2 (verify_smtp.py + enrich_waterfall.py minimum, more if routing-table mentions update).
4. **Integration:** No bare `python plugins/marketing/scripts/tam-map/` invocations (other than tier_and_segment).

---

## T9 — Rewrite CLAUDE.md BC-5551 gotcha (line 93 parenthetical) — parallel anytime

**Explore.** Read CLAUDE.md L91–L96 (gotchas section). Re-read `memory/gotcha_http_mcp_substitution_broken.md` for context.

**Plan.** Reframe the parenthetical inside L93. Old framing: "but note that `${user_config.*}` substitution into HTTP MCP headers is currently broken in Claude Code, see `email-bison.md` § Known Claude Code limitation." New framing per issue spec: "for HTTP MCPs, `${user_config.*}` and `${ENV_VAR}` substitution into headers are both broken (BC-5551) — ship user-level registration. For stdio MCPs, the recommended pattern is OS env-vars filled by `bw-run.sh` (see CONTRIBUTING.md § Plugin secret-config canon)." Keep the parenthetical compact (single sentence preferred; two short sentences max).

**Execute.** Edit the parenthetical only — preserve the surrounding `plugin.json` strict schema bullet structure.

**Verify.**
1. **Build:** CLAUDE.md file size delta < +200 chars (we're rewording a parenthetical, not adding a new section).
2. **Tests:** N/A.
3. **AC #7:** New text mentions stdio + bw-run.sh + CONTRIBUTING.md reference.
4. **Integration:** CLAUDE.md line count unchanged (or +1 max). Per BC-5832 precedent, document the line count in the commit message.

---

## T10 — Add `CONTRIBUTING.md` § "Plugin secret-config canon" — parallel anytime

**Explore.** Read CONTRIBUTING.md § "Email Bison MCP Onboarding" (L155+) and § "Salesforce MCP Onboarding" (L124+) for tonal/structural reference. New section sits between them or after them — placement: just before § "ADR Convention" (L173).

**Plan.** New section ~30 lines:
- Heading: `## Plugin secret-config canon`
- One-paragraph why: stdio MCP + CLI scripts need OS env vars; the friction is "how secrets reach env"; `bw-run.sh` is the canonical answer for the Brite plugin family.
- Reference implementation pointer: `plugins/marketing/scripts/bw-run.sh` + tests.
- Adoption checklist for any future plugin (5 bullets):
  1. Provision N items in the Engineering Bitwarden collection (per-item Login entries).
  2. Copy `bw-run.sh` to your plugin's `scripts/` directory (or symlink).
  3. Wrap each stdio MCP entry in `.mcp.json`: `command: "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh", args: ["KEY=item-name", "--", <original cmd>...]`.
  4. Wrap each Bash invocation in your skills: `bw-run.sh KEY=item -- <original cmd>`.
  5. Add `bw-run.test.sh` mirroring the marketing-plugin shape (4 mandated cases: locked vault, missing item, multi-key batch, divergent naming).
- Tradeoffs: "Adds `bw` and `jq` runtime requirements (`brew install bitwarden-cli jq`). Vault-lock-mid-session costs ~30s recovery (option-A env-propagation per BC-5947 task-3). Rotation propagates without Claude Code restart (BC-6906 AC #11)."
- Link to BC-5551 gotcha for HTTP MCP exception.

**Execute.** Insert section before `## ADR Convention`.

**Verify.**
1. **Build:** Markdown structure preserved (no broken section nesting).
2. **Tests:** N/A.
3. **AC #8:** `grep -c '## Plugin secret-config canon' CONTRIBUTING.md` == 1.
4. **Integration:** Adoption checklist has all 5 items; reference impl path is correct.

---

## T11 — Bump plugin version (BC-6000 same-commit rule) — last edit before validation

**Explore.** Confirm current state: `cat plugins/marketing/.claude-plugin/plugin.json | jq -r .version` and `cat .claude-plugin/marketplace.json | jq -r '.plugins[] | select(.name=="marketing") | .version'`. Both should be `0.3.28`.

**Plan.** Bump both to `0.3.29` (patch — wrapper migration is a behavior change but no breaking interface change).

**Execute.** 2 edits.

**Verify.**
1. **Build:** Both files still valid JSON.
2. **Tests:** N/A.
3. **AC #9:** Both files show `0.3.29`. `git log -p --follow plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json | head -40` shows the bump in the same commit (or staged for it).
4. **Integration:** No version drift between files.

---

## T12 — Run `./scripts/validate.sh` end-to-end

**Explore.** None.

**Plan.** Run validation script.

**Execute.** `./scripts/validate.sh 2>&1 | tail -40`.

**Verify.**
1. **Build:** Exit code 0.
2. **Tests:** All checks pass (JSON validity, plugin.json schema, frontmatter, hook config, marketplace cross-version-check).
3. **AC #12 prep:** No findings to fix before review.
4. **Integration:** `git status` shows only intended file edits.

If `validate.sh` fails: STOP. Fix root cause. Common failure modes: marketplace.json/plugin.json version drift (T11), JSON syntax error (T4), schema-disallowed field (don't add `agents`/`hooks`/`mcpServers as path` to plugin.json).

---

## T13 — Manual smoke test (AC #10): fresh-machine simulation

**Explore.** None — manual test.

**Plan.** Simulate a fresh dev environment without `~/.zshrc` exports:
1. Open a fresh terminal (no tam-map exports inherited).
2. `unset SPIDER_API_KEY AIARK_API_KEY DISCOLIKE_API_KEY ICYPEAS_API_KEY BLITZAPI_KEY PROSPEO_API_KEY MILLIONVERIFIER_API_KEY`.
3. `bw lock` (force re-unlock path).
4. Launch Claude Code from this shell.
5. Run `/marketing:setup-tam-map`.
6. Walk through Phase 1 → Phase 2 (2a if needed, then 2b) → Phase 3.
7. Confirm: zero file edits required, zero Claude Code restarts, all 3 MCPs `✓ Connected`, all 4 CLI scripts `✓ <name>` on `--help`.

**Execute.** Run interactively. Capture screenshots or transcript.

**Verify.**
1. **AC #10:** End-to-end completes without manual file editing or Claude Code restart.
2. Document the run in the PR description.

If a step fails: do NOT mark complete. File a follow-up task to fix the failure mode before review.

---

## T14 — Manual smoke test (AC #11): rotation without restart

**Explore.** None — manual test.

**Plan.** Validate that rotating a Bitwarden value propagates to the next MCP spawn without `/reload-plugins` or restart:
1. With Claude Code already running and one tam-map MCP previously used (e.g., `spider`), open Bitwarden and append a single character to `tam-map-spider-api-key` (note the original value first).
2. From Claude Code, invoke a `mcp__plugin_marketing_spider__*` tool that requires authentication (e.g., `spider_get_credits`).
3. Observe behavior:
   - **Expected (success path):** the next MCP spawn picks up the new value; tool either succeeds (if the corrupted value happens to still be valid — unlikely) or returns an auth-error (proving the wrapper read the new corrupted value, NOT the cached old one).
   - **Failure mode:** tool succeeds with the original value, indicating Claude Code reused a stale MCP process. If this happens, document it as the "lifecycle-side rotation gap" called out in BC-6905 adapt-list item 3.
4. Restore the original Bitwarden value.

**Execute.** Run interactively.

**Verify.**
1. **AC #11:** Document observed behavior — pass (rotation propagates) or measured gap (rotation requires `/reload-plugins`). Either outcome is acceptable for this issue *as long as the behavior is documented* in the PR. The acceptance criterion expects success; if measurement reveals a gap, file a follow-up issue and update the CONTRIBUTING.md tradeoffs section to reflect reality.

---

## Validation gates (in order)

1. T3 (test suite green) — gate before T4–T8.
2. T12 (validate.sh clean) — gate before review.
3. T13 + T14 (manual smoke) — gate before `/workflows:ship`.
4. `/workflows:review` thorough pass clean — AC #12.
5. `/workflows:ship` clean — AC #13.

## Rollback strategy

If T13 reveals a regression worse than a documentable gap:
- Revert T4 (`.mcp.json`) — restores the bare-env-var registration.
- Revert T11 (version bump) — un-publishes the broken version.
- Keep the wrapper (T1/T2/T3 are additive; safe to leave for the next attempt).
- Keep the spike directory until rollback risk has fully passed (issue says: "do NOT delete the bundle until 2 weeks post-deploy").

## Out-of-scope safety

- Do NOT delete `scripts/spike-bw-run/` — issue out-of-scope; spike POC stays for 2 weeks post-deploy per rollback policy.
- Do NOT delete the legacy `tam-map — API tokens` Bitwarden bundle item — issue out-of-scope; admin removes it 2 weeks post-deploy.
- Do NOT touch `tier_and_segment.py` invocations (BC-6907 owns the script's removal).
- Do NOT add userConfig migration paths (Pattern C, BC-5947 task-3 still open).
