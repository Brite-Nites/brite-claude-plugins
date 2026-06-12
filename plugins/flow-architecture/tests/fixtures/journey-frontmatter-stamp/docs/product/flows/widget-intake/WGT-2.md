---
flow_id: `WGT-2`
domain: WGT
status: NOT_STARTED
parent_issue: BC-20011
personas:
  - operator

  - finance-auditor
related_flows: []
intent: ../../intent.md
last_reviewed: 2026-06-10
---
# WGT-2: Review intake queue

> Fixture story doc — block-style personas list (the form hand-reshaped GOLD docs use),
> with a backtick-wrapped flow_id (must be stripped clean — if the strip breaks, WGT-2
> drops out of the §3 natural-sort line) and a blank line INSIDE the block list (a
> continuation, not a terminator — if the parser treats it as a terminator,
> finance-auditor drops out of the §2 personas line).
> `operator` is a duplicate of WGT-1's — first-seen dedup keeps WGT-1's position.

## Job story

When the queue fills, I want to review intakes oldest-first, so I can keep latency bounded.
