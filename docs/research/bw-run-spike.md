# BC-6905 Spike: `bw-run.sh` wrapper validation — findings (DRAFT)

> Status: DRAFT — measurements are accumulating in Appendix A1; full
> structured Q1–Q7 evaluation, GO/NO-GO decision, and BC-6906 adapt list
> land in T10. Raw measurements below are the source of truth for those
> sections.

## Appendix A1 — Raw measurements

(T4–T9 append here, one subsection per question. T10 promotes findings
into the structured `## Q1` … `## Q7` sections above this appendix.)

### Q1 / Q2 — single-call `bw get password` latency

- **Item**: `tam-map-spider-api-key` (Engineering collection)
- **Tool**: `/usr/bin/time -p bw get password <item>` via `scripts/spike-bw-run/measure.sh q1q2 warm`
- **Trials (warm, n=5)**: 3.18s, 3.22s, 3.27s, 3.20s, 3.20s
- **Median warm**: **3.20s**
- **Cold (post-`bw lock; bw unlock`)**: deferred to T7 lock-cycle (combines with Q5 re-unlock to save a Claude Code restart per env-propagation gotcha)
- **Target (issue)**: < 0.300s warm
- **Verdict**: **FAIL** — measured ~10x over target. Each call is dominated by network round-trip to `vault.bitwarden.com` (default cloud server; no local cache for `bw get` of org-shared items). For BC-6906's 7-key wrapper, sequential warm fetch ≈ 7 × 3.20s ≈ 22.4s startup overhead per MCP spawn that needs all keys. For tam-map's 2 MCP keys (spider_crawl, enrich_waterfall) ≈ 6.4s — tolerable but noticeable. Q3 batch-fetch latency below determines whether wrapper interface should evolve to single-call batch fetch in BC-6906.

### Q3 — `bw list items --search` batch-fetch latency

- **Search**: `tam` (case-insensitive substring; matches bundle `TAM MAP - API Tokens` + spike item `tam-map-spider-api-key`)
- **Tool**: `/usr/bin/time -p bw list items --search tam` via `scripts/spike-bw-run/measure.sh q3 warm tam 5`
- **Items returned**: 2 (`TAM MAP - API Tokens` hasPassword=false → Notes-only bundle; `tam-map-spider-api-key` hasPassword=true → Login.password per BC-6906's per-item model)
- **Trials (warm, n=5)**: 3.21s, 3.20s, 3.24s, 3.21s, 3.23s
- **Median warm**: **3.21s**
- **Cold (post-`bw lock; bw unlock`)**: deferred to T7 lock-cycle
- **Verdict for BC-6906**: **batch beats sequential at N≥2.** Batch latency is essentially identical to single-call (3.21s vs Q1/Q2's 3.20s) — cost is dominated by network round-trip, not item count. Crossover analysis:
  - N=1: sequential ≈ 3.20s, batch ≈ 3.21s — wash
  - N=2: sequential ≈ 6.40s, batch ≈ 3.21s — batch saves ~3.2s (50%)
  - N=7 (BC-6906 all keys): sequential ≈ 22.4s, batch ≈ 3.2s — batch saves ~19s (86%)
- **BC-6906 wrapper-interface recommendation**: replace sequential `bw get password $item` loop with single `bw list items --search $prefix | jq …` batch parse. Spike's POC stays sequential per design decision #3 (simplicity for ~25-line spec); production wrapper should batch.
- **Caveat**: `bw list items --search` returns full item objects including `.login.password`. Use a deterministic prefix (e.g., `tam-map-` for tam-map keys) to scope the batch. Notes-stored secrets (the existing bundle shape) need separate handling — BC-6906 provisions per-item Login entries instead.

### Q4 — MCP `initialize` handshake passthrough

- **Wrapped command**: `bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- npx -y spider-cloud-mcp@2.1.1`
- **Driver**: `scripts/spike-bw-run/exercise-q4.sh` (perl-alarm 45s timeout — macOS has no GNU `timeout`/`gtimeout`)
- **Stdin**: `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"bc-6905-spike","version":"0"}}}`
- **Stdout (first line)**: `{"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"spider-cloud-mcp","version":"2.1.0"}},"jsonrpc":"2.0","id":1}`
- **Stdout byte count**: 172 (just the response — nothing else)
- **Stderr byte count**: **0** (zero wrapper noise, zero npx noise)
- **`bw-run.sh:` substring grep on stdout**: 0 matches
- **Exit code**: 0 (clean shutdown on stdin EOF)
- **Server reported**: `protocolVersion=2025-06-18`, `serverInfo.name=spider-cloud-mcp`, `serverInfo.version=2.1.0` (npm resolved `@2.1.1` request to `2.1.0` — server-side tag, not a wrapper concern)
- **Verdict**: **PASS — wrapper is a transparent stdio passthrough**. `bw-run.sh` writes its own preflight checks to stderr (lines `scripts/spike-bw-run/bw-run.sh:9-13`), never to stdout, and uses `exec "$@"` (`scripts/spike-bw-run/bw-run.sh:46`) so the MCP inherits stdin/stdout directly with no shell-level buffering or interleaving. No corruption of MCP `initialize` request/response observed.

### Q7 — collection-share retrieval semantics

- **Item**: `tam-map-spider-api-key` (provisioned in T2 via Bitwarden web UI)
- **Sharing**: Engineering collection (organizationId `f4adda58-...`, collectionIds `["7d6f25ca-...]"`); explicitly NOT user-share
- **Driver**: inline bash heredoc (content equivalent to `scripts/spike-bw-run/verify-q7.sh`, kept on disk for repro)
- **Metadata projection**: type=1 (login), organizationId set, inEngineering=true, hasLoginPassword=true
- **Retrieval check**: `bw_get_exit=0`, `value_length=39` (consistent with Spider's typical alphanumeric key length), `value_nonempty=true`
- **Verdict**: **PASS — collection-share is sufficient for `bw get password`**. BC-6906's per-item provisioning model (one Bitwarden Login item per env-var key, shared via Engineering collection-level permission, NOT individually user-shared) works with CLI semantics. No per-user share gymnastics required.
- **BC-6906 implication**: admin step provisions 7 items in Engineering collection via Bitwarden UI. Each Brite engineer gets access automatically through their collection membership. No per-user provisioning needed.

### Q6 — rotation propagation (wrapper-side)

- **Item**: `tam-map-spider-api-key` (Engineering collection)
- **Driver**: `scripts/spike-bw-run/exercise-rotation.sh` — runs the wrapper with a `true` no-op tail and reads the temporary SHA-256-prefix log line that bw-run.sh emits to stderr (added in T8, stripped in T10 per plan)
- **Trials** (each with `bw sync` first, then a fresh wrapper invocation):
  - Trial 1 (baseline): `sha256_prefix=5669e29e`, exit 0
  - Trial 2 (post-mutation — single char prepended in Bitwarden UI, saved, sync'd): `sha256_prefix=49c65812`, exit 0 (≠ Trial 1, fresh fetch)
  - Trial 3 (post-restoration — char removed, saved, sync'd): `sha256_prefix=5669e29e`, exit 0 (= Trial 1, fresh fetch back to baseline)
- **Pattern observed**: X → Y → X. Wrapper has zero caching; every invocation runs `bw get password` afresh. No stale-value risk.
- **Wrapper-side verdict**: **PASS — fresh value on every spawn.** No caching observed at wrapper layer.
- **Lifecycle-side gap (deferred to BC-6906)**: Q6's full UX promise — "no Claude Code restart for key rotation" — also requires Claude Code to *re-spawn* the MCP server when something changes (e.g., a tool call after rotation). The spike does NOT validate this dimension because doing so requires `.mcp.json` wiring (out of spike scope per design decision #5). BC-6906's `.mcp.json` change to wrap `spider-cloud-mcp` through bw-run is the necessary precondition; BC-6906 must measure the lifecycle dimension before promoting bw-run to the canonical pattern.
- **Spider-auth round-trip not run**: Plan T8 step 3 originally suggested calling a Spider tool (`spider_get_credits`) to confirm the new value reached Spider. Skipped because the wrapper-side question is fully answered by the SHA pattern; Spider-auth would only test that Spider rejects bad keys, which is Spider's behavior, not the wrapper's. Saved scope.

### Q5 — vault-locked-mid-session UX

- **Setup**: `bw status` confirmed unlocked, then `bw lock` invalidated the session server-side. `bw status` post-lock reports `locked` (BW_SESSION env var still in shell, but the token is now stale — server rejects it).
- **Wrapper run**: `bash scripts/spike-bw-run/bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- echo wrapped`
- **Result**:
  - exit code: **1** ✓
  - stdout: **0 bytes** — `echo wrapped` never executed (exec was blocked)
  - stderr: `bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again.`
- **Checks (all PASS)**:
  - stderr contains `bw unlock` ✓
  - stdout does NOT contain `wrapped` ✓
  - exit code = 1 ✓
- **Code paths cited**:
  - `scripts/spike-bw-run/bw-run.sh:7-9` — BW_SESSION-not-set branch (not exercised here; BW_SESSION was still set, just stale)
  - `scripts/spike-bw-run/bw-run.sh:11-13` — `bw status` returns `"status":"locked"`, grep fails, stderr message + exit 1 (exercised here)
- **Verdict**: **PASS — message clear, exec blocked, exit code informative**. Failure mode is observable (stderr message names the remediation: `bw unlock`), and the wrapped command never sees a partially-initialized environment. No silent failure, no opaque MCP-side error cascade.
- **Option-A UX cost** (recorded for findings/adapt list): in restart-based env-propagation mode (Pattern A per BC-5947 task-3 + this spike's T1 decision), recovering from a mid-session lock means: user `bw unlock`s in parent shell, exports new `BW_SESSION`, restarts Claude Code. ~30 seconds of ergonomic friction per lock event. Acceptable for occasional locks; would compound for users on aggressive vault-lock policies (e.g., 5-min idle timeout).
