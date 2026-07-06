# DONE — Regional flagship-retail enrichment

**Completed:** 2026-06-15 ~10:00 CDT (resumed after the 06-15 budget pause). Budget had cleared at the 00:00 UTC rollover; the remaining 29 ran clean. **0 outstanding errors.**

## Final result: 87 of 87 companies enriched

| Outcome | Count | File |
|---|---|---|
| Found usable contacts (persisted to inventory) | **65 companies → 98 unique contacts** | `enrichment-results-regional.jsonl` (raw) · `lists/regional-contacts-found.csv` (readable) |
| Engine searched, found nobody (or only-dropped) | **22 companies** | (in results file, `contacts: []`, `error: null`) |
| Outstanding errors | **0** | — |

> [removed — person-level data lives out-of-repo]

**Addable to campaigns:** **84** deliverable + in-domain (Tier 1, across 56 companies), up to **89** after confirming the 5 domain-mismatch contacts below. 3 undeliverable are dropped.

The 29-company resume queue (`enrichment-REMAINING.jsonl`) is fully processed: 22 found contacts, 7 found nobody. All 5 retried error rows + the 1 quota row from the original queue resolved. Per-batch raw responses archived under `_raw/enrich-resume-2026-06-15/` (kept as audit record).

## ⚠️ Review-before-upload flags (in `regional-contacts-found.csv`, `flag` column)
Emails whose domain ≠ company domain (`DOMAIN-MISMATCH-review`) — verify each is the right person/brand before sending:
- [removed — person-level data lives out-of-repo]
- [removed — person-level data lives out-of-repo]
- [removed — person-level data lives out-of-repo]
- [removed — person-level data lives out-of-repo]
- [removed — person-level data lives out-of-repo]

[removed — person-level data lives out-of-repo]

## 22 found-zero companies = manual scrape candidates
Engine had no usable hit — re-running bulk_enrich won't help. Candidates for the staff-page → ED-extract → web-recovery method (beat Clay on Historic Sites):
`bychristopherking, charlottesinc, cornelishollander, cosbar, devonsdiamondsdecor, fivestoryny, fredsegal, hlorenzo, lesbijoux, londonjewelers, mariscollective, mavericksofscottsdale, molinafinejewelers, octannerjewelers, panachesunvalley, piperjacksonhole, pooleshopcharlotte, secondeditionny, shopmarketmarket, shoptuni, theclotheriescottsdale, ufgrangehall`.

## EB upload — DONE 2026-06-15 (into existing flagship-retail campaigns, ws55)
Operator decision: add the 83 verified Tier-1 leads into the **existing** active flagship campaigns (not new ones), split by recipient ESP:
- **Google → campaign 139** · **Microsoft → campaign 138** · **SMTP/other → campaign 140** (all `active`, plain-text, sequence uses only `{FIRST_NAME}`+`{SENDER_FIRST_NAME}`).
- Path: `POST /api/leads/create-or-update/multiple` (`existing_lead_behavior:"patch"`) → `POST /api/campaigns/{id}/leads/attach-leads` (omit `allow_parallel_sending` so in-sequence leads aren't double-sent). Email→ID maps in `_raw/enrich-resume-2026-06-15/upload/ids-*.json`.

**Landed: 78 unique regional leads** — SMTP 19 + Microsoft 31 + Google 28.
- [removed — person-level data lives out-of-repo]
- Existing-member snapshot at upload time: `_raw/enrich-resume-2026-06-15/existing-members.jsonl` (593 rows across the 3 campaigns).
- Excluded: 5 domain-mismatch (review), 3 undeliverable, 6 unverified-deliverability.

**Expected campaign counts after sync (~5-min lag):** 140 → 347, 138 → ~219, 139 → ~86. (140 confirmed 348 pre-dedupe by operator; net 347 after removing crawfordb.)

## How the resume ran (for next time)
- `mcp__plugin_marketing_enrichment__bulk_enrich`, `persist=true`, `verify=true`, run **INLINE in the main thread** (background agents can't answer permission prompts and share the session token quota — all 4 prior background attempts died).
- **Batches of ≤5, not ≤15.** A 10-company batch returned **HTTP 502** (gateway timeout — verify+persist over 10 exceeds the ~60s MCP host tool-call ceiling). Batches of 5 were reliable; single-company probes always worked.
- `EnrichmentNetworkError` is **transient and bursty** — it hit individual companies (and once 4-of-5 in a batch), but every one succeeded on retry. Re-run network-errored domains; they are NOT found-zero.
- After each batch, append `companies[]` to `enrichment-results-regional.jsonl`, then dedup keep-last per domain (retries supersede old error lines). Regenerate the CSV from the JSONL at the end (region joined from `lists/regional-luxury-targets.csv`; `flag` = undeliverable + domain-mismatch logic).

## Budget (why there's no reset button)
Source: `Brite-Nites/brite-data-platform` → `services/enrichment/operations/cost_ops.py`. The gate sums `cost_usd` from `ENRICHMENT_ATTEMPTS` for the current **UTC day** and blocks at 100% of `enrichment_daily_budget_usd`. Resets only at the UTC date rollover (00:00 UTC = ~7 PM CDT). No reset endpoint/MCP tool. The only manual override is raising `ENRICHMENT_DAILY_BUDGET_USD` on the brite-data-platform **prod Railway service** (shared org-wide ceiling, real-money decision).
