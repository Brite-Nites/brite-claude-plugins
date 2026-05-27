# GTM Campaign Master Inventory

**Authored by**: BC-11851 (A1 Master Inventory)  **Linear project**: Brite GTM (`5e25e522-0700-4f0f-86a2-bdff965126f5`)  **EB workspaces**: b2b + personal  **Snapshot date**: 2026-05-27

One row per **logical campaign** — the conceptual unit one operator schedules, copies, and reviews. Logical key = `(fy, month, vertical_raw, offer_raw)`. Multiple EB IDs per row come from ESP-splits (Microsoft / Google / SMTP) and audience-tier splits (Professional / Role / Personal / Managers+ / etc.). The audience-tier fan-out is preserved in `audience_tiers[]` so BC-11852 (A2 schema v2) can lock the audience-tier enum.

## Summary

- **Logical campaigns**: 77
  - matched (EB ↔ Linear): 26
  - orphan EB (no Linear milestone): 34
  - orphan Linear (no EB record): 17
- **Raw records folded in**: 130 EB + 50 Linear
- **Reconciliation status**:
  - complete: 27
  - partial: 50
  - not-started: 0

## Out-of-canon observations (feed-forward)

Verticals appearing in EB/Linear that aren't (yet) in `plugins/marketing/data/canonicals/_manifest.yaml` — flagged for BC-11853 (A3 canonicals bulk backfill) and BC-11854 (A4 flagship-retail vs shopping-centers taxonomy).

- `Brite Supply S4` — no canonical mapping (candidate for BC-11853/BC-11854)
- `Hotels Resort Holiday Anchor Audit M02` — no canonical mapping (candidate for BC-11853/BC-11854)
- `Test Campaign (Outbound Sales Operations System)` — no canonical mapping (candidate for BC-11853/BC-11854)

**Folded into bucket slugs** (not in canonical _manifest.yaml; needs A3 decision):
- `brite-recruiting` ← `Brite Recruiting`
- `cross-vertical-campaign` ← `250th Anniversary`
- `cross-vertical-reengagement` ← `Prior Year Interested`
- `off-canon-banks` ← `Banks`
- `off-canon-car-washes` ← `Car Washes`
- `off-canon-community-management` ← `Community Management`
- `off-canon-museums` ← `Museums & Art Galleries`
- `off-canon-retail` ← `Luxury Retail Stores`
- `supply-installer-network` ← `Lighting Installers`

## Inventory

| # | FY/Mo | Vertical (raw → slug) | Offer (raw) | Entity | Linear milestone | EB IDs (workspace) | Audience tiers | EB status | Leads / Sent / Repl / Bnc | Reply % | X-ref | Recon |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ?? | Hotels Resort Holiday Ancho… → `MISS` *(miss)* | — | nites | `17450de2` [ARCHIVED] Hotels Resort Holiday Anchor… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | complete |
| 2 | FY25/M09 | Bars → `bars-restaurants` *(override)* | — | nites | `c9f5e24a` [ARCHIVED] FY25, M09 | Bars | Mgr+ Pro; `db598bb0` [ARCHIVED] FY25, M09 | Bars | Owners & … | 8(b), 10(b), 11(b) | Bar Owners, GMs | General Emails, Managers+ | Professional Emails | All ESPs | archived, completed | 27187 / 49900 / 1213 / 546 | 2.43% | match | complete |
| 3 | FY25/M09 | Community Management → `off-canon-community-management` *(bucket)* | — | nites | `3710c0b4` [ARCHIVED] FY25, M09 | Community Manage… | 7(b) | Managers+ | Professional Emails | All ESPs | paused | 9240 / 17717 / 586 / 365 | 3.31% | match | complete |
| 4 | FY25/M09 |  → `MISS` *(miss)* | — | nites | — | 9(b) | Bars Owners, GMs | Personal Emails | archived | 1887 / 65 / 3 / 2 | 4.62% | orphan-eb | partial |
| 5 | FY25/M10 | Drive-Thru → `bars-restaurants` *(override)* | — | nites | `a9b99032` [ARCHIVED] FY25, M10 | Drive-Thru | Emp… | 12(b) | Employees | Professional Emails | completed | 2295 / 4581 / 17 / 4 | 0.37% | match | complete |
| 6 | FY25/M10 | Hotels → `hotels-resorts` *(override)* | — | nites | `cf52da59` [ARCHIVED] FY25, M10 | Hotels | Mgr+ Pro | 14(b) | Managers+ | Professional Emails | All ESPs | completed | 67512 / 130036 / 3144 / 3179 | 2.42% | match | complete |
| 7 | FY25/M11 | Apartments → `apartments` | — | nites | `1e7c8c1b` [ARCHIVED] FY25, M11 | Apartments | Role; `239e978e` [ARCHIVED] FY25, M11 | Apartments | Mgr… | 15(p), 37(b), 38(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, completed | 7242 / 13536 / 407 / 88 | 3.01% | match | complete |
| 8 | FY25/M11 | Car Dealerships → `auto-dealerships` *(override)* | — | nites | `8719f727` [ARCHIVED] FY25, M11 | Car Dealerships … | 5(p), 15(b), 16(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | active, archived, completed | 59890 / 42071 / 280 / 825 | 0.67% | match | complete |
| 9 | FY25/M11 | Drive-Thru Restaurants → `bars-restaurants` *(override)* | — | nites | `3d513031` [ARCHIVED] FY25, M11 | Restaurants & Ba…; `2bfbcb2c` [ARCHIVED] FY25, M11 | Restaurants & Ba… | 9(p), 10(p), 19(p), 39(b), 40(b), 43(b), 44(b) | Personal Emails | All ESPs, Professional Emails | All ESPs, Professional Emails | All ESPs | Direct Question Offer, Role Emails | All ESPs | archived, completed, draft, paused | 20308 / 32085 / 1112 / 473 | 3.47% | match | complete |
| 10 | FY25/M11 | Casinos → `casinos` | — | nites | `5521ef12` [ARCHIVED] FY25, M11 | Casinos | Mgr+ P…; `a7c43508` [ARCHIVED] FY25, M11 | Casinos | Role | 1(p), 47(b), 48(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, completed | 822 / 1603 / 27 / 23 | 1.68% | match | complete |
| 11 | FY25/M11 | Churches → `churches` | — | nites | `5651e96e` [ARCHIVED] FY25, M11 | Churches | Mgr+ …; `ea9079f3` [ARCHIVED] FY25, M11 | Churches | Role | 7(p), 33(b), 34(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | active, archived, completed | 37636 / 52586 / 1602 / 310 | 3.05% | match | complete |
| 12 | FY25/M11 | Healthcare Facilities → `hospitals` *(override)* | — | nites | `7978d80f` [ARCHIVED] FY25, M11 | Healthcare Facil… | 12(p), 29(b), 30(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, completed, draft | 998 / 1960 / 36 / 22 | 1.84% | match | complete |
| 13 | FY25/M11 | Hotels → `hotels-resorts` *(override)* | — | nites | — | 2(p) | Personal Emails | All ESPs | archived | 88 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 14 | FY25/M11 | Municipalities → `municipalities` | — | nites | — | 16(p), 25(b), 26(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, draft | 238 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 15 | FY25/M11 | Banks → `off-canon-banks` *(bucket)* | — | nites | `1c840d25` [ARCHIVED] FY25, M11 | Banks | Mgr+ Pro; `1d9fcdff` [ARCHIVED] FY25, M11 | Banks | Role | 11(p), 35(b), 36(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, completed | 2762 / 5336 / 164 / 47 | 3.07% | match | complete |
| 16 | FY25/M11 | Car Washes → `off-canon-car-washes` *(bucket)* | — | nites | `41b03af5` [ARCHIVED] FY25, M11 | Car Washes | Role | 18(p), 45(b), 46(b) | Personal Emails | All ESPs, Professional Emails | All ESPs, Role Emails | All ESPs | archived, completed, draft | 496 / 944 / 41 / 13 | 4.34% | match | complete |
| 17 | FY25/M11 | Community Management → `off-canon-community-management` *(bucket)* | — | nites | `a346f77b` [ARCHIVED] FY25, M11 | Community Manage… | 17(p), 41(b), 42(b) | Personal Emails | All ESPs, Professional Emails | All ESPs, Role Emails | All ESPs | archived, completed, draft | 7744 / 15061 / 507 / 135 | 3.37% | match | complete |
| 18 | FY25/M11 | Museums & Art Galleries → `off-canon-museums` *(bucket)* | — | nites | — | 8(p), 23(b), 24(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, draft | 31 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 19 | FY25/M11 | Luxury Retail Stores → `off-canon-retail` *(bucket)* | — | nites | — | 3(p), 27(b), 28(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, draft | 50 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 20 | FY25/M11 | Shopping Centers, Malls, Ou… → `shopping-centers` *(override)* | — | nites | `78e64de2` [ARCHIVED] FY25, M11 | Shopping Centers… | 6(p), 21(b), 22(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, completed, draft | 3289 / 6380 / 163 / 78 | 2.55% | match | complete |
| 21 | FY25/M11 | Stadiums, Arenas & Sports C… → `sports-stadiums` *(override)* | — | nites | — | 13(p) | Personal Emails | All ESPs | archived | 0 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 22 | FY25/M11 | Colleges & Universities → `universities` *(override)* | — | nites | — | 14(p), 31(b), 32(b) | Managers+ | Professional Emails | All ESPs, Personal Emails | All ESPs, Role Emails | All ESPs | archived, draft | 8387 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 23 | FY26/M02 | Municipalities → `municipalities` | — | nites | — | 53(b) | Professional Emails | All ESPs | paused | 11019 / 8460 / 442 / 178 | 5.22% | orphan-eb | partial |
| 24 | FY26/M02 | Community Management → `off-canon-community-management` *(bucket)* | — | nites | — | 51(b) | Professional Emails | All ESPs | completed | 6141 / 11650 / 335 / 186 | 2.88% | orphan-eb | partial |
| 25 | FY26/M02 | Colleges & Universities → `universities` *(override)* | — | nites | — | 52(b) | Professional Emails | All ESPs | completed | 4207 / 7804 / 296 / 122 | 3.79% | orphan-eb | partial |
| 26 | FY26/M03 | Restaurants & Bars America … → `bars-restaurants` *(override)* | — | nites | — | 21(p), 57(b), 58(b) | Personal Emails | All ESPs, Professional Emails | All ESPs, Role Emails | All ESPs | completed | 4588 / 8302 / 165 / 79 | 1.99% | orphan-eb | partial |
| 27 | FY26/M03 | Casinos → `casinos` | — | nites | — | 54(b) | Professional Emails | All ESPs | paused | 1545 / 2883 / 75 / 63 | 2.6% | orphan-eb | partial |
| 28 | FY26/M03 | Hotels Summer Activation → `hotels-resorts` *(override)* | — | nites | — | 56(b), 60(b) | Managers+ (Reverified) | All ESPs, Managers+ | All ESPs | completed, paused | 15034 / 15815 / 342 / 305 | 2.16% | orphan-eb | partial |
| 29 | FY26/M03 | Municipalities America 250 → `municipalities` *(override)* | — | nites | — | 59(b) | Professional Emails | All ESPs | completed | 706 / 1369 / 51 / 16 | 3.73% | orphan-eb | partial |
| 30 | FY26/M04 | Amusement Parks → `amusement-parks` | — | nites | — | 66(b) | Professional Emails | All ESPs | paused | 209 / 127 / 0 / 0 | 0.0% | orphan-eb | partial |
| 31 | FY26/M04 | Apartments → `apartments` | — | nites | — | 70(b) | Professional Emails | All ESPs | active | 1904 / 1183 / 16 / 6 | 1.35% | orphan-eb | partial |
| 32 | FY26/M04 | Aquariums → `aquariums` | — | nites | `eb93cd10` FY26, M04 | Aquariums | Holiday Lighting | 73(b) | Professional Emails | All ESPs | completed | 321 / 585 / 19 / 3 | 3.25% | match | complete |
| 33 | FY26/M04 | Car Dealerships → `auto-dealerships` *(override)* | — | nites | — | 69(b) | Professional Emails | All ESPs | paused | 5506 / 707 / 3 / 2 | 0.42% | orphan-eb | partial |
| 34 | FY26/M04 | Botanical Gardens → `botanical-gardens` | — | nites | — | 63(b) | Professional Emails | All ESPs | completed | 271 / 531 / 17 / 4 | 3.2% | orphan-eb | partial |
| 35 | FY26/M04 | Golf & Country Clubs → `country-clubs` *(override)* | — | nites | — | 65(b) | Professional Emails | All ESPs | active | 4618 / 4816 / 62 / 44 | 1.29% | orphan-eb | partial |
| 36 | FY26/M04 | Hospitals & Healthcare Faci… → `hospitals` *(override)* | — | nites | — | 67(b) | Professional Emails | All ESPs | active | 2094 / 3588 / 31 / 25 | 0.86% | orphan-eb | partial |
| 37 | FY26/M04 | Museums & Art Galleries → `off-canon-museums` *(bucket)* | — | nites | — | 68(b) | Professional Emails | All ESPs | active | 2510 / 4879 / 164 / 43 | 3.36% | orphan-eb | partial |
| 38 | FY26/M04 | Shopping Centers → `shopping-centers` | — | nites | — | 72(b) | Professional Emails | All ESPs | paused | 1968 / 600 / 9 / 5 | 1.5% | orphan-eb | partial |
| 39 | FY26/M04 | Ski Resorts → `ski-resorts` | — | nites | — | 61(b) | Professional Emails | All ESPs | paused | 400 / 378 / 3 / 1 | 0.79% | orphan-eb | partial |
| 40 | FY26/M04 | Sports Stadiums → `sports-stadiums` | — | nites | — | 64(b) | Professional Emails | All ESPs | paused | 518 / 304 / 4 / 3 | 1.32% | orphan-eb | partial |
| 41 | FY26/M04 | Zoos → `zoos` | — | nites | `c679a128` FY26, M04 | Zoos | Holiday Lighting | 62(b) | Professional Emails | All ESPs | active | 441 / 758 / 23 / 3 | 3.03% | match | complete |
| 42 | FY26/M05 | Auto Dealerships → `auto-dealerships` | Year-End Sales Visibility | nites | `860089ba` FY26, M05 | Auto Dealerships | Year-End… | 85(b), 88(b), 92(b) | Professional Emails | active, completed | 5309 / 10512 / 77 / 52 | 0.73% | match | complete |
| 43 | FY26/M05 | Opentable Restaurants → `bars-restaurants` *(override)* | — | nites | — | 49(b) | Role Emails | All ESPs | paused | 4697 / 4544 / 47 / 172 | 1.03% | orphan-eb | partial |
| 44 | FY26/M05 | Botanical Gardens → `botanical-gardens` | 250th Anniversary Activation | nites | `c5b162d0` FY26, M05 | Botanical Gardens | 250th A… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 45 | FY26/M05 | Brite Recruiting → `brite-recruiting` *(bucket)* | Trade Companies | cross-entity | — | 52(p), 130(b), 131(b) | Personal Emails | All ESPs, Professional Emails | All ESPs, Role Emails | All ESPs | active | 1413 / 1925 / 24 / 16 | 1.25% | orphan-eb | partial |
| 46 | FY26/M05 | Casinos → `casinos` | Collaborative Creative Partner | nites | — | 91(b), 94(b), 95(b) | Professional Emails | active, draft | 1568 / 2140 / 23 / 3 | 1.07% | orphan-eb | partial |
| 47 | FY26/M05 | Corporate Campuses → `corporate-campuses` | Year-End Campus Warmth | nites | — | 87(b), 90(b), 93(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 48 | FY26/M05 | 250th Anniversary → `cross-vertical-campaign` *(bucket)* | Opentable Restaurants | cross-entity | — | 50(b) | Professional Emails | All ESPs | paused | 2017 / 2991 / 19 / 82 | 0.64% | orphan-eb | partial |
| 49 | FY26/M05 | Prior Year Interested → `cross-vertical-reengagement` *(bucket)* | Re-engagement | cross-entity | — | 132(b), 133(b), 134(b) | Professional Emails | active | 1509 / 1505 / 86 / 25 | 5.71% | orphan-eb | partial |
| 50 | FY26/M05 | Shopping Centers → `shopping-centers` | Holiday Foot Traffic & Tenant Retention | nites | — | 97(b), 99(b), 101(b) | Professional Emails | completed | 1871 / 3645 / 40 / 72 | 1.1% | orphan-eb | partial |
| 51 | FY26/M05 | Ski Resorts → `ski-resorts` | Night-Time Event & Wedding Venue | nites | — | 96(b), 98(b), 100(b) | Professional Emails | active, completed | 655 / 1030 / 14 / 2 | 1.36% | orphan-eb | partial |
| 52 | FY26/M05 | Sports Stadiums → `sports-stadiums` | Holiday & Off-Season Activation | nites | — | 84(b), 86(b), 89(b) | Professional Emails | draft | 357 / 0 / 0 / 0 | 0.0% | orphan-eb | partial |
| 53 | FY26/M06 | Municipalities → `municipalities` | 250th Anniversary Final Call | nites | `01b1ee94` FY26, M06 | Municipalities | 250th Anni… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 54 | FY26/M06 | Theaters → `theaters` | Year-Round | nites | `06fd698a` FY26, M06 | Theaters | Year-Round | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 55 | FY26/M06 | Wineries & Breweries → `wineries-breweries` *(override)* | Summer Programming | nites | `b051d339` FY26, M06 | Wineries & Breweries | Summ… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 56 | FY26/M07 | Amusement Parks → `amusement-parks` | Winter Holiday Takeover | nites | `9518a3c6` FY26, M07 | Amusement Parks | Winter Ho… | 108(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 57 | FY26/M07 | Apartments → `apartments` | Multi-Property Holiday Portfolio Program | nites | `27427fcf` FY26, M07 | Apartments | Multi-Property… | 114(b), 122(b), 123(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 58 | FY26/M07 | Aquariums → `aquariums` | Holiday Underwater Festival | nites | `982cf8fe` FY26, M07 | Aquariums | Holiday Underwa… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 59 | FY26/M07 | Brite Supply S4 → `MISS` *(miss)* | Year-Round Installer Partnership | nites | `dfd2f55f` FY26, M07 | Brite Supply S4 | Year-Roun… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 60 | FY26/M07 | Casinos → `casinos` | Casino Floor Holiday Takeover | nites | `e99e9f06` FY26, M07 | Casinos | Casino Floor Holi… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 61 | FY26/M07 | Country Clubs → `country-clubs` | Members' Christmas Gala Production | nites | `d76e1ae1` FY26, M07 | Country Clubs | Members' Ch… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 62 | FY26/M07 | Flagship Retail → `flagship-retail` *(override)* | Custom Illuminated Artwork | labs | `9ea32701` flagship-retail-vp-marketing-custom-ill… | 138(b), 139(b), 140(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 63 | FY26/M07 | Historic Sites → `historic-sites` | Heritage Week & Holiday Tourism Driver | nites | `23d8b1a8` FY26, M07 | Historic Sites | Heritage W… | 111(b), 116(b), 117(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 64 | FY26/M07 | Hospitals → `hospitals` | Donor-Recognition & Foundation Season | nites | `f542bb56` FY26, M07 | Hospitals | Donor-Recogniti… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 65 | FY26/M07 | Hotels & Resorts → `hotels-resorts` | Custom Illuminated Artwork | labs | `cf1a7a5c` FY26, M07 | Hotels & Resorts | Aman-Tie…; `9a82a5b0` hotels-resorts-director-of-resort-exper… | 135(b), 136(b), 137(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 66 | FY26/M07 | Local Retail (Utah) → `local-retail` *(override)* | Storefront Seasonal & Permanent Illumin… | nites | `dddaf314` FY26, M07 | Local Retail (Utah) | Store… | 124(b), 126(b), 127(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 67 | FY26/M07 | Shopping Centers → `shopping-centers` | Anchor Tenant Holiday Center-Court | nites | `ffc93c9e` FY26, M07 | Shopping Centers | Anchor T… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 68 | FY26/M07 | Ski Resorts → `ski-resorts` | Village Base-Area Holiday Takeover | nites | `c9f0af23` FY26, M07 | Ski Resorts | Village Base-… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 69 | FY26/M07 | Sports Stadiums → `sports-stadiums` | Gameday Holiday Fan-Zone Activation | nites | `b41149c4` FY26, M07 | Sports Stadiums | Gameday H… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 70 | FY26/M07 | Lighting Installers → `supply-installer-network` *(bucket)* | Training Library & Brite Platform Access | supply | `ce6a3c30` FY26, M07 | Lighting Installers | Train… | 125(b), 128(b), 129(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 71 | FY26/M07 | Theaters → `theaters` | Producer's Night Gala & Donor Holiday | nites | `262fa9be` FY26, M07 | Theaters | Producer's Night… | 113(b), 120(b), 121(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 72 | FY26/M07 | Tribes & Reservations → `tribes-reservations` *(override)* | Cultural Festival & Holiday Activation | nites | `b9c6deb5` FY26, M07 | Tribes & Reservations | Cul… | 112(b), 118(b), 119(b) | Professional Emails | draft | 0 / 0 / 0 / 0 | 0.0% | match | complete |
| 73 | FY26/M07 | Universities → `universities` | Holiday Lighting | nites | `0608871d` FY26, M07 | Universities | Holiday Ligh… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 74 | FY26/M08 | Botanical Gardens → `botanical-gardens` | Holiday Lighting | nites | `615e6393` FY26, M08 | Botanical Gardens | Holiday… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 75 | FY26/M08 | Zoos → `zoos` | Holiday Lighting | nites | `7ef43d09` FY26, M08 | Zoos | Holiday Lighting | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 76 | FY26/M09 | HOAs Self-Managed → `hoas` *(override)* | Holiday Lighting | nites | `41c8e21f` FY26, M09 | HOAs Self-Managed | Holiday… | — | — | — | 0 / 0 / 0 / 0 | 0.0% | orphan-linear | partial |
| 77 | FY??/M?? | Test Campaign (Outbound Sal… → `MISS` *(miss)* | — | nites | — | 20(p), 55(b) | — | completed | 2 / 2 / 0 / 0 | 0.0% | orphan-eb | partial |

## How to read this

- **Vertical (raw → slug)**: `raw` is the EB/Linear display string; `slug` is the canonical_manifest.yaml entry (or `bucket-…` / `MISS` when inference falls through). `*(override)*` means matched via the build script's display-overrides table; `*(bucket)*` means folded into a non-canonical bucket pending an A3/A4 decision.
- **EB IDs**: `(b)` = b2b workspace; `(p)` = personal. Three IDs for one row typically = ESP split (Microsoft / Google / SMTP).
- **Audience tiers**: each tier is its own EB record but the same logical campaign. BC-11852 will lock the enum.
- **Recon**: `complete` = EB + Linear + canonical slug all present; `partial` = one of {EB, Linear, canonical slug} missing; `not-started` = none of the three (this should be 0 for valid rows).

## Spot-check (validation criterion)

5 random EB IDs verified resolvable via `get_campaign` at snapshot time (BC-11851 validation criterion). Replied/bounced counts may have drifted since the list snapshot was taken — `get_campaign` is live, `list_campaigns` lags by a session.

| EB ID | Workspace | Name | Status | Verified |
|---|---|---|---|---|
| 7 | b2b | `FY25, M09 \| Community Management \| Managers+ \| Professional Emails \| All ESPs` | paused | yes |
| 33 | b2b | `FY25, M11 \| Churches \| Managers+ \| Professional Emails \| All ESPs` | active | yes |
| 73 | b2b | `FY26, M4 \| Aquariums \| Professional Emails \| All ESPs` | completed | yes |
| 134 | b2b | `SMTP \| FY26, M05 \| Prior Year Interested \| Re-engagement \| Professional Emails` | active | yes |
| 52 | personal | `FY26, M05 \| Brite Recruiting \| Trade Companies \| Personal Emails \| All ESPs` | active | yes |

## Sources

- `docs/reconciliation/_sources/linear-milestones.json` — Brite GTM `list_milestones` snapshot
- `docs/reconciliation/_sources/eb-b2b-campaigns.csv` — b2b workspace paginated rollup (109 records)
- `docs/reconciliation/_sources/eb-personal-campaigns.csv` — personal workspace paginated rollup (21 records)
- Generator: `plugins/marketing/scripts/build_master_index.py` (stdlib-only)

Refresh: pull the three snapshots via MCP (`list_milestones` + `list_campaigns` x2 paginated), replace files in `_sources/`, then `python3 plugins/marketing/scripts/build_master_index.py`.

## Feed-forward for sibling BCs

- **BC-11852 (A2 schema v2 — audience tier enum)**: audience-tier strings found in EB across the inventory: `Professional Emails`, `Role Emails`, `Personal Emails`, `General Emails`, `Managers+`, `Managers+ (Reverified)`, `Employees`, `Bar Owners, GMs`, plus `Direct Question Offer` as a copy-modifier appended to Professional Emails. These should drive the enum lock.
- **BC-11853 (A3 canonicals bulk backfill)**: 4 verticals appear in EB/Linear with no canonical mapping (see *Out-of-canon observations* above); 9 more are folded into ad-hoc bucket slugs pending decision (`off-canon-banks`, `off-canon-car-washes`, `off-canon-museums`, `off-canon-retail`, `off-canon-community-management`, `cross-vertical-reengagement`, `cross-vertical-campaign`, `brite-recruiting`, `supply-installer-network`).
- **BC-11854 (A4 flagship-retail vs shopping-centers taxonomy)**: 3 EB campaigns + 1 Linear milestone use `flagship-retail` as a distinct vertical; `shopping-centers` (canonical) is a separate sibling. Decision needed.
- **BC-11856 (A6 build /marketing:audit-campaigns)**: this index is a one-shot; the recurring drift detector reads from the same three snapshot sources and diffs against the previous run.
- **BC-11858 (A8 M07 in-flight scaffolds resolve)**: 2 slug-form milestones (`hotels-resorts-...-fy26-m07`, `flagship-retail-...-fy26-m07`) co-exist with matching pipe-form milestones from earlier scaffolding passes — clean-up decision needed.

