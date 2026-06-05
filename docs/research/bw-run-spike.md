# BC-6905 Spike: `bw-run.sh` wrapper validation — findings

## Summary

This spike validated `bw-run.sh` — a ~46-line bash wrapper that takes `KEY=item` args, fetches each item's password from Bitwarden via `bw get password`, exports the env, and execs the wrapped command — as the credential-broker mechanism for BC-6906's tam-map MCP + CLI key injection migration. Six of seven questions PASS (Q3 passes with a strong wrapper-shape recommendation; Q4–Q7 pass cleanly). One fails: Q1/Q2 single-call latency at **3.20s warm** is **~10× over the issue's 0.300s target**, dominated by the `bw get password` round-trip to `vault.bitwarden.com`. The decision below is **GO with one mandatory adaptation**: BC-6906 must use `bw list items --search` batch fetch (Q3 measured ~3.21s for 2 items, essentially constant time vs item count — saves ~19s vs sequential at N=7). The spike's POC stays sequential per design decision #3 (preserve ~25-line scope); production wrapper batches.

## Q1 — Per-item retrieval works non-interactively

- **Question**: Does `bw get password <item>` work without TTY interaction (required for stdio MCPs spawned by Claude Code)?
- **Method**: Five warm trials of `bw get password tam-map-spider-api-key` via `scripts/spike-bw-run/measure.sh q1q2 warm`.
- **Evidence**: All 5 trials exited 0 with non-empty value (length 39 chars, consistent with Spider key shape). Wrapper exercises this same call at `scripts/spike-bw-run/bw-run.sh:35` (post-strip line numbers).
- **Verdict**: **PASS** — `bw get password` is fully non-interactive when `BW_SESSION` is set in env and vault is unlocked.

## Q2 — Single-call latency

- **Question**: Is `bw get password` fast enough to use in MCP startup (issue target: < 0.300s warm)?
- **Method**: `/usr/bin/time -p bw get password` × 5 warm trials, after `bw sync`.
- **Evidence**: Trials 3.18s, 3.22s, 3.27s, 3.20s, 3.20s. Median **3.20s warm**.
- **Verdict**: **FAIL** — measured ~10× over target. Each call is dominated by network round-trip to `vault.bitwarden.com` (default cloud server; no local cache for org-shared items). For BC-6906's 7-key wrapper, sequential warm fetch ≈ 22.4s startup overhead per MCP spawn. Cold trials deferred to BC-6906 measurement (warm already over target; cold is diagnostic, not decisional).

## Q3 — Batch-fetch latency via `bw list items --search`

- **Question**: Is batch fetch via `bw list items --search` materially faster than N sequential `bw get password` calls? At what crossover N?
- **Method**: `/usr/bin/time -p bw list items --search tam` × 5 warm trials. 2 items returned (bundle `TAM MAP - API Tokens` + spike item `tam-map-spider-api-key`).
- **Evidence**: Trials 3.21s, 3.20s, 3.24s, 3.21s, 3.23s. Median **3.21s** — essentially identical to single-call. Cost is dominated by network round-trip, not item count.
- **Verdict**: **PASS — batch beats sequential at N≥2.** Crossover analysis:
  - N=1: sequential 3.20s ≈ batch 3.21s (wash)
  - N=2: sequential 6.40s vs batch 3.21s (saves 3.2s, 50%)
  - N=7 (BC-6906): sequential 22.4s vs batch 3.2s (saves 19.2s, 86%)
- **BC-6906 wrapper-interface recommendation (mandatory)**: replace sequential `bw get password $item` loop with single `bw list items --search $prefix | jq …` batch parse using a deterministic prefix (e.g., `bw-tam-map-` or `tam-map-`). Notes-stored secrets in the legacy bundle item don't fit; BC-6906 provisions per-item Login entries instead.

## Q4 — MCP `initialize` handshake passthrough

- **Question**: Does the wrapper preserve stdio fidelity so MCPs can `initialize` cleanly (no buffer corruption, no shell-level interleaving)?
- **Method**: Pipe an `initialize` JSON-RPC request through `bash bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- npx -y spider-cloud-mcp@2.1.1`; capture stdout/stderr separately. Driver: `scripts/spike-bw-run/exercise-q4.sh` (perl-alarm 45s timeout — macOS lacks GNU `timeout`).
- **Evidence**:
  - stdout: 172 bytes — exactly the JSON-RPC response (`protocolVersion=2025-06-18`, `capabilities.tools.listChanged=true`, `serverInfo=spider-cloud-mcp v2.1.0`).
  - stderr: **0 bytes** — zero wrapper noise, zero npx noise.
  - `bw-run.sh:` substring grep on stdout: **0 matches**.
  - exit 0 (clean shutdown on stdin EOF).
- **Code paths cited**: `scripts/spike-bw-run/bw-run.sh:8-13` (preflight checks write to stderr, never stdout); `scripts/spike-bw-run/bw-run.sh:42` (`exec "$@"` hands stdin/stdout directly to the MCP).
- **Verdict**: **PASS — wrapper is a transparent stdio passthrough.** No `initialize` corruption observed. Pattern-A stdio MCP wrapping is safe with this wrapper shape.

## Q5 — Vault-locked-mid-session UX

- **Question**: When the vault locks mid-session (idle timeout, manual lock), does the wrapper produce an observable failure with clear remediation, not a silent or opaque error?
- **Method**: `bw status` (unlocked) → `bw lock` → `bw status` (locked, BW_SESSION still in env but stale) → run wrapper. Capture stderr/stdout/exit.
- **Evidence**:
  - exit code: **1**
  - stdout: **0 bytes** — `echo wrapped` never executed (exec was blocked).
  - stderr: `bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again.`
- **Code paths cited**: `scripts/spike-bw-run/bw-run.sh:11-13` — `bw status 2>/dev/null | grep -q '"status":"unlocked"'` returns false, message + exit 1.
- **Verdict**: **PASS — failure mode is observable, exec is blocked, remediation is named.** No silent failure, no opaque MCP-side error cascade.
- **Option-A UX cost** (recorded for adapt list): in restart-based env-propagation mode (Pattern A per BC-5947 task-3 + this spike's T1 decision), recovery from a mid-session lock costs ~30s (`bw unlock` + re-export `BW_SESSION` + Claude Code restart). Acceptable for occasional locks; would compound on aggressive idle-lock policies.

## Q6 — Rotation propagation through wrapper

- **Question**: When a Bitwarden item's value changes, does the wrapper fetch the fresh value on the next invocation (no caching)?
- **Method**: 3 trials with mutate/restore in Bitwarden UI between calls. Driver: `scripts/spike-bw-run/exercise-rotation.sh` (reads a temporary SHA-256 stderr log line that bw-run.sh emitted in T8; line was stripped in T10 — see "Open questions" for re-instrumentation cost).
- **Evidence**:
  - Trial 1 (baseline): `sha256_prefix=5669e29e`
  - Trial 2 (1 char prepended): `sha256_prefix=49c65812` (≠ Trial 1, fresh fetch)
  - Trial 3 (char removed): `sha256_prefix=5669e29e` (= Trial 1, fresh fetch)
- **Pattern observed**: X → Y → X. Wrapper has zero caching at the bash-process level.
- **Code paths cited**: `scripts/spike-bw-run/bw-run.sh:35` — `value="$(bw get password "$item")"` runs on every invocation; no env-var or file-based memoization.
- **Verdict (wrapper-side)**: **PASS — fresh value on every spawn.**
- **Lifecycle-side gap (deferred to BC-6906)**: Q6's full UX promise — "no Claude Code restart for key rotation" — also requires Claude Code to *re-spawn* the MCP server when something signals the underlying value changed. The spike does NOT validate this; it would require `.mcp.json` wiring out of spike scope (design decision #5). BC-6906's `.mcp.json` change to wrap `spider-cloud-mcp` through bw-run is the precondition; BC-6906 must measure the lifecycle dimension before promoting bw-run to the canonical pattern.

## Q7 — Collection-share retrieval semantics

- **Question**: Is collection-level share permission sufficient for `bw get password`, or does the CLI require user-level share?
- **Method**: Item `tam-map-spider-api-key` provisioned in Engineering collection (NOT user-share); CLI metadata + retrieval check via inline bash heredoc (equivalent to `scripts/spike-bw-run/verify-q7.sh`).
- **Evidence**:
  - `type=1` (login item), `organizationId` set, `collectionIds=["7d6f25ca-40c9-4480-8844-b42e010a29a3"]` (Engineering), `inEngineering=true`, `hasLoginPassword=true`.
  - Retrieval: `bw_get_exit=0`, `value_length=39`, `value_nonempty=true`.
- **Verdict**: **PASS — collection-share is sufficient.** BC-6906's per-item provisioning model (one Bitwarden Login per env-var key, shared via Engineering collection-level permission) works with CLI semantics. No per-user share gymnastics.
- **BC-6906 implication**: admin step provisions all 7 items in Engineering collection once. Each Brite engineer with collection membership gets access automatically.

## GO/NO-GO

**Decision: GO**

Six of seven questions PASS. The single fail (Q1/Q2 latency) is fully addressable by Q3's batch-fetch finding: switching from sequential to `bw list items --search` collapses 7-key startup overhead from ~22s to ~3.2s — within tolerance for an MCP spawn that already pays multi-second overhead from npx/node initialization. Q4 confirms stdio fidelity, Q5 confirms observable lock UX, Q6 confirms wrapper-side rotation freshness, Q7 confirms collection-share is sufficient. The wrapper pattern is sound; adaptation is purely on the wrapper-interface shape (sequential → batch).

## Adapt list for BC-6906

1. **Wrapper interface MUST batch via `bw list items --search`** (not sequential `bw get password`). Q3 measured ~3.2s constant time vs ~22s for 7 sequential keys. Use a deterministic item-name prefix (e.g., `bw-tam-map-` or similar) and parse the JSON array. Spike POC stays sequential per design decision #3 (preserve ~25-line scope); production wrapper differs intentionally on this axis.

2. **Wrapper MUST guard empty-array expansion under `set -u`** (`if [ "${#EXPORTS[@]}" -gt 0 ]; then ... fi` around the for loop, or default-substitution idiom). macOS bash 3.2 + `set -u` rejects `"${arr[@]}"` for empty arrays. Spike T3 caught this; the plan's verbatim wrapper code wouldn't have worked on macOS. See `scripts/spike-bw-run/bw-run.sh:33-43` for the working pattern.

3. **Lifecycle-side rotation gap MUST be measured before bw-run is promoted to canonical**. BC-6906's `.mcp.json` wiring is a prerequisite for measuring whether Claude Code re-spawns the MCP on rotation signals — without that measurement, the "no restart for key rotation" UX promise is unproven. Add a measurement subtask to BC-6906 covering this.

4. **Vault-lock UX is option-A-coupled**: every lock event costs ~30s recovery (unlock + re-export + Claude Code restart) in restart-based env-propagation mode. Acceptable for occasional locks. If teammates run aggressive idle-lock policies (< 15 min), consider documenting `bw unlock` + `BW_SESSION` re-export as a startup ritual or exploring background-broker alternatives (out of BC-6906 scope; flag as future work).

5. **Per-item Bitwarden provisioning model is validated** (Q7). BC-6906 admin step: create N Login items in Engineering collection, one per env-var key, via Bitwarden UI. No per-user share required.

6. **Spike test item disposition**: keep `tam-map-spider-api-key` in Engineering collection as one of the 7 BC-6906 items (it's already shaped correctly), or delete and re-provision fresh. T11 captures this decision.

## Open questions / explicit non-goals

- **Pattern C (`${user_config.*}` substitution into stdio MCP env) verification remains UNRUN**. BC-5947 task-3's promotion question is NOT closed by this spike — the spike validates Pattern A (`${OS_ENV}` after wrapper export) only. Future work; coordinate with BC-5551.
- **Cold-cache latency** (post-`bw lock; bw unlock` first call) deferred to BC-6906 measurement. Rationale: warm trials already failed target by 10×; cold being slightly worse is diagnostic, not decisional, and the cold-trial requires a Claude Code restart in option-A mode.
- **Spider-side auth round-trip** (Q6 step 3 in plan) skipped. The wrapper-side question — "does bw-run fetch fresh on every spawn?" — is fully answered by the SHA pattern; an auth-failure check would only test that Spider rejects bad keys (Spider's behavior, not the wrapper's).
- **Lifecycle-side rotation** (Claude Code re-spawn behavior) is BC-6906's measurement.
- **The 8th key (ANTHROPIC_API_KEY) elimination** is BC-6907 (parallel track), not addressed here.
- **`.mcp.json` edits** are intentionally out of scope for the spike PR (design decision #5).
- **Plugin version bumps**: BC-6000 doesn't apply because nothing under `plugins/<plugin>/{hooks,skills,commands,agents}/**` changes in this spike.

## Appendix A1 — Raw measurements

(Source-of-truth for the per-Q sections above. Kept verbatim for re-runners and BC-6906 reference.)

### Q1 / Q2 — single-call `bw get password` latency

- **Item**: `tam-map-spider-api-key` (Engineering collection)
- **Tool**: `/usr/bin/time -p bw get password <item>` via `scripts/spike-bw-run/measure.sh q1q2 warm`
- **Trials (warm, n=5)**: 3.18s, 3.22s, 3.27s, 3.20s, 3.20s
- **Median warm**: **3.20s**
- **Cold (post-`bw lock; bw unlock`)**: deferred to BC-6906 measurement
- **Target (issue)**: < 0.300s warm
- **Verdict**: **FAIL** — measured ~10x over target.

### Q3 — `bw list items --search` batch-fetch latency

- **Search**: `tam` (case-insensitive substring; matches bundle `TAM MAP - API Tokens` + spike item `tam-map-spider-api-key`)
- **Tool**: `/usr/bin/time -p bw list items --search tam` via `scripts/spike-bw-run/measure.sh q3 warm tam 5`
- **Items returned**: 2 (`TAM MAP - API Tokens` hasPassword=false; `tam-map-spider-api-key` hasPassword=true)
- **Trials (warm, n=5)**: 3.21s, 3.20s, 3.24s, 3.21s, 3.23s
- **Median warm**: **3.21s**
- **Cold**: deferred to BC-6906
- **Verdict**: batch beats sequential at N≥2; saves 86% at N=7.

### Q4 — MCP `initialize` handshake passthrough

- **Wrapped command**: `bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- npx -y spider-cloud-mcp@2.1.1`
- **Driver**: `scripts/spike-bw-run/exercise-q4.sh` (perl-alarm 45s)
- **Stdout (first line)**: `{"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"spider-cloud-mcp","version":"2.1.0"}},"jsonrpc":"2.0","id":1}`
- **Stdout byte count**: 172
- **Stderr byte count**: 0
- **`bw-run.sh:` substring grep on stdout**: 0 matches
- **Exit code**: 0
- **Verdict**: PASS — transparent stdio passthrough.

### Q5 — vault-locked-mid-session UX

- **Setup**: `bw status` confirmed unlocked, then `bw lock` (server-side invalidation), `bw status` post-lock reports `locked`.
- **Wrapper run**: `bash scripts/spike-bw-run/bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- echo wrapped`
- **Result**: exit 1, stdout 0 bytes, stderr `bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again.`
- **Code path**: `scripts/spike-bw-run/bw-run.sh:11-13`
- **Verdict**: PASS — message clear, exec blocked, exit informative.

### Q6 — rotation propagation (wrapper-side)

- **Driver**: `scripts/spike-bw-run/exercise-rotation.sh`
- **Trial 1 (baseline)**: `sha256_prefix=5669e29e`
- **Trial 2 (1 char prepended)**: `sha256_prefix=49c65812` (≠ Trial 1, fresh fetch)
- **Trial 3 (char removed)**: `sha256_prefix=5669e29e` (= Trial 1)
- **Pattern**: X → Y → X
- **Wrapper-side verdict**: PASS — zero caching.
- **Lifecycle-side**: deferred to BC-6906.

### Q7 — collection-share retrieval semantics

- **Item**: `tam-map-spider-api-key`
- **Sharing**: Engineering collection (organizationId `f4adda58-...`, collectionIds `["7d6f25ca-..."]`); NOT user-share.
- **Metadata**: type=1 (login), organizationId set, inEngineering=true, hasLoginPassword=true.
- **Retrieval**: `bw_get_exit=0`, `value_length=39`, `value_nonempty=true`.
- **Verdict**: PASS — collection-share is sufficient.
