# Plan: BC-6905 — Spike: validate `bw-run.sh` wrapper for tam-map MCP + CLI key injection

**Issue**: [BC-6905](https://linear.app/brite-nites/issue/BC-6905)
**Branch**: `holden/bc-6905-spike-validate-bw-run-wrapper-for-tam-map-mcp-cli-key` (per Linear `gitBranchName`)
**Worktree**: `.claude/worktrees/bc-6905/`
**Tasks**: 11 (estimated 60–90 min, of which ~30–40 min is measurement wait time)
**Design doc**: `docs/designs/BC-6905-spike-validate-bw-run-wrapper-for-tam-map.md`

## Prerequisites

- `bw` CLI 2026.4.1 installed via `brew install bitwarden-cli` (done in this session).
- User authenticated to Brite Bitwarden (`holden@britenites.com`); `bw status` reports `unlocked` in parent shell (verified in this session).
- Engineering-collection write access in Bitwarden (Holden has admin rights — required for T2).
- `npx` reachable for `npx -y spider-cloud-mcp@2.1.1` smoke test (verified — node v25.9.0 installed).
- **Precedent alignment**: Aligns with **BC-5947 task-3** (extends Pattern A — plugin-scoped stdio + `${OS_ENV}` — by replacing the human-types-into-`.zshrc` step with `bw-run.sh`). Wrapper-source-grep discipline per **BC-5946 task-3** (every claim about wrapper behavior must grep-anchor to specific line numbers in `bw-run.sh`, not author memory).
- **Precedent non-claim**: This spike does NOT verify Pattern C (`${user_config.*}` substitution for stdio) — that's BC-5947 task-3's still-open promotion question. Spike findings doc must explicitly call this out.
- **CDR check**: Skipped — handbook private, Context7 cannot resolve. Spike is research-only, no architectural decisions in flight.

## Tasks

### Task 1: Decide env-propagation mode + verify wrapper can see `BW_SESSION`
**Files**: none (decision + verification only)
**Why**: Claude Code captured env at launch (no `BW_SESSION` then). Without resolving this, every Bash tool call I make to invoke the wrapper will fail at `bw status`. Two paths exist; pick one before writing code.

**Implementation**:
1. Present choice to user via AskUserQuestion:
   - **(A) Restart Claude Code from a `BW_SESSION`-exported shell** — recommended. Closes session; user re-runs `/workflows:session-start BC-6905` from the relaunched session. The wrapper inherits `BW_SESSION` naturally for the rest of the spike. This is also exactly the production pattern BC-6906 targets, so we're testing the real flow.
   - **(B) User-driven `!` measurements** — every measurement command runs as `! <cmd>` from user's parent shell. Slower feedback, but no session interruption.
2. Once user picks: if (A), document the relaunch sequence in T2 as: `bw lock; bw unlock` (gives a fresh BW_SESSION token, the one printed earlier already works for this session — re-export to be safe), `export BW_SESSION="..."`, restart Claude Code from that shell, re-run `/workflows:session-start BC-6905`, then continue from T2 of this plan.
3. If (B): annotate every subsequent task's "Implementation" with "(user-driven `!`)" prefix.

**Test**:
- Verify: `bw status` (run in the env where the wrapper will execute — i.e., my Bash tool in option A, user's `!` shell in option B) returns `"status":"unlocked"`.
- Expected: JSON output with `"status":"unlocked"` and `"userEmail":"holden@britenites.com"`.

**Verify**: `bw status` reports unlocked in the execution context for subsequent tasks.

---

### Task 2: Provision 1 per-item Bitwarden test entry in Engineering collection
**Files**: none in repo (Bitwarden vault state change only)
**Why**: Validates Q1 (per-item retrieval) + Q4 (MCP handshake passthrough) + Q7 (collection-share permission) in one shot. Per design decision #4, exactly one item — minimal vault churn; bundle stays as-is for rollback.

**Implementation** (user-driven, in Bitwarden web/desktop client):
1. Open Bitwarden, navigate to Engineering collection.
2. Find existing item: `tam-map — API tokens` (the bundle item).
3. Copy the `SPIDER_API_KEY` value from its Notes field.
4. Create a new login item:
   - **Name**: `tam-map-spider-api-key`
   - **Username**: (leave empty)
   - **Password**: paste the SPIDER_API_KEY value from step 3
   - **URI**: `https://spider.cloud`
   - **Notes**: `Spike test item for BC-6905. Mirrors bundle SPIDER_API_KEY value. Delete after spike completes (BC-6906 admin step provisions the canonical 7).`
   - **Collection**: Engineering (collection-share, NOT user-share — this is what Q7 validates)
   - **Folder**: (any or none)
5. Save.

**Test**:
- Run from execution context: `bw sync && bw get password tam-map-spider-api-key`
- Expected: prints the same SPIDER_API_KEY value as the bundle item's Notes contains. Exit 0.
- If "More than one result was found" error → item name collides with another; rename to `tam-map-spider-api-key-spike` and update T3+ accordingly.
- If "Not found" error → either sync didn't pick it up (run `bw sync` again), or collection-share permission isn't reaching the CLI (Q7 NO-GO; halt and discuss).

**Verify**: `bw get password tam-map-spider-api-key` returns the expected value.

---

### Task 3: Build POC wrapper at `scripts/spike-bw-run/bw-run.sh`
**Files**: `scripts/spike-bw-run/bw-run.sh` (new), `scripts/spike-bw-run/README.md` (new)
**Why**: The artifact under test. Must be ~25 lines per issue spec, hard-bound to `bw`, and parent-shell-unlock with fail-fast on locked vault.

**Implementation**:
1. Create directory: `mkdir -p scripts/spike-bw-run`.
2. Write `scripts/spike-bw-run/bw-run.sh` (POSIX `sh`-compatible, mode 755):
   ```sh
   #!/usr/bin/env bash
   # bw-run.sh — POC credential broker for BC-6905 spike.
   # Usage: bw-run.sh KEY=item [KEY=item ...] -- cmd args...
   # Pre: BW_SESSION exported in parent env, vault unlocked.
   set -euo pipefail

   if [ -z "${BW_SESSION:-}" ]; then
     echo "bw-run.sh: BW_SESSION not set. Run \`bw unlock\` and export BW_SESSION." >&2
     exit 1
   fi
   if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
     echo "bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again." >&2
     exit 1
   fi

   # Parse KEY=item args until -- separator
   declare -a EXPORTS=()
   while [ $# -gt 0 ] && [ "$1" != "--" ]; do
     case "$1" in
       *=*) EXPORTS+=("$1") ;;
       *)   echo "bw-run.sh: unexpected arg \`$1\` (expected KEY=item or --)" >&2; exit 2 ;;
     esac
     shift
   done
   if [ "${1:-}" != "--" ]; then
     echo "bw-run.sh: missing -- separator before command" >&2
     exit 2
   fi
   shift  # drop --

   # Fetch each key via bw get password (sequential per design decision #3)
   for entry in "${EXPORTS[@]}"; do
     key="${entry%%=*}"
     item="${entry#*=}"
     value="$(bw get password "$item")" || {
       echo "bw-run.sh: bw get password failed for item \`$item\`" >&2
       exit 3
     }
     export "$key=$value"
   done

   # Exec the wrapped command with env populated
   exec "$@"
   ```
3. `chmod +x scripts/spike-bw-run/bw-run.sh`.
4. Write `scripts/spike-bw-run/README.md` with: usage example, BW_SESSION precondition, link to `docs/research/bw-run-spike.md` (placeholder for T10), and a clear "this is a throwaway POC for BC-6905; production wrapper lives in BC-6906" notice.

**Test**:
- Lint: `bash -n scripts/spike-bw-run/bw-run.sh` (syntax check) → exit 0.
- Smoke: `bash scripts/spike-bw-run/bw-run.sh -- echo "hello"` → prints `hello`, exit 0 (no keys = no fetches).
- Smoke (locked-vault detection): in a shell with no `BW_SESSION` exported, run `bash scripts/spike-bw-run/bw-run.sh KEY=foo -- true` → prints the unlock message, exits 1.
- Smoke (missing `--` separator): `bash scripts/spike-bw-run/bw-run.sh KEY=foo true` → prints the missing-`--` message, exits 2.

**Verify**: All three smoke tests pass; `wc -l scripts/spike-bw-run/bw-run.sh` reports ≤35 lines (allowing some headroom over the issue's "~25 lines" target).

---

### Task 4: Q1 — Validate `bw get password <item>` works non-interactively + measure single-call latency (Q2)
**Files**: `docs/research/bw-run-spike.md` (append measurement to a "Raw measurements" appendix; full doc structure comes in T10)
**Why**: Foundational — confirms the wrapper's core fetch primitive works without TTY interaction, and establishes the per-key latency floor.

**Implementation**:
1. Run 5 trials (warm cache; `bw sync` once before to ensure latest):
   ```sh
   bw sync >/dev/null
   for i in 1 2 3 4 5; do
     /usr/bin/time -p bw get password tam-map-spider-api-key >/dev/null 2>&1
     # Capture user/sys/real
   done
   ```
2. On macOS `/usr/bin/time -p` outputs `real X.XX` to stderr — capture, parse, record.
3. Run 1 cold-cache trial after `bw lock; bw unlock; export BW_SESSION="..."` (cold = post-unlock first call). Record real time.
4. Append to `docs/research/bw-run-spike.md` under appendix `## A1. Raw measurements`:
   ```
   ### Q1 / Q2 — single-call `bw get password` latency
   - Trials (warm): [t1, t2, t3, t4, t5] seconds
   - Median warm: X.XXs
   - Cold: Y.YYs
   - Target (issue): < 0.300s warm
   - Verdict: [PASS / FAIL — explain]
   ```

**Test**:
- Verify: each call exits 0 and prints non-empty value (without printing it to terminal — pipe to `wc -c` to confirm length without exposing secret).
- Verify: parsed median is a positive number.

**Verify**: 5 warm + 1 cold measurement recorded in raw measurements appendix; verdict line written.

---

### Task 5: Q3 — Measure `bw list items --search` batch-fetch latency
**Files**: `docs/research/bw-run-spike.md` (append to raw measurements appendix)
**Why**: Tells us if the wrapper interface should evolve to batch-fetch in BC-6906 instead of N sequential calls. Cost surface: at N=2 (spider_crawl, enrich_waterfall), sequential is `2 × Q2 latency`; batch is one `list items` call regardless of N.

**Implementation**:
1. Run 5 warm trials:
   ```sh
   for i in 1 2 3 4 5; do
     /usr/bin/time -p bw list items --search tam-map- >/dev/null 2>&1
   done
   ```
2. Run 1 cold trial post-`bw lock; bw unlock`.
3. Inspect output once: `bw list items --search tam-map- | jq 'length'` → confirm count (should be 2 today: bundle + new spike item) and `bw list items --search tam-map- | jq '.[] | {name, hasPassword: (.login.password != null)}'` to verify the new spike item has a password.
4. Append to `## A1. Raw measurements`:
   ```
   ### Q3 — `bw list items --search` batch-fetch latency
   - Trials (warm): [...] seconds
   - Median warm: X.XXs
   - Cold: Y.YYs
   - Items returned: N (names: [...])
   - Verdict for BC-6906: [batch beats sequential at N≥X / sequential always wins / inconclusive]
   ```

**Test**:
- Verify: each call exits 0; output is valid JSON parseable by `jq`.
- Verify: at least the spike item appears in results.

**Verify**: 5 warm + 1 cold measurement recorded; verdict on batch-vs-sequential crossover written.

---

### Task 6: Q4 — Smoke-test wrapper passes MCP stdio handshake transparently
**Files**: `docs/research/bw-run-spike.md` (append handshake transcript to appendix)
**Why**: The wrapper-as-broker must NOT corrupt the MCP `initialize` request/response. If stdin/stdout are not clean passthroughs, MCP servers will fail to initialize and the wrapper is useless for plugin-scoped MCPs.

**Implementation**:
1. Construct an `initialize` JSON-RPC request:
   ```json
   {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"bc-6905-spike","version":"0"}}}
   ```
2. Pipe it to the wrapper-wrapped MCP:
   ```sh
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"bc-6905-spike","version":"0"}}}' \
     | bash scripts/spike-bw-run/bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- npx -y spider-cloud-mcp@2.1.1
   ```
3. Capture first line of stdout. Expected: a JSON object with `"jsonrpc":"2.0"`, `"id":1`, `"result":{...}` containing `protocolVersion`, `capabilities`, `serverInfo`.
4. Append to `docs/research/bw-run-spike.md` `## A1. Raw measurements`:
   ```
   ### Q4 — MCP `initialize` handshake passthrough
   - Wrapped command: bw-run.sh SPIDER_API_KEY=... -- npx -y spider-cloud-mcp@2.1.1
   - Stdin: initialize JSON-RPC request
   - First-line stdout: <captured>
   - Server reported: protocolVersion=<X>, serverName=<Y>, serverVersion=<Z>
   - Verdict: [PASS — handshake clean / FAIL — corruption observed]
   ```

**Test**:
- Verify: stdout's first line parses as JSON and has `result.protocolVersion`, `result.capabilities`, `result.serverInfo`.
- Verify: NO interleaved `bw-run.sh:` warnings on stdout (stderr is OK).

**Verify**: Server-info JSON captured; stdout is clean (no wrapper noise on stdout, only on stderr).

---

### Task 7: Q5 — Vault-locked-mid-session UX
**Files**: `docs/research/bw-run-spike.md` (append to appendix)
**Why**: The wrapper's failure mode when the vault locks during a long-running session needs to be observable, not silent. If users get an opaque MCP failure, the bw-run pattern erodes trust.

**Implementation**:
1. Confirm vault is unlocked: `bw status | grep unlocked` → exit 0.
2. Lock vault: `bw lock` → reports locked.
3. Re-export the (now-stale) `BW_SESSION` (note: stale session keys give "Vault is locked" errors from `bw get password` even with the value still set).
4. Run wrapper: `bash scripts/spike-bw-run/bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- echo wrapped`.
5. Capture stderr + exit code. Expected: clear `run \`bw unlock\`` message on stderr, non-zero exit, no `wrapped` printed on stdout (exec never reached).
6. Append to appendix:
   ```
   ### Q5 — Vault-locked-mid-session UX
   - Pre-condition: vault unlocked, then `bw lock`
   - Wrapper invocation: bw-run.sh SPIDER_API_KEY=... -- echo wrapped
   - Stderr: <captured>
   - Stdout: <captured — should be empty>
   - Exit code: <captured>
   - Verdict: [PASS — message clear, exec blocked / FAIL — silent or unclear]
   ```
7. Re-unlock for subsequent tasks: `bw unlock` → export new `BW_SESSION` (per env-propagation gotcha; if option (A), this means restart Claude Code again — flag this UX cost in the verdict).

**Test**:
- Verify: stderr contains the substring `bw unlock`.
- Verify: stdout does NOT contain `wrapped` (exec was blocked).
- Verify: exit code is 1.

**Verify**: All three checks pass; verdict line records UX clarity.

---

### Task 8: Q6 — Does Claude Code re-spawn an MCP cleanly when a Bitwarden value rotates?
**Files**: `docs/research/bw-run-spike.md` (append to appendix)
**Why**: The issue's stated goal is "no Claude Code restart for key rotation." This is the most expensive measurement (touches Claude Code's MCP lifecycle, requires real auth round-trips). Findings here drive the GO/NO-GO on the rotation UX promise.

**Implementation**:
This task is necessarily partly user-driven because it touches Claude Code's MCP lifecycle, not just shell invocations. Run in execution context with BW_SESSION live:

1. **Setup observability**: Add a debug-log line to `scripts/spike-bw-run/bw-run.sh` that logs (to stderr) a SHA-256 prefix of each fetched value, e.g., `bw-run.sh: $key fetched [sha256=<8 hex chars>]`. This avoids logging the secret while making rotation visible. (This is a temporary debug instrumentation — remove or comment-out before T10's findings doc finalizes claims.)
2. **Wrap Spider MCP via the spike wrapper**: This requires a temporary `.mcp.json` change OR direct invocation. Since the spike PR explicitly does NOT touch `plugins/marketing/.mcp.json` (out of scope), use direct invocation: write a 5-line `scripts/spike-bw-run/exercise-spider.sh` helper that pipes an MCP `tools/call` `spider_get_credits` request through the wrapped server.
3. **Trial 1**: Run `exercise-spider.sh` → record stderr SHA prefix and the credits-call response (exit 0, JSON includes credits balance).
4. **Rotation simulation**: In Bitwarden, edit `tam-map-spider-api-key` — **prepend a single character** to the password value (this invalidates the key from Spider's perspective; subsequent calls should fail auth). Save. Run `bw sync`.
5. **Trial 2 (immediate)**: Run `exercise-spider.sh` again → record stderr SHA prefix.
   - If SHA prefix changed → wrapper fetched fresh value (good); auth should now FAIL because Spider rejects the bad key (good — proves the new value reached Spider).
   - If SHA prefix is identical → wrapper got the cached/old value somehow (bad, investigate).
6. **Restoration**: Edit Bitwarden item back to original value. Save. `bw sync`. Run `exercise-spider.sh` again — should succeed.
7. **Claude-Code-MCP-lifecycle test (only meaningful if the marketing plugin's spider MCP is wrapped)**: Out of scope for this spike's PR (we agreed not to touch `.mcp.json`). Document this gap in findings: "Q6's full answer requires BC-6906's `.mcp.json` change to wrap spider through bw-run; the spike validates only the *wrapper*-side rotation propagation, not Claude Code's *MCP-lifecycle*-side restart-vs-re-spawn behavior. BC-6906 must measure the lifecycle dimension before promoting bw-run to the canonical pattern."
8. Append findings to appendix:
   ```
   ### Q6 — Rotation propagation through wrapper
   - Trial 1 SHA prefix: <X>
   - Trial 2 SHA prefix (after rotation): <Y>
   - Auth on trial 2: [failed as expected — bad key reached Spider / unexpected behavior]
   - Trial 3 (post-restoration) SHA prefix: <Z = X expected>
   - Wrapper-side verdict: [PASS — fresh value on every spawn / FAIL — caching observed]
   - Lifecycle-side gap: deferred to BC-6906 (requires `.mcp.json` wiring)
   ```

**Test**:
- Verify: SHA prefixes captured for 3 trials.
- Verify: auth-failure observed during rotation window (positive evidence the new value reached Spider).
- Verify: post-restoration trial succeeds.

**Verify**: Three trials recorded; lifecycle-side gap explicitly documented as BC-6906 follow-up.

---

### Task 9: Q7 — Confirm collection-level share permission works for `bw get password`
**Files**: `docs/research/bw-run-spike.md` (append to appendix)
**Why**: BC-6906's whole vault model assumes per-item entries shared via Engineering collection. If `bw get password` requires user-level share (not collection-share), BC-6906 needs to either provision items per-user or rethink. T2 already created the test item via collection-share; this task verifies retrievability is unaffected.

**Implementation**:
1. Confirm via Bitwarden web client that `tam-map-spider-api-key` is shared via Engineering collection (not personal vault, not user-share). Screenshot or describe the Sharing/Collections panel state in findings.
2. Inspect: `bw list items --search tam-map-spider-api-key | jq '.[] | {name, collectionIds, organizationId, type, login: {hasPassword: (.login.password != null)}}'` → confirm `collectionIds` is non-empty (matches Engineering collection ID) and `organizationId` is present.
3. The actual fetch already happened in T2's verification step — but re-run to capture the timing/output cleanly: `bw get password tam-map-spider-api-key | wc -c` → confirms non-zero length without printing secret.
4. Append to appendix:
   ```
   ### Q7 — Collection-share retrieval semantics
   - Item: tam-map-spider-api-key
   - Sharing: Engineering collection (NOT user-share)
   - `bw list` collectionIds: [<id>]; organizationId: <id>
   - `bw get password` exit code: 0; value length: N bytes (non-zero)
   - Verdict: [PASS — collection-share is sufficient / FAIL — required user-share]
   ```

**Test**:
- Verify: `collectionIds` is a non-empty array.
- Verify: `bw get password` succeeds (exit 0, non-zero output length).

**Verify**: Sharing surface confirmed via both Bitwarden UI and CLI metadata; retrieval succeeds.

---

### Task 10: Write findings doc + GO/NO-GO + adapt list
**Files**: `docs/research/bw-run-spike.md` (full structure now, not just appendix)
**Why**: Issue acceptance criterion: "1-paragraph summary, the 7 Q&As, a GO/NO-GO decision, and a 'things issue β must adapt' list if surprises surfaced."

**Implementation**:
1. Promote the appendix data into a structured findings doc. Sections (in order):
   - **Summary** (1 paragraph): What the spike validated, the GO/NO-GO verdict, top 1–2 surprises (if any).
   - **Q1–Q7 evaluation** (7 subsections): Each subsection has Question, Method, Evidence (cite line numbers in `scripts/spike-bw-run/bw-run.sh`), Verdict.
   - **GO/NO-GO**: Single line — `**Decision: GO**` or `**Decision: NO-GO**` with 1-paragraph rationale referencing specific verdicts.
   - **Adapt list for BC-6906** (only if GO with caveats): Bulleted, each item names a specific BC-6906 task it shapes. Example: `- BC-6906 wrapper interface: prefer batch-fetch over sequential at N≥3 (Q3 measured X.XXs batch vs N×Y.YYs sequential).`
   - **Open questions / explicit non-goals**: Single subsection. Must include: "Pattern C (`${user_config.*}` substitution) verification remains UNRUN — BC-5947 task-3's promotion question is not closed by this spike. Future work."
   - **Appendix A1**: Raw measurements (the data accumulated in T4–T9). Keep verbatim.
2. Strip the temporary debug instrumentation added in T8 (the SHA-256 logging line) — leave a comment explaining it was used during the spike, was removed before findings publication. Re-verify wrapper still passes T3's smoke tests after debug-line removal.
3. Add line-number-anchored evidence citations: when findings claim "wrapper exits 1 on locked vault," cite `scripts/spike-bw-run/bw-run.sh:L<N>-<M>` per BC-5946 task-3.

**Test**:
- Verify: doc has all required sections (grep for headings: `## Summary`, `## Q1`, ..., `## Q7`, `## GO/NO-GO`, `## Adapt list`, `## Open questions`, `## Appendix`).
- Verify: GO/NO-GO line matches regex `\*\*Decision: (GO|NO-GO)\*\*`.
- Verify: At least 3 line-number citations to `scripts/spike-bw-run/bw-run.sh` (if GO) using format `L<N>` or `L<N>-<M>`.
- Verify: T8 debug instrumentation is removed: `grep -n "sha256" scripts/spike-bw-run/bw-run.sh` returns nothing.

**Verify**: Findings doc readable end-to-end; verdict line is present and machine-parseable.

---

### Task 11: Post Linear comment + cleanup
**Files**: none in repo (Linear API + Bitwarden vault state)
**Why**: Issue AC: "Decision recorded as a comment on this Linear issue (GO unblocks β; NO-GO triggers a follow-up alternative-approach issue)." Cleanup ensures we leave the vault and shell state tidy.

**Implementation**:
1. Post comment on BC-6905 via `mcp__plugin_workflows_linear-server__save_comment`:
   - Body shape:
     ```
     **Spike outcome — BC-6905**

     **Decision: <GO | NO-GO>**

     <1-paragraph rationale citing the most load-bearing verdicts.>

     **Findings doc**: `docs/research/bw-run-spike.md` (PR #<num>)

     <If GO:> **BC-6906 adapt list**:
     - <bullet>
     - <bullet>

     <If NO-GO:> **Follow-up issue filed**: BC-XXXX — <title> (alternative-approach issue capturing the blocker.)
     ```
2. **If NO-GO**: file the alternative-approach issue via `mcp__plugin_workflows_linear-server__save_issue` BEFORE posting the comment, so the comment can reference it. Issue should: name the specific NO-GO blocker; propose 2–3 alternative directions (e.g., 1Password switch, CLI-only-no-MCP-wrap, OAuth migration); set `priority: 2` (High); link `relatedTo: [BC-6905]`; set `team: "Brite Company"`, project: "Brite Plugin Marketplace".
3. **Bitwarden cleanup decision** (user choice — ask via AskUserQuestion):
   - **Keep** the `tam-map-spider-api-key` item: BC-6906 will reuse it as one of the 7 canonical items.
   - **Delete** the spike item: BC-6906 will provision fresh items.
4. **Token cleanup**: Run `bw lock` in the parent shell where `BW_SESSION` is exported. This invalidates the session token that's now in this conversation's transcript. Confirm via `bw status` → reports `locked`.
5. **Spike-PR scope tidy**:
   - If GO: spike POC stays in `scripts/spike-bw-run/` for BC-6906 to reference / replace.
   - If NO-GO: confirm with user whether to delete `scripts/spike-bw-run/` from the spike PR or keep as historical evidence (recommendation: keep, with a "deprecated — see findings doc" note in the README).

**Test**:
- Verify: `mcp__plugin_workflows_linear-server__list_comments` for BC-6905 includes the new comment.
- Verify: `bw status` reports `"status":"locked"` after step 4.

**Verify**: Linear comment visible on BC-6905; vault locked; cleanup decisions recorded in the comment.

---

## Task Dependencies

- **T1 → T2**: Need execution-context decision before user can run vault-write commands cleanly.
- **T2 → T3 not strictly required** (T3 is wrapper construction, doesn't need test item). But T3's smoke tests in T3 step 4 reference the test item, so practically T2 should land first.
- **T3 → T4–T9**: All measurements use the wrapper.
- **T4, T5 are independent of T6** (latency vs handshake — different surfaces). Can run in parallel if user-driven.
- **T6 ← T3** (wrapper must exist for handshake test).
- **T7 ← T6** (Q5 lock-test needs to happen AFTER Q4 because re-unlock costs a session restart in option (A)).
- **T8 ← T6** (Q6 rotation requires real auth round-trips; the SHA instrumentation must land before T8 measurements).
- **T9 ← T2** (collection-share semantic test runs against the same item created in T2; can run anytime after T2).
- **T10 ← T4–T9 all complete**.
- **T11 ← T10 complete**.

## Verification Checklist

- [ ] T1 env-mode decision recorded; `bw status` reports `unlocked` in execution context.
- [ ] T2 vault item `tam-map-spider-api-key` created and shared via Engineering collection.
- [ ] T3 `scripts/spike-bw-run/bw-run.sh` exists, `bash -n` passes, ≤35 lines, all 3 smoke tests pass.
- [ ] T3 `scripts/spike-bw-run/README.md` exists.
- [ ] T4 — Q1/Q2 latency: 5 warm + 1 cold trials recorded with verdict.
- [ ] T5 — Q3 batch latency: 5 warm + 1 cold trials recorded with verdict on batch-vs-sequential crossover.
- [ ] T6 — Q4 handshake: server-info JSON captured, stdout clean.
- [ ] T7 — Q5 lock UX: stderr-clarity verified, stdout empty, exit 1.
- [ ] T8 — Q6 rotation: 3 trials recorded with SHA prefixes; lifecycle-side gap documented as BC-6906 follow-up.
- [ ] T9 — Q7 collection-share: `collectionIds` non-empty, retrieval succeeds.
- [ ] T10 — `docs/research/bw-run-spike.md` complete with all required sections; debug instrumentation stripped from wrapper.
- [ ] T11 — Linear comment on BC-6905 posted; `bw lock` confirmed; spike directory disposition decided.
- [ ] No `.mcp.json` edits in the spike PR (verify via `git diff main -- plugins/marketing/.mcp.json` is empty).
- [ ] No skill edits in the spike PR (verify via `git diff main -- 'plugins/**/skills/**'` is empty).
- [ ] No plugin version bump (verify via `git diff main -- 'plugins/**/plugin.json' '.claude-plugin/marketplace.json'` is empty — BC-6000 doesn't apply because nothing under `plugins/<plugin>/{hooks,skills,commands,agents}/**` changed).
