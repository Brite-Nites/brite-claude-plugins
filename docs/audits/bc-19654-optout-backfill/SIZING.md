# BC-19654 — recomputed scope

Snowflake `ANALYTICS.STAGING.STG_EMAILBISON__*`, warehouse snapshot `2026-08-21 10:14 UTC`
(predates the Karol writes made the same day at 16:01, so these are pre-change figures).
Queries in `queries/` — see `queries/README.md` for setup. Every figure below is reproducible:

Paths below are from the **repository root**:

```bash
python3 -m pip install 'snowflake-connector-python[secure-local-storage]' pyyaml

Q=docs/audits/bc-19654-optout-backfill/queries
python3 "$Q/sfq.py" < "$Q/q_base.sql"
```

## The 407 was broadly right

I suspected the issue's "407 not blocklisted" was inflated by the
`/api/blacklisted-emails?search=` false-zero bug. **It was not.** Recomputed against a full
warehouse dump of both instances' blocklists, evaluated per workspace:

| Measure | Count |
| --- | --- |
| Distinct reply senders (our domains excluded) | 18,104 |
| Opt-out phrase match, issue's method | **598** — reproduces the issue exactly |
| Of those, not covered by email **or** domain blocklist | **399** (issue said 407; ~1 day of drift) |
| Same, after stripping quoted original | **372** |

The search bug is real and worth knowing (see README), but it did not distort the headline.

## The real work queue is ~275, not 407

Bucketed by phrase strength, with 28 rows hand-sampled across buckets:

| Bucket | Senders | Sampled precision | Verdict |
| --- | --- | --- | --- |
| **A.** strong phrase — "remove me/us", "please remove", "take me off", "stop emailing", "do not contact", "opt out" | 237 | 13/14 genuine (~93%) | action |
| **C1.** short reply (≤250 chars) containing "unsubscribe" | 38 | genuine in sample | action |
| **C2.** long body, "unsubscribe" only in footer | 94 | 6/14 genuine (~43%) | review, mostly inbound marketing |

**A + C1 = 275 to action.** C2 is dominated by newsletters and cold mail sent *to* us
(Apollo, `noreply@…marketing`, `*.click` spam) that merely contain the word.

Body length is the discriminator in bucket C: a reply that is essentially just the word
"unsubscribe" is a genuine request; a marketing email containing it in a footer is not.

Note 88 of the 275 are not leads we mailed in that workspace — they replied from an adjacent
address, exactly the Karol pattern. Do not drop them for not matching a lead row.

## Domain-level blocking does NOT generalize from the Karol case

Karol had 6 addresses, so a domain block was cheap and correct. Across all opt-out domains it
is not. Excluding free-mail, **319 domains** have sent an opt-out, holding **8,936** mailable
addresses between them. Median 3 per domain, but a heavy tail:

| Domain | Addresses at risk |
| --- | --- |
| hilton.com | 3,155 |
| cfacorp.com | 1,283 |
| caesars.com | 528 |
| daveandbusters.com | 276 |
| fpimgt.com | 244 |
| atriumhospitality.com | 224 |

One person at Hilton writing "remove me" would suppress 3,155 addresses. `caesars.com` sits in
the live casino campaign (ws55 185/186/187).

### Proposed rule

| Condition | Action |
| --- | --- |
| Free-mail domain (gmail, yahoo, …) | **Address only**, never domain |
| ≤5 addresses at the domain (207 of 319 domains) | **Domain block** — cheap, covers the Karol pattern |
| >5 addresses **and** request uses company-wide language ("remove us", "our team") | **Domain block**, but eyeball it first |
| >5 addresses, individual language ("remove me") | **Address only** |

By language: 195 of the 275 are individual-scoped, 80 use company-wide phrasing.

## Reproducing

The blocklist must be read from the warehouse (`STG_EMAILBISON__BLACKLISTED_EMAILS` /
`__DOMAINS`, filtering `IS_DELETED_IN_SOURCE`), never via the API's `search` parameter.
Coverage is instance-relative — join on `_EB_WORKSPACE`.
