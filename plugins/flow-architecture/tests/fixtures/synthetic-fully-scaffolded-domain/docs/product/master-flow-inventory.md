# Master Flow Inventory

Fixture for BC-9971 — represents a domain fully landed on the filesystem
(H3 in inventory + journey doc + at least one story doc). Linear-side state
(milestone present? parents authored?) is the orchestrator's MCP-side
overlay; this fixture exercises only the filesystem classifier.

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
