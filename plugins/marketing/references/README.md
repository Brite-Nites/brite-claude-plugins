# Marketing references

Shared reference library consumed by the Brite marketing plugin's skills. These are query catalogs, thinking models, signal taxonomies, and decay tables — not executable logic. Skills read from here; nothing in this directory runs on its own.

## Contents

- `research-processes/` — 16 account-research query playbooks (C-suite, competitors, VP leadership, directors, founders, growth signals, hiring, job-role insights, negativity, news, people-creative, PR releases, profiles, reviews, specialist roles). Ported verbatim from the MIT-licensed upstream; search verbs use WebSearch.
- `creative-thinking-models.md` — Five forcing functions (Inversion, Adjacent Transfer, Timing Arbitrage, Specificity Escalator, Ecosystem Gap Analysis) for generating non-obvious GTM angles. Upstream content + Brite-adapted worked examples for Municipalities and Universities.
- `hidden-signals-library.md` — Industry-indexed table of asymmetric outbound signals. Upstream 10 industries + 3 Brite-entity tables (Municipalities, HOAs, Universities) tied to handbook-Active verticals.
- `experiential-lighting-vendor-landscape.md` — Four experiential-lighting vendor archetypes (lantern festival, projection/immersive, holiday installers, LED-retrofit) with named companies, commercial models, and Brite's competitive position. Brite-originated; distilled from BC-5879 session research.
- `offer-design-frameworks.md` — Hormozi value equation, Brunson value ladder, Abraham risk-reversal, and B2B-outbound frontend/backend characteristics. Brite-originated; read by vertical playbooks and preset-composition issues to evaluate and design offers.
- `shelf-life-patterns.md` — Five decay categories (Regulatory/Deadline, Competitive Move, Data Insight, Industry Pattern, Structural) for reasoning about signal timing.
- `vertical-playbooks/` — Per-vertical playbooks distilling the vendor landscape, buyer personas, recency signals, program economics, offer evaluations, voice rules, and anti-slop rules for each targeted vertical. Entries: `zoos.md` (BC-5920), `hotels-resorts.md` (BC-5921). Read by email-copywriting preset composition, tam-mapping, and situation-mining.

## Expected consumers

Future Brite marketing skills will pull from this library:

- `account-research` — research-processes query catalogs
- `situation-mining` — hidden-signals-library + shelf-life-patterns
- `creative-angles` — creative-thinking-models
- `tam-mapping` — hidden-signals-library industry tables
- `campaign-debrief` — shelf-life-patterns for signal-decay attribution
- `vertical-playbooks/*.md` + `email-copywriting/presets/*` — offer-design-frameworks + experiential-lighting-vendor-landscape (apply frontend/backend checklists when proposing or composing offers; apply vendor-archetype frame when positioning Brite against the prospect's incumbent)
- `email-copywriting` preset composition (e.g., BC-5932 zoos, BC-5935 hotels & resorts) — `vertical-playbooks/<vertical>.md` § Offer candidates + § V1 offer picks + § Voice rules + § Anti-slop rules

## Provenance

See [UPSTREAM.md](./UPSTREAM.md) for the pinned commit, license, per-file manifest, and the Serper→WebSearch and Brite-entity swap policies.
