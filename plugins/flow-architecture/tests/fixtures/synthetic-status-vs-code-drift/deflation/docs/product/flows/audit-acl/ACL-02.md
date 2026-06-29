---
flow_id: ACL-02
domain: audit-acl
status: NOT_STARTED
---

# ACL-02: Audit-log write hook

## Job story

**When** a privileged record changes, **I want to** capture an immutable audit
entry, **so I can** reconstruct who changed what after the fact.

## Status

NOT_STARTED — no implementation yet.

<!--
Fixture note (BC-12909 deflation case): this doc is stamped NOT_STARTED, but the
hook + its test are in fact present under src/audit/ (audit-log.ts /
audit-log.test.ts). The code carries no ACL-02 token and this doc cites no
evidence path, so only a semantic codebase-inferrer scan recovers the build —
the cross-check then warns DEFLATION (declared NOT_STARTED < inferred BUILT).
Mirrors brite-roster ACL-02/03/04 + SFI-01.
-->
