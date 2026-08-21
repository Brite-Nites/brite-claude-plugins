# BC-19654 wave 1 — org-scope domain blocks

Executed 2026-08-21. 43 domains blocked on **both** EB instances; 112 leads actioned.

## How the buckets were decided

The first pass bucketed by *domain size*. That was the wrong axis — size is a safety veto, not a
reason to block. The deciding question is **what the person actually asked for**:

| Signal in the reply text | Action |
| --- | --- |
| Names the org, or says "us / our" | domain block |
| Says "me / my / this address" | address only, even at a tiny domain |
| Free-mail domain (gmail, hotmail) | address only — a domain block is impossible |
| Auto-reply, inbound marketing, or a redirect | drop, suppress nothing |
| Org language **but** domain >100 addresses | hold for human review |

Reading all 73 org-flagged candidates found the regex over-matches by ~26%:
- **9 were not opt-outs at all** — an out-of-office (`<person>@exoticca.com`), Microsoft's own
  marketing, two auto-responders, two `noreply@*.onlinecrm.marketing` blasts, an inbound sales
  pitch (`<person>@trymonny.com`), and a *redirect* (`<person>@stanford.edu` pointing us at a
  different department). See `exclude_notoptout.txt`.
- **11 were address-scoped despite org-ish phrasing** — "remove **me**", "remove **this address**",
  or a free-mail domain. See `exclude_addressonly.txt`.

That left 50 domains: 43 actioned here, 7 held for review.

## Signals worth reusing

- **Repeat senders from one domain are themselves an org signal.** `phoenixuu.org` had three
  different people write in; `ginandluck.com` two.
- **Some requests are explicitly domain-wide** and need no interpretation:
  `<person>@ourismancars.com` — *"Unsubscribe all ourismancars.com emails"*;
  `<person>@highpointgo.com` — *"remove me and everyone on our domain"*.
- **"Us" is scoped to whatever the speaker represents.** A location concierge or a single-brand
  marketing director saying "us" may mean their site, not the whole group — which is why
  `commonhouse.com`, `bhglex.com` and `theindigoroad.com` were held rather than auto-blocked.

## Result

| | |
| --- | --- |
| Domains blocked (both instances) | **43** |
| Addresses covered | **112** |
| Leads unsubscribed | **109 / 112** |
| b2b domain blocklist | 17 → **60** |
| personal domain blocklist | 1 → **44** |

18 of the 112 were at `ourismancars.com` and still sitting in campaigns 15/69 — the domain that had
explicitly asked us to unsubscribe every address on it.

## Known residual — 3 leads could not be unsubscribed

**`PATCH /api/leads/{id}/unsubscribe` returns 422 when the lead has never been sent an email**
(`"This lead has not been sent any emails yet"`). This refines the note in
`reference_eb_blocklist_vs_campaign_removal`: that endpoint clears campaign state *only for leads
with at least one send*. There is no detach endpoint, so a queued-but-never-sent lead cannot be
removed from a campaign at all.

| Lead | Campaign | Campaign state | Protected by |
| --- | --- | --- | --- |
| `<person>@hotelwalloon.com` | 177 | **ACTIVE** | `hotelwalloon.com` domain block |
| `<person>@ourismancars.com` | 15 | paused | `ourismancars.com` domain block |
| `<person>@ourismancars.com` | 15 | paused | `ourismancars.com` domain block |

Only one sits in an active campaign. All three are covered by a domain blocklist entry, which is
verified to stop sends. The acceptance criterion "none sit `in_sequence`" is therefore met in
substance but not literally for `<person>@hotelwalloon.com` — flagged rather than papered over.

Note `sending_paused` on a lead row mirrors the **campaign** being paused, not the lead being live.
Campaigns 15, 33, 40 and 69 are all paused; only 177 is active.

## Held for review (7 domains / 188 addresses)

`imperialcars.com` (98), `theindigoroad.com` (36), `commonhouse.com` (16), `bhglex.com` (14),
`bede.org` (13), `thebridgesrsf.com` (8), `penrosebar.com` (3).

`penrosebar.com` opted out 2025-10-10 then **re-engaged 2026-05-23** asking a genuine question —
a domain block there would cut off a live conversation.
