# Master Flow Inventory

Fixture for BC-9971 — represents the unusual intermediate state where a
domain has an H3 section AND a journey doc, but no story docs landed yet
(e.g., Phase 5 succeeded but Phase 4 had failed-or-deferred). Used to
verify the classifier returns `journey-exists` (distinct from
`fully-scaffolded-fs`).

## PLATFORM FOUNDATIONS

### ASSET-DISCOVERY --- Asset Discovery & Catalog (3 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| ASSET-DISCOVERY-01 | Browse asset catalog | Brand admin | mvp |
| ASSET-DISCOVERY-02 | Search assets by metadata | Brand admin | mvp |
| ASSET-DISCOVERY-03 | Filter by collection | Brand admin | nice-to-have |

---
