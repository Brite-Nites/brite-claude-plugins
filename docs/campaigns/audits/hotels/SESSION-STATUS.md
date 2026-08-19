# Hotels — Lead Audit (2026-07-28, completed 2026-08-05)

> **2026-08-05 revision.** The original run concluded campaign #14's 67,509 leads were
> unreachable past the 15,000-row offset cap. **That was wrong** — `?pagination_type=cursor`
> bypasses it on this exact endpoint (it was already recorded in
> `reference_eb_pagination_filter_traps` and went unread). All 67,509 have now been pulled.
> The headline #56/#60 figures below are unchanged; the full-universe numbers are new, and
> they surface a **major list-quality problem in #14** — see "The #14 contamination problem."

**State: audit complete, nothing built. No campaign staged, no copy written, nothing sending.**
Source of truth = Email Bison (b2b ws55). CSVs here are a point-in-time snapshot — re-run `pull.py` + `audit.py` before acting on them.

## Why this exists

Hotels are the highest-volume vertical Brite has ever mailed (142,460 sends) and went quiet
2026-05-14. This audit answers: what audience is left, how much of it is clean, and who
already engaged — ahead of building a new hotels campaign.

## The campaigns

| ID | Campaign | Status | Sent | First send | Last send |
|---|---|---|--:|---|---|
| 60 | FY26, M3 \| Hotels Summer Activation \| Managers+ (Reverified) | completed | 14,346 | 2026-04-01 | **2026-05-14** |
| 56 | FY26, M3 \| Hotels Summer Activation \| Managers+ | paused | 1,180 | 2026-03-24 | 2026-03-31 |
| 14 | FY25, M10 \| Hotels \| Managers+ \| Professional Emails | completed | 126,934 | 2025-10-27 | 2025-12-09 |
| 135/136/137 | FY26, M07 \| Hotels & Resorts \| Custom Illuminated Artwork (MS/Google/SMTP) | draft | 0 | — | never sent |
| ws13 #2 | FY25, M11 \| Hotels \| Personal Emails | archived | 0 | — | never sent |

Campaigns 135/136/137 are a **Labs experiential** pitch (custom illuminated artwork), not a
Nites holiday-decor pitch. Built, zero leads, never launched. Unresolved whether that was
abandoned deliberately.

## Headline numbers

**Full universe (all three campaigns, complete):**

| Metric | Value |
|---|--:|
| Unique contacts across #14 + #56 + #60 | 69,380 |
| — burned (bounced / unsub) | 3,389 |
| — prior repliers | 3,408 |
| **Re-mailable, all campaigns** | **62,583** |
| — of which on the newer #56/#60 lists | 9,253 |
| — of which from #14 only (8–9 mo old, contaminated) | 53,330 |
| Zero sends **on #56** (but mailed elsewhere — see below) | 6,604 |
| **Truly unmailed anywhere** | **0** |
| Total unique repliers | 3,425 |
| — flagged `interested` | **38** |

**Recommended working set: the 9,253.** The 53,330 is not a clean hotel list — see below.

## ⚠️ THERE IS NO FRESH HOTEL INVENTORY

**Not one of the 69,380 contacts is unmailed.** Total emails ever received, across every
campaign each lead belongs to:

| Emails received | Contacts |
|---|--:|
| **0** | **0** |
| 1 | 4,796 |
| 2 | 55,110 |
| 3+ | 9,474 |

**A corrected earlier claim:** #56's 6,604 `sending_paused` leads were described in an
earlier revision of this doc as "never mailed — no fatigue, cheapest send, start here."
**That was wrong.** `emails_sent: 0` in `lead_campaign_data` is CAMPAIGN-scoped: those
leads got zero sends *on #56*, but all 6,604 had already been contacted via #14 and/or
#60 — 4,421 of them received four emails. To count true exposure you must SUM
`emails_sent` across every entry in `lead_campaign_data`, not read one campaign's.

**Consequence for planning:** a new hotels campaign is entirely **re-engagement**, not
fresh outreach. The least-exposed segment is the 4,796 who received a single email. If
untouched audience is needed, it has to come from net-new list building.

**Campaign overlap — the newer lists are 82% recycled from #14:**

| Membership | Contacts |
|---|--:|
| #14 only | 59,158 |
| #14 + #56 + #60 | 4,812 |
| #14 + #56 | 2,709 |
| #60 only | **1,871** ← the only net-new contacts since #14 |
| #14 + #60 | 830 |

Of the 10,222 on the newer lists, 8,351 were already on #14. Only 1,871 are net-new.

## The #14 contamination problem

Campaign #14 was not built as a hotel list. It looks like a broad "travel & hospitality"
scrape. Largest domains in its 53,330-contact re-mailable pool:

| Domain | Contacts | What it is |
|---|--:|---|
| marriott.com | 1,912 | hotel ✓ |
| hilton.com | 1,282 | hotel ✓ |
| **delta.com** | **1,162** | **airline** |
| **coca-cola.com** | **1,021** | **beverage/CPG** |
| hyatt.com | 853 | hotel ✓ |
| **ehi.com** | **821** | **Enterprise rental car** |
| **united.com** | **633** | **airline** |
| **aa.com** | **606** | **airline** |
| **aramark.com** | **494** | **food service** |
| ihg.com | 449 | hotel ✓ |

Tagging only the obviously-non-hotel domains:

| Category | Contacts |
|---|--:|
| Airlines | 3,299 |
| Food service / CPG | 1,808 |
| Rental car | 1,591 |
| Casinos (Brite's own separate vertical) | 1,006 |
| Cruise lines | 494 |
| Parking / entertainment | 405 |
| Travel management | 341 |
| **Total tagged** | **8,944 (16.8%)** |

**That 16.8% is a floor, not a ceiling** — only the top domains were classified; the long
tail is unexamined. **Do not mail the #14-only pool without re-qualifying it against the
hotel ICP first.**

Quality corroborates: title coverage is **100% on #56/#60 but only 84.4%** across the full
pool. The newer lists are the better-built ones.

## Per-campaign state

From each lead's `lead_campaign_data` (campaign-scoped). The API's status *filters* read
**global** lead status, not per-campaign — that's why a filtered query returns
`never_contacted: 0` for #56 despite 6,604 leads there having zero sends. Always use
`lead_campaign_data`.

**#60 — 7,513 attached.** sequence_finished 6,967 · replied 292 · bounced 251 · stopped 3.
Emails sent: 7,087 got both steps, 423 got one, 3 got none. Ran to completion.

**#56 — 7,521 attached.** **sending_paused 6,866** · sequence_finished 286 · stopped 281 ·
replied 50 · bounced 38. Emails sent: **6,604 got zero**, 616 got one, 301 got both.
Died at 8% completion.

**#14 — 67,509 attached** (counts only, see coverage gap). replied 3,143 ·
sequence_finished 61,257 · verified 62,609 · unverified 1,588.

## List overlap — #60 is NOT a clean re-verification of #56

| | Count |
|---|--:|
| On both | 4,812 |
| Only #60 (re-verified) | 2,701 |
| Only #56 (original) | 2,709 |

Only 47% overlap. **Working from either list alone drops ~2,700 contacts.** Use the union.

## Company & contact coverage

2,897 domains / 9,253 contacts = **3.19 per domain**, heavily skewed.

| Contacts on domain | Domains |
|---|--:|
| 1 | 1,886 |
| 2 | 446 |
| 3 | 189 |
| 4 | 98 |
| 5 | 57 |
| 6–10 | 111 |
| 20+ | 8 |

**Largest domains:** hilton.com 845 · hyatt.com 369 · marriott.com 286 · ihg.com 186 ·
hgv.com 125 · fourseasons.com 106 · highgate.com 99 · ritzcarlton.com 70 · wyn.com 68 ·
vailresorts.com 67 · aubergeresorts.com 64 · aimbridge.com 58.

⚠️ **Dedup on PROPERTY, not mail domain.** 845 hilton.com contacts is a corporate directory,
not 845 hotels. Sending per-domain would fire hundreds of emails into a handful of orgs.
The genuinely independent universe is closer to the ~2,300 domains holding 1–2 contacts.
See [[reference_eb_suppression_traps]] — print the group-size histogram before loading.

**Contact quality is high:** 100% have a first name, 100% have a title, only 20 addresses
(0.2%) are role-style. This is a person-level list, not an `info@` list.

## ⚠️ NO GEOGRAPHY ON ANY LEAD

The only custom variables carried are `company website` and `person linkedin url`. **No
city, state, or postal address anywhere in the lead data.** Brite Nites is territory-gated,
so none of this list can be qualified for a Nites offer without geo-enrichment first. The
sample makes the risk concrete — Namotu Island Resort (`namotuisland.com`) is in **Fiji**.

Practical consequence: a net-new build that is geo-scoped from the start is only
reconcilable against this list on **domain**, never on location.

## Chain vs independent (local vs corporate decision)

Cut on **where the buying decision happens**, which maps to the handbook's ICP 1
(Independent/Boutique) vs ICP 2 (Chain-Managed). A 3-property local group behaves like an
independent — owner decides, no procurement. A chain-FLAGGED single property under
independent ownership (`wyndhamdeerfield.com`) does too.

Clean pool (#56/#60), 9,253 contacts / 2,897 domains:

| Category | Domains | Contacts |
|---|--:|--:|
| Single property | 2,290 | 2,719 |
| Small group (3–7) | 392 | 1,598 |
| Regional group / mgmt co (8–24) | 114 | 1,419 |
| Chain corporate directory (25+) | 54 | 2,012 |
| Non-hotel / association | 47 | 1,505 |

Of 7,748 real hotel contacts: **4,317 (55.7%) local-decision · 3,431 (44.3%) corporate.**
Full pool incl. #14: 24,169 local (49.2%) vs 24,915 corporate (50.8%).

**Method note.** Contacts-per-domain is the primary signal and held up — every domain with
25+ contacts proved to be a genuine chain or management co (Troon, HHM, Sonesta, Aimbridge,
Choice, Westgate, Sage, HEI, Remington, Drury, Crescent, Best Western, Loews, Kimpton).
A company-NAME regex was tried and **rejected**: it tagged `niagara-hospitality.com`,
`kamhospitality.com` and `bgrhospitality.com` (1 contact each) as management companies —
small owner-operators routinely name themselves "X Hospitality". The 8/25 thresholds are
judgment calls; a well-covered independent with 9 contacts lands in the wrong bucket.

**The 4,317 local-decision pool** is 85% director-level or above (2,369 director, 1,316
owner/C-suite, 432 manager, 43 GM). Top titles: director of sales 326, director of
operations 275, director of sales & marketing 181, CEO 119. 2,682 domains, of which 1,861
hold exactly one contact. Property types: 1,410 generic hotel, 726 resort/spa, 287
inn/B&B/lodge, 1,796 unclassified. Exposure: 2,590 already received 4 emails.

## Engagement history

| | Count |
|---|--:|
| #14 repliers | 3,143 |
| — also on #56/#60 | 415 |
| — unique to #14 | 2,728 |
| — flagged interested | **37** |
| #56/#60 repliers | 344 |
| **Total unique repliers** | **3,421** |

**Top replier domains:** marriott.com 180 · hilton.com 108 · dt.com 41 ·
atriumhospitality.com 34 · ihg.com 34 · hyatt.com 34 · ritzcarlton.com 31 · fourseasons.com 30.

**Top replier titles (#14):** sales manager 81 · operations manager 63 · director of sales 62 ·
account manager 55 · director of operations 55 · event manager 46 · senior sales manager 32 ·
marketing manager 30 · director of sales and marketing 26 · founder 24.

Titles confirm the targeting was right — sales, ops, and events leadership is who books
holiday decor at a property.

⚠️ **37 interested out of 3,143 replies is 1.2%.** The rest are routing, opt-outs, and
auto-replies. **Do not treat the 3,421 as warm.** Pull reply bodies and separate real
opt-outs (which must be suppressed) from routing replies before anything sends —
see [[reference_eb_reply_content_audit]] (MCP wrappers strip reply bodies; use raw
`call_api GET /api/replies` and join on `lead.email`).

## Coverage — complete as of 2026-08-05

All three campaigns pulled in full: 67,509 + 7,521 + 7,513 = 82,543 rows
(69,380 unique contacts). #14 came in at 67,509 against a `total_leads_contacted` of
67,513 — 4 leads presumably deleted between when that counter was set and the pull.

**How #14 was reached:** `?pagination_type=cursor` (~26 min at ~2.1 pg/s). `meta.total`
is `None` under cursor pagination, so the expected count comes from the campaign record's
`total_leads_contacted`.

**Do NOT** try to slice a >15,000-lead campaign with the `created_at` filter instead —
it is day-granular (a time component is silently accepted and ignored), and #14
bulk-loaded 33,297 leads on 2025-10-28 alone, so no filter combination gets that day
under the cap. Cursor is the only route.

## Gotchas found (cost real time — read before re-running)

1. **Offset paging caps at ~15,000 rows; `?pagination_type=cursor` is the bypass.** Page
   ~1,001+ returns HTTP 422. This was already documented in
   `reference_eb_pagination_filter_traps` and got missed on the first pass, which cost an
   hour building a filter-slicing workaround that could never have worked. **Check that
   memory before designing any large EB pull.**
2. **The campaign list's `leads` column undercounts by 7x.** #14 shows `9,351` there;
   `total_leads_contacted` on the campaign record says **67,513**, and `/leads` returns
   67,509. Cross-check: 130,036 sends ÷ 67,513 = 1.93 emails/lead, exactly right for a
   2-step sequence; ÷ 9,351 would be 13.9, which is impossible. **Trust
   `total_leads_contacted`, not `total_leads`.**
3. **`bulk_export`'s `max_items` is a ~15%-yield knob**, not a limit —
   `(max_items/100) × 15`, from the same hardcoded `per_page=15`. `max_items: 20000`
   returned exactly 3,000 rows of a 7,513-lead campaign with `success: true` and no
   warning. **Set it to ~7× the rows you want and assert `row_count == bulk_count(...)`.**
   It also writes its CSV to the MCP server's own filesystem
   (`/home/mcp/EmailBison_Exports/`), unreachable locally.
4. **Threaded paging stalls the endpoint.** 6 concurrent workers on urllib (new socket per
   request) piled up 86 hung sockets at zero CPU — the server throttles by holding
   connections open rather than returning 429. **Serial on one keep-alive connection runs
   ~2–3 pg/s**; the threaded version did ~0 after 45 min. `pull.py` here does it correctly.
5. **Status filters are global, not campaign-scoped.** See per-campaign section above.
6. **A campaign's name does not describe its list.** #14 is titled "Hotels" and is 17%+
   airlines, rental cars, CPG, cruise lines, and casinos. **Print a domain histogram before
   trusting any inherited list.**

## Files

- `pull.py` — serial keep-alive pager (offset for <15k campaigns, cursor for #14).
  Writes the four JSON dumps. Skips anything already on disk; delete to refresh. ~45 min cold.
- `audit.py` — reads those, emits every number in this doc + three CSVs.
- `audit_output.txt` — last full run output.
- `hotel_remailable.csv` — 62,583 contacts, `on_newer_list` column separates the clean
  9,253 from the 53,330 contaminated #14-only pool.
- `hotel_repliers.csv` — 3,425 repliers with an `interested` flag (only 38 are true).
- `hotel_never_mailed_c56.csv` — 6,604 leads with zero sends **on #56 only**. MISNAMED —
  all 6,604 were mailed via #14/#60. Not a fresh list. Kept for the #56 membership record.
- `hotel_independent.csv` — 4,317 local-decision contacts (single property + 3–7 group).
- `hotel_independent_nevermailed.csv` — 2,827 of those with zero #56 sends. Same caveat.
- `hotel_exclusion_domains.txt` — all 15,046 domains across the 69,380 contacts, for
  deduping a net-new build against what is already held.
- `classify_chain.py` / `profile_independent.py` — chain-vs-independent split + profiling.

## When picking this back up

1. Re-run `pull.py` + `audit.py` — EB state drifts.
2. **Accept that this is re-engagement.** Nothing here is unmailed. The offer has to be
   genuinely new — re-running a similar pitch at a twice-mailed audience is the weakest
   available play. Least-exposed segment: the 4,796 single-email contacts.
3. **Do not mail the 53,330 #14-only pool without re-qualifying against the hotel ICP** —
   17%+ is provably not hotels, and that's a floor.
4. Audit reply bodies for opt-outs before any send — 3,387 of the 3,425 repliers are
   routing/opt-outs/auto-replies, and opt-outs must be suppressed, not re-mailed.
5. Dedup to 1–2 contacts per *property*. 11,411 domains hold 1–2 contacts (the real
   independent universe); the corporate directories need separate treatment.
6. Decide what 135/136/137 (Labs custom illuminated artwork) are for — a different offer
   than a Nites holiday-decor pitch, and currently empty.
7. Re-verify everything — the newest of these lists last sent 2026-05-14.

## Copy direction (from the 2026-07-28 session, not yet built)

Hotels buy **atmosphere / guest experience / a property that photographs well** — unlike
botanical gardens, where the buy is a ticketed revenue event. "Holiday decor" is the correct
noun *for hotels*. Nearly every hotel already puts something up, so the offer is
**replace or upgrade**, not create — the conditional should ask whether last year's worked.

> hey {{FIRST_NAME}} — right now we're dialing in holiday decor plans for the hotels on our
> calendar, so figured I'd reach out while there's still time.
>
> If yours isn't set for this year, or last year's didn't quite land, happy to see how we can help.

Timing note: a hotel can decide in August and install in November, so a same-season close is
realistic here — unlike gardens, whose year-1 cycle is 6–12 months.
