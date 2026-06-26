# 038. FDA-audit action distributed via a scoped moving major tag (`fda-audit-v1`)

**Status:** Accepted — the "Enforcement stays advisory" decision point is **superseded by [ADR-039](039-fda-audit-advisory-to-required.md)** (2026-06-26)
**Date:** 2026-06-23
**Linear:** [BC-13773](https://linear.app/brite-nites/issue/BC-13773) (fan-out foundation) · [BC-12303](https://linear.app/brite-nites/issue/BC-12303) (wire FDA audit into consumer CI) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [036](036-fda-story-frame-bold-span-match.md) (α — story-frame predicate) · [037](037-fda-redirect-stub-convention.md) (β — redirect-stub gate). Both shipped the runner this tag distributes.

## Context

The mechanism PR (#485) shipped a composite action `.github/actions/fda-audit` plus the deterministic runner `plugins/flow-architecture/scripts/run_fda_ci_audit.py`, single-sourced in `brite-claude-plugins`. The brite-sites pilot (BC-13745) wired it by pinning the action to a **per-repo merge SHA**: `uses: Brite-Nites/brite-claude-plugins/.github/actions/fda-audit@ad71acaa…`.

That pin does not scale to the fan-out (brand-hub → lseo → labs → roster → supply). Every runner fix (e.g. α's predicate loosening, β's redirect gate, or the next bug) would require a separate PR to **every** consumer repo to bump the SHA — N PRs per fix — and consumers silently drift to whatever SHA they last pinned. The fan-out needs a single maintained ref the plugin owns.

The action sources the runner by a **relative path inside its own `@ref` checkout** (`$ACTION_PATH/../../../plugins/flow-architecture/scripts/run_fda_ci_audit.py`), so whatever ref a consumer pins resolves the runner *at that same ref* — there is no separate runner artifact to version or bundle. This makes a moving ref viable: move the ref, and every consumer's next CI run picks up the new runner.

## Decision

**Distribute the action via a moving major tag `fda-audit-v1`, maintained in `brite-claude-plugins` and force-moved to each new known-good runner commit.** Consumers pin:

```yaml
uses: Brite-Nites/brite-claude-plugins/.github/actions/fda-audit@fda-audit-v1
```

- **Scoped tag name, not bare `v1`.** The repo already uses `vX.Y.Z` for marketplace releases (currently `v3.29.0`) and `flow-architecture@vX.Y.Z` for plugin tags. A bare `v1` would read as a repo-version tag sitting inside the marketplace v-line, and a future breaking `v2` would **collide with the existing `v2.0.0` marketplace tag**. `fda-audit-v1` is unambiguous and collision-free across both existing namespaces. (The action path already scopes the `uses:`; the tag name must not masquerade as a repo version.)
- **Breaking changes → opt-in `fda-audit-v2`.** A backward-incompatible runner/gate change cuts a new major; consumers migrate their `@ref` deliberately. `fda-audit-v1` only ever moves forward-compatibly.
- **The third-party `actions/checkout` stays SHA-pinned.** We move-pin only our own first-party action in our own org; we do not relax supply-chain hygiene on third-party actions (GitHub's own guidance).
- **Enforcement stays advisory.** All consumer mains are unprotected → the `fda-audit` check is visible-but-not-required. Promoting it to a GitHub branch-protection *required* check is a deferred, per-repo follow-up (see ADR-037 / the BC-12303 tracks; grill Q6).
  - **[Superseded 2026-06-26 by [ADR-039](039-fda-audit-advisory-to-required.md), BC-13795.]** Both halves of this bullet were overturned by live verification: (a) the mains are **not** uniformly unprotected — `brite-sites`/`brite-base` use classic branch protection and `brand-hub` uses rulesets; (b) `fda-audit` is now a **required** check on those three (the other four stay advisory pending an owner-approved protection decision). The deferred follow-up referenced here is what ADR-039 resolves.

## Consequences

- A runner fix is a **single tag move** in `brite-claude-plugins`; all consumers pick it up on their next CI run — no per-repo PR, no drift.
- Trades **reproducibility** (a moving tag is not immutable) for **maintainability**. Acceptable because the gate is advisory and internal-only, and a bad runner is rolled back by moving the tag back to the prior good commit. Immutable point tags (`fda-audit-v1.x.y`) can be added later if pin-rollback is ever needed — deliberately YAGNI for ~5 internal advisory consumers.
- The brite-sites pilot re-points `@ad71acaa…` → `@fda-audit-v1` as the first proof the tag resolves and runs (BC-13773), and is upgraded to the fan-out template (self-trigger `paths:` including the workflow file + `workflow_dispatch:`).
- The tag is cut at the post-β SHA (the merged α + β runner) and force-moved on each subsequent runner change. No plugin version bump — the tag is git-infra, not a plugin release.

## Rejected alternatives

- **Per-repo SHA pin (the pilot's initial approach).** Maximal reproducibility, but N PRs per runner fix and silent consumer drift. Rejected for the fan-out; retained only as the pilot's one-repo bootstrap, now superseded.
- **Copy the runner into each consumer repo.** Drift + N maintenance points; already rejected by the mechanism PR in favour of single-sourcing via the action.
- **Bare `v1` tag.** Collides with the marketplace `vX.Y.Z` line; the breaking-change path `v2` hard-collides with the existing `v2.0.0` marketplace tag.
- **Immutable-only point tags (`fda-audit-v1.0.0`, consumers pin exact).** Same scaling problem as SHA pins — every fix needs a per-repo bump. The moving major is what removes the per-repo PR.
- **Publish to the GitHub Marketplace / a dedicated action repo.** Heavier process for an internal-only action; the monorepo composite action + moving tag is sufficient.
