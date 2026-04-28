## Design: launch-campaign Phase 5 — plain_text deliverability default

**Issue**: BC-6306 — BC-5906 follow-up: launch-campaign Phase 5 — set plain_text + other deliverability defaults on campaign create
**Date**: 2026-04-28

### Problem

Today the `/marketing:launch-campaign` Phase 5 calls `create_campaign(name, type)` only. Email Bison's default is `plain_text: false`, so every campaign created through the spec ships in HTML mode. The copy artifacts produced by `email-copywriting` use `<br><br>` for paragraph breaks and contain spintax — both of which assume plain-text rendering. HTML mode also pulls in tracking pixels, link rewrites, and image references that signal "automated marketing" to spam filters and degrade cold-B2B deliverability. Round-2 dogfood (BC-5906) created 2 campaigns under this default before the issue was caught.

### Approach

After each `create_campaign` call in Phase 5, fire a follow-up `PATCH /api/campaigns/{id}/update` with `plain_text: true`. Always. No operator opt-out — `/marketing:launch-campaign` is the cold-outreach command and HTML mode has no legitimate use case in that context. Record completion in the metadata JSON via a new `plain_text_applied: bool` field so resume knows whether the PATCH loop has run.

### Key Decisions

1. **Scope narrowed to `plain_text` only** — original issue scope included `reputation_building` and `can_unsubscribe`. Both dropped from BC-6306; deferred (no successor issue filed yet — operator wants to think about them separately). BC-6306's Linear title + body must be narrowed before merge so the issue accurately reflects what shipped.
2. **No `--no-plain-text` opt-out flag** — `/marketing:launch-campaign` is exclusively for cold B2B outreach (per the existing § Non-goals + the email-copywriting upstream). HTML mode for cold has no legitimate operator preference; it's a true invariant. An escape hatch would invite drift, not protect a real use case.
3. **Single bool `plain_text_applied` in metadata, not per-campaign object** — PATCH is idempotent (re-asserting `plain_text: true` is a no-op against an already-plain-text campaign). On resume, the spec re-runs the PATCH loop on all campaigns blindly if the flag is not `true`. Per-campaign tracking would add schema shape for no operational benefit.
4. **PATCH ordering: serial inside the existing per-campaign loop** — Phase 5's existing step 5 already iterates over the bucket→ID map. The new PATCH step lives inside that same loop (PATCH right after each create returns its ID), not as a second pass after all creates finish. Keeps create+configure paired per campaign, consistent with how Phase 6 ATTACH LEADS structures its per-campaign work.
5. **No new MCP gate required** — `update_campaign` is NOT on the email-bison.md two-call confirmation gate list (verified at email-bison.md:239–248). Single MCP call per PATCH; no two-call cycle to add.

### Alternatives Considered

- **Per-campaign metadata tracking** (`plain_text_applied: {Google: true, Microsoft: false, Other: true}`) — rejected because PATCH idempotency removes the operational need; the precision adds schema cost without buying anything resume can use.
- **Add `--no-plain-text` opt-out flag** — rejected because no real use case in the cold-outreach context this command serves. Power users wanting HTML campaigns are already in the EB UI.
- **PATCH all 6 deliverability fields explicitly (defensive lock)** — rejected with the scope narrowing; if EB ever changes a default for `open_tracking` or others, that's a separate question to handle when it happens, not pre-emptively.
- **Split PATCH into a second pass after all creates** — rejected because the per-campaign loop is already the right granularity; pairing create+PATCH per campaign keeps partial-failure state easier to reason about.

### Risks & Mitigations

- **Risk**: PATCH succeeds for some campaigns, fails for others mid-loop → metadata records `plain_text_applied: false`, leaving partial real-state. **Mitigation**: same as Phase 5's existing partial-failure pattern — operator inspects EB UI, decides whether to delete partial campaigns or resume. Resume re-runs the PATCH loop blindly; idempotency makes the already-PATCHed campaigns a no-op.
- **Risk**: EB API changes `update_campaign` shape, breaking the PATCH call → silent breakage on every future campaign. **Mitigation**: round-3 dogfood (BC-6308) is the validation checkpoint. Issue body's verification list already requires a UI inspection of the plain_text toggle on a created campaign.
- **Risk**: Linear issue title still says "plain_text + other deliverability defaults" → future readers think BC-6306 covers all 3, but only plain_text shipped. **Mitigation**: narrow the Linear issue title + scope section before PR merge (or before ship). Note the scope narrowing in the PR description.

### Scope Boundaries

**In scope (BC-6306, this PR)**:
- Edit `plugins/marketing/commands/launch-campaign.md` Phase 5 — insert new step 6 (PATCH `plain_text: true`) between current step 5 (Execute creates) and current step 7 (Append to metadata).
- Edit Phase 5 user gate 5 wording — surface that campaigns will be created in plain-text mode.
- Edit § Launch metadata schema — add `plain_text_applied: bool` field; document Phase 5 step 6 as the writer.
- Edit Phase 5 § "If Phase 5 fails mid-loop" — note partial PATCH state + idempotent resume behavior.
- Edit `plugins/marketing/tools/integrations/email-bison.md` — add a brief note (1–2 sentences) under an existing section that the launch-campaign command sets `plain_text: true` post-create via `update_campaign`, with rationale.
- Narrow the BC-6306 Linear issue title + scope description to reflect plain_text-only scope.

**Out of scope**:
- `reputation_building` PATCH — dropped from BC-6306. No successor issue filed; operator wants to think it through separately.
- `can_unsubscribe` PATCH — dropped from BC-6306. CAN-SPAM compliance question deferred.
- `--no-plain-text` opt-out flag — explicitly not adding.
- Defensive PATCH of `open_tracking`, `include_auto_replies_in_stats`, `sequence_prioritization` — explicitly not touching.
- Round-3 dogfood validation — that's BC-6308, blocked-by this PR + the other BC-5906 follow-ups.
- Any change to Phases 1–4 or 6–11.

### Open Questions

None. (Reputation_building + can_unsubscribe disposition is "drop for now, decide later" — that's a separate decision, not an open question for this design.)
