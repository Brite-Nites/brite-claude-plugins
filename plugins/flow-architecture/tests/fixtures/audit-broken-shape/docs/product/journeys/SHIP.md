---
domain: SHIP
status: shipped
last_reviewed: 2026-05-10
---

# SHIP journey

End-to-end journey for an engineer who is shipping a release and watching it through production.

## Sub-flows

- [SHIP-01](../flows/SHIP/SHIP-01.md) — Ship readiness
- [SHIP-02](../flows/SHIP/SHIP-02.md) — Ship rollback
- [SHIP-03](../flows/SHIP/SHIP-03.md) — Ship telemetry

## Narrative

An engineer checks readiness before shipping (SHIP-01); if a regression appears post-deploy, they roll back (SHIP-02); when the release is healthy, they verify via telemetry (SHIP-03).
