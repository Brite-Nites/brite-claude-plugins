# Casino vertical audit — 2026-08-10

Audit of every casino campaign Brite has run and every casino contact in Email Bison, run to answer two questions: **who can go back into a campaign**, and **where are the gaps**.

Source of truth: live Email Bison API (ws55 `send.outbase.so` + ws13 `personal.outbase.so`), pulled 2026-08-10. Reply bodies were read individually, not classified by keyword alone.

## 1. What we ran

Six campaigns in ws55 (b2b). The personal workspace has one archived casino campaign with 1 lead and 0 sends — effectively nothing.

| Camp | Lane | Window | Contacted | Sent | EB "replies" | **Human replies** | **Warm** | Bounces |
|-----:|------|--------|----------:|-----:|-------------:|------------------:|---------:|--------:|
| 47 | All ESPs | Nov 2025 | 787 | 1,537 | 25 | 3 (0.4%) | 0 | 23 |
| 48 | All ESPs (role) | Nov 2025 | 34 | 66 | 2 | 0 | 0 | 0 |
| 54 | All ESPs | Mar–Apr 2026 | 1,545 | 2,883 | 75 | 17 (1.1%) | 4 | 63 |
| 91 | Google | never sent | 0 | 0 | 0 | 0 | 0 | 0 |
| 94 | Microsoft | May 2026 | 721 | 1,439 | 5 | 1 (0.1%) | 0 | 3 |
| 95 | SMTP | May–Jun 2026 | 815 | 1,608 | 27 | 2 (0.2%) | 1 | 2 |
| **Total** | | | **3,902** | **7,533** | **134** | **23 (0.6%)** | **5** | **91** |

**The headline reply number is inflated ~6x.** Of 144 tracked replies, 115 are automated (out-of-office, acknowledgements, mailbox notices). Only 23 are a human typing a response, and only 5 of those express interest. Campaign 54 is the only run that produced anything: 17 of the 23 human replies and 4 of the 5 warm leads.

Campaign 54 also carried 63 of the 91 bounces. It was the widest run and the only one that got real traction.

## 2. Contact base

2,359 unique contacts across 3,934 campaign memberships (heavy re-mailing), spanning 455 companies and 426 email domains. Zero overlap with any non-casino campaign — this list has never been double-sent against another vertical.

### Eligibility segmentation

| Segment | Count | Meaning |
|---|---:|---|
| ELIGIBLE | 2,148 | No reply, no bounce — mechanically re-mailable |
| REPLIED_AUTO | 91 | Auto-reply only; no human signal, still eligible |
| POLICY_BLOCK | 37 | Good address, domain blocked our lane |
| HARD_BOUNCE | 33 | Bad address, needs re-enrichment |
| SOFT_BOUNCE | 19 | Retryable (quota, size, deferral) |
| DEPARTED | 8 | Gone; auto-reply named a successor |
| REFERRAL | 6 | Pointed us at the right person/department |
| WARM_FOLLOWUP | 5 | Real interest — human sales follow-up, not a campaign |
| SUPPRESS_INHOUSE | 3 | "We handle lighting in house" |
| NURTURE_TIMING | 3 | Right fit, wrong moment |
| WRONG_PERSON | 3 | Explicitly not their remit |
| SUPPRESS_OPTOUT | 2 | Explicit unsubscribe / not interested |
| NEVER_MAILED | 1 | Loaded to draft campaign 91, never sent |

### From 2,148 "eligible" to 666 worth mailing

The raw eligible number does not survive the ICP in `docs/research/bc-5930-casinos-research.md`:

| Filter | Remaining | Dropped |
|---|---:|---:|
| ELIGIBLE (no reply, no bounce) | 2,148 | — |
| Drop Las Vegas Strip flagships + lottery/non-casino orgs | 1,413 | −735 |
| Drop wrong-department titles | 1,024 | −389 |
| **Tier A — named buyer titles only** | **666** | |
| Tier B — in-scope property, unclear title | 358 | |

## 3. Findings

**The list contradicts our own ICP.** The research doc puts Las Vegas Strip flagships out of scope except as ceiling references. 740 contacts (31%) are at exactly those properties — Caesars alone has 206 contacts, MGM 126, Wynn 85. This is the single largest quality problem in the list.

**We targeted the wrong department at scale.** 655 contacts (28%) hold marketing, player-development, casino-host, or slot-operations titles. The replies confirm the miss in the prospects' own words: *"I am a casino host and work in casino marketing. You have the wrong person"* (Bellagio); *"Not sure what you mean?"* (Three Rivers, Director of Marketing); *"I'm not sure if this is the right department"* (Yakama Nation Legends).

**We under-targeted the buyer the research names.** The research doc identifies Director of F&B as the primary experiential P&L owner across all four casino sub-types. We have **40** F&B contacts — 1.7% of the list. Facilities/engineering is also thin at 149.

**~50 contacts aren't casinos at all** — state lottery corporations (Kentucky, Oregon, Virginia, Georgia, Minnesota, Michigan, Maryland, DC, Arizona), Tao Group Hospitality (29), sbe Lifestyle.

**Opt-outs live in a spreadsheet, not in Email Bison.** All six campaigns report `unsubscribed = 0`, and the EB blocklist holds 16 domains, none of them casino. Roger Sullivan at The Greenbrier wrote *"Please unsubscribe"* on 2025-11-18 and is still an active, mailable lead record. He was not re-mailed — but only because someone remembered to exclude him from the next upload. That is a manual control protecting a compliance obligation.

**The existing do-not-contact list buries live deals.** `casino_DO_NOT_CONTACT_repliers_2026-05-13.csv` marks 15 people "do not re-contact." Only 6 are genuine suppressions. Three are warm leads and five are useful referrals. Two of the three warm leads had **calls booked**:

- **John Moss, VP Engineering & Facilities, Virgin Hotels Las Vegas** — asked for a proposal to light the entrance palms, confirmed a 9am Wednesday call (Apr 8).
- **Elise Grabowski, Fortune Bay Resort Casino** — booked Wed 4/15 11am with Rainer for their 40th + NYE.

Both were filed as do-not-contact a month later. (This is the same failure mode recorded for wineries: the removal bar is *wrong contact*, not *replied*.)

**One open loop, unanswered for 10 weeks.** Justin Sullivan, Corporate Director of Marketing at Gila River Resorts & Casinos, wrote on 2026-06-01: *"I've got a couple of projects that might be something we could work on together... Maybe we could set up a call late next week?"* Santi replied the same day offering Wed/Thu/Fri. **Nothing after that in Email Bison.** Either the call happened off-platform or it was dropped — worth checking before anything else in this audit.

**Eight contacts have named replacements we never used.** Auto-replies handed us successors at Downtown Grand, Santa Ana Star, M Resort/Penn, Caesars, Thunder Valley, Arizona Lottery, and Tao Group. Free, pre-qualified contact data sitting unread.

**37 policy blocks are a lane problem, not a list problem.** Boyd Gaming (7), Hard Rock (5), Graton, Pala, Rio, Wild Rose and others returned `554 5.7.5` permanent policy rejections — the addresses are fine, the sending lane was refused. These properties are in-scope and worth re-running through the SMTP lane.

**On ESP lanes:** raw EB replies suggested SMTP (27) crushed Microsoft (5). At the human level it was 2 vs 1 — too small to conclude anything. The gap was almost entirely auto-reply volume. Don't read a 5x lane effect into this data.

## 4. Coverage gaps

Against the 560-property TAM in `~/Desktop/Casinos/us-casinos-enriched.csv` (306 tribal / 254 commercial, 38 states):

- **230 properties (41%) have at least one contact**
- **330 properties (59%) have zero contacts** — 188 tribal, 142 commercial
- **95 of those sit inside the 16 Brite service states** — the highest-value gap

Top in-territory gaps: CA 28, CO 16, AZ 13, IL 8, NY 8, PA 7, FL 6, NJ 3.

A further 266 email domains (1,173 contacts) belong to properties the TAM list never captured, so the TAM itself is incomplete in both directions. `casino-gap-list.csv` already holds 184 properties with no email, **55 of which have named contacts and only need an address** — the cheapest enrichment available.

## 4b. The real universe (added 2026-08-11)

The 560-row Desktop list was never the TAM. A property universe rebuilt from two authoritative-ish public sources:

- **Wikipedia `List_of_casinos_in_the_United_States`** — one national table (Casino / City / County / State / Type / Comments), 960 rows, 110 closed properties excluded. Strong on commercial, racino, riverboat.
- **500nations national tribal list** — 508 tribal operations across 30 states under 246 tribes. Wikipedia only carries 276 tribal, so it undercounts by roughly half exactly where our Seminole / Casino Pauma references land.

Merged, then de-duplicated twice (exact key, then within-state name-containment clustering — 196 clusters collapsed, e.g. 500nations' "Wind Creek Casino" vs Wikipedia's "Wind Creek Casino & Hotel Atmore").

**Final universe: 896 open properties across 41 states.** Reference point: AGA counts 492 commercial and NIGC counts 532 tribal = 1,024, so this is a ~87% reconstruction — treat 896 as a floor.

| | Universe | Have mailable contact | Gap | Coverage |
|---|---:|---:|---:|---:|
| Tribal | 452 | 167 | 285 | 37% |
| Commercial | 358 | 132 | 226 | 37% |
| Racino | 63 | 14 | 49 | 22% |
| Riverboat | 23 | 12 | 11 | 52% |
| **Total** | **896** | **325** | **571** | **36%** |

Biggest gaps by state — NV 107, OK 74 (73 tribal — the densest tribal state in the country), MN 34, CA 30 (all tribal), SD 29, FL 25 (22 racino), NM 24, CO 23, MS 20, WI 20. Montana is 12 properties and zero coverage.

### ICP change, 2026-08-11 — Las Vegas Strip is IN scope

`docs/research/bc-5930-casinos-research.md` § scope excludes Strip flagships "except as ceiling references." **Operator overrode this on 2026-08-11: Vegas is in.** The research doc and `casinos.yaml` should be updated to match.

Effect on the keeper list: `DROP` fell from 1,185 to 584, and **mailable rose from 1,111 to 1,712** (+601) across 366 properties. The recovered contacts sit at Caesars (143), MGM Resorts (96), Wynn (65), Fontainebleau (38), Resorts World (29), Mandalay Bay (26), Tao Group (25), Venetian (21).

Two things that do **not** change with this override:
- **Wrong-department titles stay dropped** — 568 contacts, mostly marketing / player development / slot operations. That filter is evidence-based: prospects said so themselves (*"I am a casino host and work in casino marketing. You have the wrong person"*).
- **State lotteries and race-tech stay dropped** — 16 contacts. Not casinos.

Worth carrying into the offer: the *"we handle it in house"* objection came disproportionately from large properties (Caesars, MGM, Beau Rivage, Viejas, Coushatta all have in-house production or special-events teams). Vegas being in scope doesn't make that objection go away — it makes it the main thing the Vegas copy has to answer.

## 5. Files

| File | Rows | Use |
|---|---:|---|
| **`RESEND-inventory.csv`** | **2,359** | **Master keeper list** (Vegas in scope). One `resend_verdict` per contact: `RESEND_A` 1,078 · `RESEND_B` 578 · `RESEND_RELANE` 37 · `RESEND_RETRY` 19 · `REPLACE` 8 · `REENRICH` 33 · `SALES_ONLY` 14 · `NEVER_MAIL` 8 · `DROP` 584. **1,712 mailable now, 1,753 after cheap recovery, across 366 properties.** Carries a `vegas_strip` column so the Strip can be split into its own campaign. |
| **`UNIVERSE-final.csv`** | **896** | Rebuilt US casino property universe with `have_contact` flag |
| **`GAP-properties-to-build.csv`** | **571** | Properties with no mailable contact — the build list. 257 carry a named tribe, 586 carry a city |
| `_source-tribal-500nations.csv` | 508 | Parsed tribal source, kept for re-runs |
| `scripts/` | | Re-runnable pipeline (`tribal.py` → `merge_universe.py` → `dedupe_final.py`) |
| `ACTION-1-remail-tierA-buyers.csv` | 666 | Superseded by `RESEND-inventory.csv`; kept for traceability |
| `ACTION-2-remail-tierB-unclear-title.csv` | 358 | Secondary — in-scope property, title needs review |
| `ACTION-3-suppress-in-EB.csv` | 8 | Load to EB unsubscribe/blocklist |
| `ACTION-4-human-followup-warm.csv` | 14 | Sales follow-up — do **not** put in a campaign |
| `ACTION-5-replace-contact-departed.csv` | 8 | Swap in the named successor |
| `ACTION-6-relane-to-SMTP-policy-blocked.csv` | 37 | Re-send via SMTP lane |
| `ACTION-7-reenrich-hard-bounce.csv` | 33 | Re-enrich the address |
| `ACTION-8-drop-out-of-ICP.csv` | 1,124 | Out-of-scope — archive, don't mail |
| `GAP-properties-zero-contacts.csv` | 330 | Properties with no contact; `InBriteServiceState` column |
| `casino-segmentation.csv` | 2,359 | Full per-contact segmentation |
| `_raw-replies.json` / `_raw-leads-by-email.tsv` | | Underlying pull |

Tier A last-touch spread: 195 from Nov 2025, 25 from Apr 2026, 211 from May 2026, 221 from Jun 2026, 14 never mailed. The 432 touched in May/June are only 8–10 weeks cold — tight for a re-mail if you launch in August.

## 6. Suggested order

1. Chase Gila River — 10 weeks stale on an explicit buying signal.
2. Re-open Virgin Hotels LV and Fortune Bay; both had calls booked and were mis-filed as do-not-contact.
3. Load the 8 suppressions into EB properly, so the control isn't a spreadsheet.
4. Swap in the 8 named successors and re-lane the 37 policy blocks — 45 contacts recovered at near-zero cost.
5. Fill the 55 named-contact-no-email properties, then the 95 in-territory zero-contact properties.
6. Rebuild the title mix toward F&B, facilities, and GM before re-mailing Tier A.
