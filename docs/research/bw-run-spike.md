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
