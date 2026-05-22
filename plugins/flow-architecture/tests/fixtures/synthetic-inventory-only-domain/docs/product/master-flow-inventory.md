# Master Flow Inventory

Fixture for BC-9971 `flow-classify-domain-state.sh` v-slice — represents the
state Brand Hub iter-2 (2026-05-13) left for the 9 BC-9559 children: one
domain has an H3 section + sub-flow rows in inventory, but no Linear
milestone, no journey doc, and no story docs were authored.

Schema reflects Q20 amendment 2 (BC-10352, 2026-05-22): lowercase
kebab-case domain slugs, backtick-wrapped H3, em-dash separator. Matches
Brand Hub iter-2's actual shipped inventory shape.

## PLATFORM FOUNDATIONS

### `asset-discovery` — Asset Discovery & Catalog (3 flows)

| ID | Title | Primary persona | Notes |
|---|---|---|---|
| asset-discovery-01 | Browse asset catalog | Brand admin | mvp |
| asset-discovery-02 | Search assets by metadata | Brand admin | mvp |
| asset-discovery-03 | Filter by collection | Brand admin | nice-to-have |

---
