## Design: BC-5906 follow-up — launch-campaign Phase 3 VARIABLES reality gaps

**Issue**: BC-6299 — launch-campaign Phase 3 VARIABLES custom-variables reality gaps (Sx-2/3/4 + F15)
**Date**: 2026-04-29

### Problem
BC-5906 round-2 dogfood surfaced 4 ways the launch-campaign spec's Phase 3 framing of EB custom variables doesn't match how EB actually behaves: no workspace-level `default` field exists (Sx-2), names are silently lowercased on store (Sx-3), no DELETE endpoint exists (Sx-4), and the 3-way new/existing/conflicting classification collapses to 2-way (F15). Two render-engine behaviors remain unverified — case-sensitivity (whether `{UPPERCASE_TOKEN}` resolves against a lowercase-stored variable) and empty-value handling (what EB renders when a lead's variable value is blank).

### Approach
Land the 7 prescribed Phase 3 sub-edits to make the spec match EB's verified API behavior. Co-update `email-bison.md` with 3 EB-API gotcha bullets (Sx-2/3/4) per the BC-6298 dogfood-bundle precedent. Add a guardrail paragraph to BC-6308's issue body locking in case-sensitivity AND empty-value verification at Phase 4 lead spot-check during round-3 — pushing the unverified-behavior tests to the next planned live-walk rather than paying live-test cost in this session.

### Key Decisions
1. **Defer render-engine tests to BC-6308 round-3 with hardened guardrail.** EB has no pure preview endpoint; testing requires a real `/test-email` SMTP send (~15-20 min, sender-reputation cost). Round-3 already walks Phase 4 + Phase 10 lead spot-checks naturally — we lock in 2 specific verifications there instead of paying setup cost now. Matches BC-5870 verification-side-effects pattern.
2. **Co-update email-bison.md with 3 gotcha bullets.** 4th application of the BC-6298 dogfood-bundle pattern (procedural + canonical reference co-update). Keeps the canonical EB reference doc honest as Phase X spec fixes land.
3. **Preserve UPPERCASE artifact convention pending evidence.** Don't lowercase the merge-token convention across 14 marketing skills on an unverified premise. If round-3 finds render is case-sensitive, the spinoff issue does the convention churn with real evidence.
4. **Phase 4 fallback semantics already correct.** `launch-campaign.md` line 364 already uses artifact `default` as per-lead fill-in. No Phase 4 edits needed — only clarify in Phase 3 that `default` lives at lead-level, not workspace-level.

### Alternatives Considered
- **Lowercase artifact convention now** — Rejected: 14-skill blast radius on unverified premise; preserves human-readable templates by waiting for evidence.
- **Live-test in this session via /test-email** — Rejected: 15-20 min cost + real send, when round-3 will surface the same answer as a side-effect of work it has to do anyway.
- **Bake richer defaults into email-copywriting templates** — Out of scope: separate skill, separate concern. File as spinoff if round-3 finds EB renders empty values poorly.

### Risks & Mitigations
- BC-6308 round-3 skips the spot-check or runs without exercising empty values → guardrail is explicit + names both tests in the issue body.
- email-bison.md edits drift from launch-campaign.md edits → write both in same commit so they reference each other.
- 4th application of BC-6298 bundle pattern without promotion → user already declined CLAUDE.md promotion at 3rd-instance threshold (BC-6300); this remains per-issue precedent trace, no promotion attempt this PR.

### Scope Boundaries
- **In scope**: 7 Phase 3 sub-edits to launch-campaign.md; 3 EB-API gotcha bullets in email-bison.md; BC-6308 issue-body guardrail paragraph; marketing plugin version bump (plugin.json + marketplace.json).
- **Out of scope**: lowercasing artifact convention; richer email-copywriting default text; any actual render-engine testing (deferred to BC-6308 round-3); other Phase X follow-ups (BC-6301/6302/6303/6304/6307).

### Open Questions
None — both render-engine unknowns are explicitly delegated to BC-6308 round-3 with locked-in spot-check requirements.
