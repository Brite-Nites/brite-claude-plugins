# Master Flow Inventory

Fixture for BC-9971 — represents the unusual intermediate state where a
domain has an H3 section AND a journey doc, but no story docs landed yet
(e.g., Phase 5 succeeded but Phase 4 had failed-or-deferred). Used to
verify the classifier returns `journey-exists` (distinct from
`fully-scaffolded-fs`).

Schema reflects Q20 amendment 2 (BC-10352, 2026-05-22): lowercase
kebab-case domain slugs, backtick-wrapped H3, em-dash separator.

## PLATFORM FOUNDATIONS

### `asset-discovery` — Asset Discovery & Catalog (3 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| asset-discovery-01 | Browse asset catalog | Brand admin | mvp |
| asset-discovery-02 | Search assets by metadata | Brand admin | mvp |
| asset-discovery-03 | Filter by collection | Brand admin | nice-to-have |

---
