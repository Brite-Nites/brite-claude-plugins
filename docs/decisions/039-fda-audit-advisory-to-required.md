# 039. FDA-audit advisory → required: drop the paths filter, stage by protection state

**Status:** Accepted
**Date:** 2026-06-26
**Linear:** [BC-13795](https://linear.app/brite-nites/issue/BC-13795) (advisory→required) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [038](038-fda-audit-action-v1-distribution.md) — **supersedes** its "enforcement stays advisory / all consumer mains are unprotected" decision point (see below) · [036](036-fda-story-frame-bold-span-match.md) · [037](037-fda-redirect-stub-convention.md)

## Context

BC-12303 wired the deterministic `fda-audit` check into 7 consumer repos as an **advisory** (visible, non-blocking) status check, distributed via the moving `fda-audit-v1` tag (ADR-038). ADR-038 recorded that promoting it to a **required** branch-protection check was "a deferred, per-repo follow-up" and asserted "**All consumer mains are unprotected**." BC-13795 is that follow-up.

Live verification of all 7 repos on 2026-06-26 overturned two premises:

1. **The "all mains unprotected" premise is false.** Protection state is heterogeneous:
   - **Classic branch protection:** `brite-sites` (`ci` + 1 review), `brite-base` (`Up-to-date check`, `Build, Lint & Test`).
   - **Rulesets:** `brand-hub` (active ruleset = PR + 1 review; **no** status-check rule).
   - **Fully unprotected:** `brite-labs`, `brite-roster`, `brite-supply-commerce`, `lseo-tool`.
   (BC-12303 had recorded `brite-roster` as protected — it is not.)

2. **A required check + a `paths:` filter deadlocks.** Every consumer's `fda-audit.yml` triggers only on `docs/product/**`, `.flow/config.json`, and the workflow file. GitHub leaves a **required** status check **unreported** when its workflow is skipped by a path filter — the PR then sits on "Expected — waiting for status" and can never merge. Proven live: `brite-labs` and `brite-supply-commerce` had **no** `fda-audit` check on their `main` HEAD because the last commit didn't touch FDA paths. So "advisory→required" is **not** a settings-only change.

## Decision

1. **Drop the `paths:` filter** on every consumer where `fda-audit` becomes required. The audit then runs on **every** PR and push to `main`, so the check always reports. It is deterministic (~10s) and a no-op when no FDA docs changed. This also makes the enforced invariant "**`main` is always canon**," not "canon iff you touched docs."

2. **Fix before require.** Merge the workflow change and confirm `fda-audit` green on `main` **first**, then add the required check. This guarantees no deadlock window on a shared repo; the empirical non-docs-PR test then *confirms the fix* rather than *demonstrating an outage*.

3. **Stage by protection state.** Flip only the 3 **already-gated** repos now: `brite-sites` + `brite-base` (classic) and `brand-hub` (ruleset). **Defer** the 4 unprotected repos — requiring a check there means *imposing branch protection*, an owner-approved policy decision tracked separately. They keep the `paths:` filter (and stay advisory) until then.

4. **API discipline.**
   - **Classic:** `PATCH /branches/main/protection/required_status_checks` (the sub-endpoint), read-modify-write *within* it — preserve existing checks, pin every check to `app_id: 15368` (GitHub Actions). Never the full-protection PUT (its read/write shape asymmetry 422s or clobbers reviews/enforce_admins).
   - **Rulesets (brand-hub):** create a **new additive ruleset** `fda-audit-required` (`~DEFAULT_BRANCH`, one `required_status_checks` rule, `integration_id: 15368`, `strict_required_status_checks_policy: false`, OrganizationAdmin + repo-admin bypass). Never edit the live ruleset. Rollback = delete the additive ruleset.

## Consequences

- `fda-audit` runs on every PR on the 3 gated repos (~10s, no-op when no docs changed) — negligible cost for the deadlock-freedom and the "always canon" invariant.
- **Supersedes ADR-038's "Enforcement stays advisory / all consumer mains are unprotected."** That decision point is retired; enforcement is now required on the gated repos, and the unprotected-mains premise was factually wrong.
- The 4 unprotected repos stay advisory until a protection decision; their filter-drop bundles with their future protection PR.
- **Rollback:** classic = restore the prior `checks` set; ruleset = delete `fda-audit-required`. `enforce_admins:false` (classic) and OrganizationAdmin bypass (ruleset) mean an admin can always emergency-merge — no repo can hard-lock.

## Rejected alternatives

- **Companion no-op job** (GitHub's documented "skipped-but-required" pattern): two sources emitting one check name is a maintenance footgun ×N repos; the audit is fast enough that dropping the filter is simpler and unambiguous.
- **Conditional job-level skip:** a GitHub-"skipped" job reintroduces the murky "does a skipped job satisfy a required check?" behavior — the very ambiguity we are killing. Only safe if the skip path still emits a real `success`, which is plumbing to save ~10s.
- **Stay advisory:** defeats the BC-11983 enforcement capstone.
- **Impose protection on all 7 now:** forces org-wide branch-protection policy on teams that never opted in; out of scope for an advisory→required check flip. Tracked as a separate per-repo decision.
- **Full-protection PUT for classic:** read/write shape asymmetry; clobbers reviews/enforce_admins on a naive round-trip.
