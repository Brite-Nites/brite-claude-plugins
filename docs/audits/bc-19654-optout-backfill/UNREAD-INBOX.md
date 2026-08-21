# The unread inbox — a revenue finding, not a compliance one

Counted 2026-08-21, prompted by two accidental discoveries: the Karol Hotel opt-out sat
`is_read=false` for **nine months**, and `penrosebar.com`'s inbound *sales question* for **three**.
Both surfaced by chance. So: what else is in there?

## Counting honestly

| Filter | Count |
| --- | --- |
| Human (non-automated) replies, unread, external sender | 9,937 |
| …**from a lead we actually mailed** | **3,404** |
| …not an opt-out or out-of-office | 3,016 |
| …not a decline | 2,513 |
| …with a real body (20–1,200 chars) | 2,390 |
| …received in 2026 | **325** |

**66% of the raw 9,937 is inbound spam landing in our own mailboxes**, not prospect replies —
`inboxspherex.shop`, `getinstantlygrowth.info`, `plumberseosite.com`, `meetforwardfirm.com` and
similar. The May-2026 spike (352 in one month vs single digits either side) is almost entirely this.
**Joining to the leads table is what separates signal from noise here** — a genuine reply comes from
someone we mailed; spam does not.

## What the survivors are (15-row hand sample of the 325)

| Class | ~share | Example |
| --- | --- | --- |
| Soft decline the regex missed | ~8/15 | *"We're going to pass"* · *"we do it ourselves to save money"* · *"not a priority for us this year"* |
| **Referral to the right person** | ~4/15 | *"You should speak with John Krusinski <<person>@decoratect.com>, he is the head of our Christmas Lights"* · *"Try reaching out to public works at <person>@elmonteca.gov"* |
| **Genuine interest** | ~3/15 | *"Yes, we do a lot of Christmas decorations"* · *"what holiday?"* |

Extrapolating: of the 325, roughly **90 referrals and 60 interested** are worth acting on, against
~175 declines. Sample is 15 rows — treat as an order of magnitude, not a figure.

The sharpest single case:

> `<person>@richlandhills.com`, **2026-02-26** — *"[rep], thanks for reaching out regarding holiday
> lights. If you have any information you would like to share, please feel free to email me
> directly."*

An explicit invitation to follow up, unread for six months.

## Why this matters for BC-19654 item 6

The referrals may be worth more than the expressions of interest: a named better contact
("talk to John, he runs Christmas lights") is a warmer entry than any cold list produces.

It also reframes the n8n work. The reply pipeline should not only classify **opt-out** intent — it
should classify **referral** and **interested** too, because all three are currently failing the
same way and for the same reason: *nothing reads the inbox*. A classifier that only catches
opt-outs fixes the compliance half and leaves the revenue half on the floor.

## Caveat on the decline filter

The `declines` regex under-catches badly — over half the sampled 325 were declines it missed
("we're going to pass", "no recollection", "not a priority"). Any triage built on this should
expect the interested/referral buckets to be smaller than the raw count suggests, and should read
rather than trust the pattern.
