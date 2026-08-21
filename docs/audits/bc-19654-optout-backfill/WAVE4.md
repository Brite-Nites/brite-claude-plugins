# BC-19654 wave 4 — address-level back-fill

Executed 2026-08-21. Closes the address-scoped remainder of the queue.

## Queue reconciliation

The earlier "275" excluded senders already on the email blocklist. Recomputed against the **live**
blocklists (the warehouse lags same-day writes):

| | |
| --- | --- |
| Actionable senders, all time | 464 |
| Already suppressed before this wave | 242 |
| Remaining | **222** |
| → clean address blocks | 199 |
| → needed re-reading first | 23 |

## The 23 re-reads, adjudicated

**8 genuine** — all a variant of *"this mailbox is no longer monitored, remove this address"*:

| Address | Note |
| --- | --- |
| `<person>@taubman.com` · `jwells@` · `eryan@` · `avalero@` | Four separate Taubman mailboxes, same boilerplate. Dead-mailbox cleanup, **not** an org opt-out — address-level is correct for each. |
| `<person>@plymouthucc.org` | "no longer in use by the former mailbox owner. Please remove this address from any lists" |
| `<person>@bianchiwine.com` | "Please remove from mailing list. Kit no longer with us" |
| `<person>@map401k.com` | names the exact address |
| `<person>@emhealth.org` | removal **and a referral** — "Please contact a named colleague at <person>@emhealth.org" |

**15 dropped as noise** — Veterans Day closures, vacation autoresponders, two postmaster NDRs, and
the three Edward Jones out-of-offices that matched only on their own corporate unsubscribe footer.

## Near-miss worth recording

`<person>@penrosebar.com` was sitting in the clean-199 list. That is the domain deliberately spared in
wave 3 because they re-engaged with an unanswered sales question. Blocking it here would have
buried the live lead **through the back door**, undoing a decision made two waves earlier.

**Lesson: a spare decision must be carried as an explicit exclusion list, not held in memory.**
Post-run verification confirms `penrosebar.com` returns 404 for both domain and email lookups on
both instances.

## Result

| | |
| --- | --- |
| Address blocks written | **206** × 2 instances = 412 calls |
| Status codes | 411 × 201, 1 × 422 (already present on personal) |
| Verified missing from our 206 | **0** on b2b, **0** on personal |
| b2b email blocklist | 558 → **764** |
| personal email blocklist | 190 → **396** |
| Leads unsubscribed | **133 / 133**, all HTTP 200 |

Only 133 lead rows exist for 206 addresses — the other 73 replied from an **adjacent address** with
no lead row of its own (the Karol pattern). They are covered by the blocklist regardless, and would
have been missed entirely by any lead-join-based approach.

## BC-19654 running total

| | |
| --- | --- |
| Domains blocked | **49** |
| Addresses blocked | **206** + ~330 covered by domain blocks |
| Leads unsubscribed | **~400** |
| Deliberately spared | `penrosebar.com` |
| Dropped as not-an-opt-out | 24 (9 wave 1 + 15 wave 4) |
