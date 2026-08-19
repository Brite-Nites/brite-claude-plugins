# Casino suppression — actions taken

> Contacts are referenced by role + property. No names or email addresses: this
> repo is public and person-level detail is out of scope per the PR #511 policy.
> Full rows live in the campaign CSVs (untracked) and in EB / Salesforce.

## 2026-08-13 — hard opt-outs loaded to the EB email blocklist

Two contacts who explicitly asked not to be contacted. Until now the only thing
stopping them being re-mailed was someone remembering to exclude them from the next
upload — the earlier request had been unenforced since 2025-11-18.

Added to **both** workspaces: an unsubscribe request applies to the company, not to
whichever sending instance happened to be used. Blocklists are instance-relative, so
a ws55-only entry would not protect a ws13 send.

| Role / property | Said | ws55 id | ws13 id |
|---|---|---:|---:|
| Ops Manager, The Greenbrier | "Please unsubscribe." (2025-11-18) | 569 | 178 |
| VP Customer Development, MGM Grand LV | "I am not interested." (2026-04-10) | 570 | 179 |

Verified by read-back on both instances. Totals after: ws55 550, ws13 173.

### API note

`POST /api/blacklisted-emails/bulk` returns **HTTP 500 "Server error."** on every body
shape tried (`{"emails":[...]}`, `{"blacklisted_emails":[...]}`, `{"emails":[{"email":...}]}`).
The spec documents the route but leaves `requestBody: null`.

Use the singular route instead — it works and returns 201:

```
POST /api/blacklisted-emails      {"email": "someone@example.com"}
```

## NOT blocklisted — deliberately

Six more contacts are `NEVER_MAIL` for this campaign but were **not** added to the
blocklist, because blocklisting is permanent and these are not permanent objections.

**"We handle lighting in house" (3)** — a no to this offer, not a no forever. One is
the GM & VP Property Management at Viejas, exactly our buyer; an in-house team today
can change, and a design-partnership offer may still land.

- GM & VP Property Management, Viejas
- Exec Director of Sales, Beau Rivage
- Sr Catering & Events Sales Mgr, Coushatta

**Wrong person (3)** — routing failures, not rejections. Blocklisting loses the whole
account when the fix is to find the right contact at that property. All three
properties are in the universe and should go to the enrichment list.

- Bellagio — casino host, not facilities
- French Lick — Director of **Golf** Operations
- Three Rivers — Director of Marketing, confused by vague copy

## Suppression legs completed

| Leg | Result |
|---|---|
| BounceBan verification | 2,159 → 2,003 deliverable |
| Prod Salesforce (BC-13599 method) | 9 suppressed — Virgin Hotels LV (5, open opp), Cache Creek / Yocha Dehe (4, $140k open) |
| EB domain blocklist, both workspaces | 0 hits |
| EB email blocklist, both workspaces | 0 hits |
| Same person in an active campaign | 0 |
| Same company in an active campaign | 0 across 15,668 leads / 9,163 domains |
| Vendors removed | 5 |
| Duplicate humans collapsed | 7 |
| Auto-reply scan (full text) | 23 pulled as unreachable |

**Final: `SEND-LIST-FINAL.csv` — 1,959 contacts across 376 domains.**

## Auto-reply scan — 23 pulled

Departed/retired contacts (6 + 2) were already excluded as `DEPARTED` with successors
captured. Re-scanned on **full-length** bodies because 61% of the stored copies were
truncated at 500 chars; full text surfaced nothing extra, but reading the unclassified
bucket by hand did.

**Unreachable individuals (2)**
- Meskwaki — primary contact unavailable indefinitely; two alternates at the same
  property captured in the CSV
- MLCV — permanent redirect to a named successor. No "out of office", no "no longer
  with", no return date, so every keyword pattern missed it. Found by eye.

**Challenge-response filters (21)** — these reply *"Your email to X is almost there!
We need to verify you're a real person."* Mail never lands unless a human completes the
challenge, which nobody on our side does. BounceBan scored all 21 "deliverable" — true
at the SMTP layer, wrong in practice.

| Property | Blocked | 
|---|---:|
| Soboba Casino Resort | 7 |
| Black Oak Casino Resort | 6 |
| FireKeepers Casino Hotel | 4 |
| Cahuilla Casino Hotel | 2 |
| Augustine Casino | 1 |
| Resorts Casino Hotel | 1 |

Six properties where cold email is a dead channel — route to phone or LinkedIn.
Includes their `info@` shared inboxes, so there is no back door.

All 23 in `PULLED-autoreply-unreachable.csv` with a `pull_reason`.

### Still open

Replies in the 26 paused/draft campaigns (~125k leads) were not scanned. Residual risk
is low: none of the 1,994 leads appear in any non-casino campaign, so they cannot have
replied elsewhere — the only exposure is a colleague at the same company in a paused
campaign.
