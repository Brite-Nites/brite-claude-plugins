---
flow_id: ONB-01
domain: onboarding
status: BUILT
---

# ONB-01: First-run welcome

## Job story

**When** I sign in for the first time, **I want to** see a guided welcome,
**so I can** reach my first useful action without reading docs.

## Status

BUILT — per the (separate) app repo.

<!--
Fixture note (BC-12909 doc-only skip case): this repo has docs only — NO src/ and
NO app/ directory. The cross-check's repo-level precondition (a code root must
exist) is NOT met, so the WHOLE advisory is skipped with "no code tree to diff"
and emits ZERO warns — even though declared BUILT would otherwise look like
inflation against an all-NOT_STARTED scan. Guards greenfield / doc-only repos
from mass false-inflation noise.
-->
