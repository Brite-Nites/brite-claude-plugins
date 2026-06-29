---
flow_id: BILL-01
domain: billing
status: BUILT
---

# BILL-01: Create invoice

## Job story

**When** a job completes, **I want to** generate an invoice from its line items,
**so I can** bill the client without retyping anything.

## Status

BUILT — invoice generation shipped.

<!--
Fixture note (BC-12909 inflation case): this doc claims BUILT, but the repo has a
code root (src/ exists) with NO implementation for BILL-01 — nothing under
src/billing/. A fresh codebase-inferrer scan concludes NOT_STARTED, so the
cross-check warns INFLATION (declared BUILT > inferred NOT_STARTED). The code
root is present so this is NOT the doc-only skip case.
-->
