---
flow_id: WGT-10
domain: WGT
status: NOT_STARTED
parent_issue: BC-20031
personas: [tm, bad token!, off, intake-clerk]
related_flows: []
intent: ../../intent.md
last_reviewed: 2026-06-10
---
# WGT-10: Archive processed intakes

> Fixture story doc — two-digit flow suffix (natural sort: WGT-10 sorts AFTER WGT-2/WGT-3,
> where lexicographic ordering would put it first), a charset-invalid persona token
> (`bad token!`) that must be skipped, never emitted raw into YAML, and a YAML-keyword
> persona (`off`) that must be emitted double-quoted or a YAML consumer reads it as
> boolean False. `tm` duplicates WGT-1's.

## Job story

When intakes are processed, I want them archived, so the queue shows only live work.
