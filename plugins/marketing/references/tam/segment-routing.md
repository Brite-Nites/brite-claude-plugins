---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: prompts/segment-routing.md
license: MIT
ported: 2026-04-24
---

# Segment Routing

How to route the 4 output CSVs to your sender infrastructure.

---

## The segments

The `icp-scoring` skill's `abc` rubric emits four CSVs per run (delegated from `tam-mapping` Phase 7; previously emitted by `scripts/tier_and_segment.py` — removed per BC-6907):

| File | What it contains | Routing |
|------|------------------|---------|
| `tier-a.csv` | High-fit, valid email, non-catch-all | Primary campaign, best sender group |
| `tier-b.csv` | Medium-fit, valid email, non-catch-all | Secondary campaign, standard sender group |
| `tier-c.csv` | Weak-fit, valid email, non-catch-all | Warmup cadence only, or skip |
| `catch-all.csv` | Any catch-all domain (A/B/C mixed) | **Isolated** sender group, separate warmup |

---

## Why catch-all is isolated

Catch-all domains accept every email at the SMTP layer but route invalid addresses to a black hole (or bounce later). Mixing catch-all into your main campaigns:

1. **Inflates your apparent send volume** — 1000 catch-all emails might only reach 400 real inboxes
2. **Skews your reply rate down** — replies only come from real recipients
3. **Burns sender reputation slowly** — bounces land in soft-bounce buckets that provider filters track
4. **Triggers agency-heavy TAM bounce spikes** — some verticals bounce heavily at delivery even when SMTP says "valid"

Route catch-all into a sender group that you've warmed specifically for higher-risk sends. Monitor bounce rate at 5% (auto-pause) / 3% (flag).

---

## Campaign configuration checklist

For each segment:

- [ ] Open tracking **OFF** (deliberate policy — privacy + false signal)
- [ ] Reply tracking **ON** (the only signal that matters)
- [ ] Max 2 sequence steps (no breakup emails)
- [ ] Daily send limit per campaign, not per sender
- [ ] Separate catch-all into its own sender group
- [ ] 14-day warmup before catch-all campaigns go live
- [ ] Circuit breaker: auto-pause at >5% bounce, flag at 3-5%

---

## Upload format

Most tools (EmailBison, Smartlead, Instantly, Lemlist, etc.) accept CSV with these columns:

```
email, first_name, last_name, company, domain, title, linkedin_url, phone, tier
```

The `icp-scoring` skill (`abc` rubric) writes the input row shape plus a `tier` column — so when fed `tam-mapping`'s `verified-flat.csv` (6 firmographic columns), the tier CSVs carry firmographic + tier only. For the full contact-level upload shape including `email`/`first_name`/`title`/`linkedin_url`/`phone`, consume `list-building`'s `enriched_leads.csv` (BC-2717) and join on `domain` — that's the two-feeder split documented in `plugins/marketing/skills/tam-mapping/SKILL.md` § "Note on the two icp-scoring upstream feeders." Custom variables (`tier`, `domain`) flow through as merge fields if your sender supports it.
