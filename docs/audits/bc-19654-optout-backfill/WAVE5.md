# BC-19654 wave 5 — widened sweep

Run 2026-08-21 after the main queue closed, to test whether the inherited phrase list had missed
anything. It had — including a whole detection channel.

## Two gaps found

### 1. Phrase gaps — "delete me" and "remove from list"

The issue's original list covered `remove me/us` and `take me off` but **not `delete me`**. Three
people used it, two of them the most senior person at the company:

| Sender | Text |
| --- | --- |
| `<person>@thirdhome.com` | *"Please delete me from communications"* — **Founder / CEO / Chairman** |
| `<person>@theseashellresort.com` | *"delete me please"* — **President** |
| `<person>@tbginnovative.com` | subject **"Delete me"** |
| `<person>@honeygrow.com` | *"no thank you remove from list"* — `remove from` was not covered either |

### 2. Subject-line-only opt-outs — a channel nobody scanned

**Every prior pass, including the issue's own method, scanned `TEXT_BODY` only.** Nine people put
the request in the **subject** and left a body containing nothing but a signature:

| Sender | Subject | Body |
| --- | --- | --- |
| `<person>@virginiagreen.com` | `unsubscribe` | signature |
| `<person>@duwestrealty.com` | `UNSUBSCRIBE` | *"STOP"* |
| `<person>@tbginnovative.com` | `Delete me` | signature |
| `<person>@mountmadonna.org` | `UNSUBSCRIBE` | quoted original |
| `<person>@creeksiderestaurant.com` | `UNSUBSCRIBE` | signature |
| `<person>@lodgeworks.com` | `unsubscribe` | signature (VP, Digital Strategy) |
| `<person>@mckibbon.com` | `unsubscribe` | *"Director"* |
| `<person>@crowneknox.com` | `Unsubscribe` | signature |
| `<person>@cfacorp.com` | `Unsubscribe` | signature |

`<person>@cfacorp.com` is Chick-fil-A — one of the giant domains (1,283 addresses). Address-only,
per the size veto.

**Any future detection job must scan `SUBJECT` as well as `TEXT_BODY`, and fall back to
`HTML_BODY` when `TEXT_BODY` is empty.**

## Result

12 candidates, 2 already covered, **10 blocked** (20 writes, all 201). 8 leads unsubscribed, all 200.
The other 2 have no lead row — replied from an adjacent address.

## What the sweep did NOT find: more opt-outs

The widened regex matched **110** senders the old one missed, but only ~4 were opt-outs. The other
~90 are a different thing entirely:

### The "no longer monitored" class — ~90 dead mailboxes

Auto-replies saying the mailbox is dead, **most naming a successor**:

> `<person>@lorainccc.edu` — *"This inbox is no longer monitored. Please contact a named Director of Facilities, Director of Facility…"*
> `<person>@tibetanmuseum.org` — *"Please fwd to <person>@tibetanmuseum.org"*
> `<person>@monarchduneshoa.com` — *"Please contact a named successor: Audra.Napoli@…"*

**These are not opt-outs and should not be treated as a compliance matter.** Mailing them is waste,
not a violation. But they are worth acting on twice over: the dead address is list rot, and the
named successor is a **referral** — the same pattern found in `UNREAD-INBOX.md`.

Deliberately **not** actioned here: it is list hygiene plus lead-gen, not the scope of BC-19654, and
folding it in would misclassify ~90 people as having opted out when they did no such thing.

Also in the 110 and correctly excluded: the 8-domain `joshua whitfield` inbound-spam cluster,
several out-of-office replies, two genuinely positive replies (`<person>@jcnj.org`,
`<person>@freskodsm.com`), and `<person>@rudysgolf.com` — a business that **permanently closed**, which
is dead-list hygiene rather than an opt-out.
