---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: examples/roofing-contractors-tx.md
license: MIT
ported: 2026-04-24
---

# Worked Example — Roofing Contractors (TX)

Full TAM build walkthrough. Shows the commands, intermediate outputs, and final segments.

---

## 1. Invoke the skill

```bash
claude /tam-map "roofing contractors in TX, 5-50 employees, storm-damage specialists"
```

## 2. ICP resolution

Claude converts the prompt into `output/roofing-tx/icp.json`:

```json
{
  "industries": ["roofing", "storm damage restoration"],
  "geo": { "country": "US", "regions": ["TX"] },
  "size_band": { "employee_min": 5, "employee_max": 50 },
  "intent_signals": ["storm damage", "hail repair", "insurance claims"],
  "exclusions": ["franchises"]
}
```

## 3. Discovery (parallel)

```bash
python scripts/aiark_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/aiark.jsonl &
python scripts/discolike_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/discolike.jsonl &
python scripts/icypeas_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/icypeas.jsonl &
wait
```

## 4. Dedupe + crawl

```bash
jq -s 'add' output/roofing-tx/{aiark,discolike,icypeas}.jsonl | \
  jq 'unique_by(.domain)' > output/roofing-tx/companies.jsonl

python scripts/spider_crawl.py --in output/roofing-tx/companies.jsonl \
  --out output/roofing-tx/crawled.jsonl
```

## 5. Enrich + verify

```bash
python scripts/enrich_waterfall.py \
  --in output/roofing-tx/crawled.jsonl \
  --out output/roofing-tx/enriched.jsonl

python scripts/verify_smtp.py \
  --in output/roofing-tx/enriched.jsonl \
  --out output/roofing-tx/verified.jsonl
```

## 6. Tier + segment

```bash
python scripts/tier_and_segment.py \
  --in output/roofing-tx/verified.jsonl \
  --out-dir output/roofing-tx/segments/
```

## 7. Final output

```
output/roofing-tx/segments/
├── tier-a.csv        # high-fit, verified emails → primary campaign
├── tier-b.csv        # medium-fit → secondary campaign
├── tier-c.csv        # lower-fit → cold warmup campaign
└── catch-all.csv     # catch-all domains → isolated campaign
```

Upload each CSV to its own campaign in EmailBison. Catch-all goes to a separately-warmed sender group to contain bounce risk.

---

## Typical drop-offs

These are illustrative — your numbers will vary by vertical and geography.

| Step | Input | Drop reason | Output |
|------|-------|-------------|--------|
| Discovery | — | — | Raw companies |
| Dedupe | Raw | Same domain across sources | Unique domains |
| Crawl | Unique | No responsive website | Crawled |
| Enrich | Crawled | No owner found / no email | Enriched |
| SMTP verify | Enriched | Invalid / unknown | Verified (valid + catch-all) |
| Catch-all split | Verified | Catch-all → separate segment | Valid only |
| Tier | Valid | None (classification) | A / B / C segments |

---

## Runbook for your first campaign

1. Start with tier-a only (highest-fit, lowest risk)
2. Warm up catch-all senders for 14 days before launching catch-all campaigns
3. Track reply-only (never opens)
4. Auto-pause any segment hitting >5% bounce (circuit breaker)
5. Move unresponsive tier-a to tier-b cadence after 2 sequence steps
