---
domain: SHIP
status: shipped
last_reviewed: 2026-05-10
display_name: Ship
linear_milestone:
  name: Ship
  id: 7f3c2a10-aaaa-4bbb-8ccc-0123456789ab
personas: []
flow_ids_in_scope: []
figma: TBD
intent: ../intent.md
---

# SHIP journey

End-to-end journey for an engineer who is shipping a release and watching it through production.

## Sub-flows

- [SHIP-01](../flows/SHIP/SHIP-01.md) — Ship readiness
- [SHIP-02](../flows/SHIP/SHIP-02.md) — Ship rollback
- [SHIP-03](../flows/SHIP/SHIP-03.md) — Ship telemetry

## Narrative

An engineer checks readiness before shipping (SHIP-01); if a regression appears post-deploy, they roll back (SHIP-02); when the release is healthy, they verify via telemetry (SHIP-03).
