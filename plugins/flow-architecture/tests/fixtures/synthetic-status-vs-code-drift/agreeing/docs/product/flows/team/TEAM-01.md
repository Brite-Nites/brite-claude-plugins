---
flow_id: TEAM-01
domain: team
status: BUILT
---

# TEAM-01: Invite a teammate

## Job story

**When** I add a colleague, **I want to** send them an invite from the team
settings page, **so I can** get them into the workspace without IT.

## Status

BUILT — `src/team/invite-teammate.tsx` + test.

<!--
Fixture note (BC-12909 agreeing-clean case): doc says BUILT and the impl + test
are present under src/team/. A fresh scan infers BUILT → the cross-check AGREES
(declared == inferred), so NO advisory warn is emitted. This is the negative
control that keeps the check from crying wolf on honest, in-agreement docs.
-->
