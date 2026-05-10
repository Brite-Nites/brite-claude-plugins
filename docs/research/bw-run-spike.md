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
