# 026. revops: promotion-topology command model & vocabulary

**Status:** Accepted
**Date:** 2026-06-05
**Linear:** [BC-12345](https://linear.app/brite-nites/issue/BC-12345) (deploy-integrity epic) · children [BC-12347](https://linear.app/brite-nites/issue/BC-12347) (F1), [BC-12348](https://linear.app/brite-nites/issue/BC-12348) (F2)
**Related:** [ADR-025](025-sfdx-hardis-adoption.md) (hardis adoption — the keystone), [ADR-007](007-revops-plugin-design.md) (revops design), [ADR-009](009-sf-capability-adoption.md) (6-check), [ADR-010](010-plugin-secret-config-canon.md) (secret canon); **bn-salesforce ADR-016** (the authoritative promotion topology this mirrors), **bn-salesforce ADR-014** (pins `revops` as methodology, not a data boundary).

## Context

bn-salesforce **ADR-016** sets Brite's promotion topology: CI-driven deploy (Model A), branch-per-environment, and an enforcement/guidance split (platform enforces; the plugin guides). Per the authority arrow (`CONTEXT.md`; bn-salesforce ADR-014), **bn-salesforce *defines* deploy discipline and `revops` *mirrors* it.** This ADR records the revops-side consequences — how the plugin's commands, guards, and guidance change — and the **command vocabulary**, because the legacy `deploy-*` names mis-describe a world where **CI, not the human, performs the deploy**.

## Decision

**1. Dual path.** Local commands stay raw-`sf` and **never delegate to hardis**; CI uses hardis. (Resolves the single-vs-dual question deferred from BC-12346: **dual**.)

**2. Commands are orchestrators, not engines.** The deploy moved to CI (ADR-016 §2); revops commands drive the dev's *interaction* with the pipeline (inner-loop deploy to one's own org · open the PR · watch CI · promote · post-deploy steps) plus cheap **local pre-flights** and **post-deploy verification**. The plugin stays the dev's primary interface end-to-end — for non-career-SF devs, more hand-holding, not less.

**3. Command vocabulary** — named from the human's *intent*, not the machine's *mechanism* (per the cross-plugin naming convention, [`CONTRIBUTING.md`](../../CONTRIBUTING.md)). Recorded here as **decided vocabulary**; the actual renames are build work and keep **deprecation aliases**:

| legacy | new | safe? | phase |
|---|---|---|---|
| `setup-sandbox` | `setup-dev-workspace` | mutates (auth) | 1 |
| `doctor` | `check-environment-health` | read-only | 1 |
| `deploy-sandbox` | `preview-changes` | throwaway-mutate (own org) | 1 |
| *(new — was `/workflows:ship`→PR)* | `submit-changes-to-integration` | mutates (git/PR) | 1 |
| `deploy-prod` (normal path) | `push-to-production` | mutates (prod via CI) | 1 |
| `deploy-prod --break-glass` | `emergency-deploy-to-production` | mutates (prod) | 1 |
| `post-deploy-runbook` | `run-manual-post-deploy-steps` | mutates (manual) | 1 |
| *(proposed `deploy-status`)* | `show-pipeline-status` | read-only | **defer → 2** |
| *(new)* | `promote-to-uat` | mutates | 2 |

Org aliases: `brite-sandbox` → `brite-integration` · per-dev `brite-dev-<name>` · `brite-prod` (keep) · `brite-uat` (Phase 2). Untouched (marketing/GTM seam, [ADR-015](015-gtm-sigma3-sf-campaign-sync.md)): `create-sf-campaign`, `update-sf-campaign-status`.

**4. F1/F2 at both layers.** F1 (`.forceignore` guard, BC-12347) is a local pattern-match that runs in **every** revops deploy/ship command (inner-loop + emergency) **and** mirrors as a CI step; F2 (post-deploy verification) likewise. The emergency path is never unguarded. (BC-12348 doctor semver guard is unaffected — it stays as scoped.)

**5. Guidance layer = config-gated (Option E, revops half).** The plugin **guides** (status · NEXT-footer · statusline · advisory nudges) and **never claims to enforce**. Every guidance/guard mechanism reads a **repo-local pipeline config and no-ops where absent**, so `revops` stays portable (ADR-007 §3.1). Precedent: BC-11983 config-gated strict mode; ADR-008 unset→auto-detect. **Phase-1 guidance slice:** `show-pipeline-status`-equivalent on-demand + statusline + NEXT footer (all read-only, zero portability hazard); advisory PreToolUse nudges + cross-session breadcrumb follow in Phase 2.

**6. Emergency path = re-trigger CI** (`gh workflow run`), staying in the enforced lane; a guarded local `validate → quick-deploy` is a documented last resort; the legacy raw local prod deploy is retired. (Mirrors ADR-016 §6.)

## Consequences

- **Build issues reshaped, not invalidated:** F1/BC-12347 → local pre-flight in the commands **+** a CI mirror; F2/BC-12348 doctor semver → unchanged, plus the post-deploy *verification-scope* gap stays revops's to close. New commands (`submit-changes-to-integration`, `push-to-production`, `promote-to-uat`) + repoints (`deploy-sandbox`→`preview-changes`, `deploy-prod`→`emergency-deploy-to-production`).
- **Sequencing:** the CI half is real only after **ADR-016 Phase 0 (CI org-auth)** lands; the revops command repoints + the read-only guidance slice can ship independently of Phase 0.
- The **cross-plugin naming convention** ([`CONTRIBUTING.md`](../../CONTRIBUTING.md)) generalizes the vocabulary rules beyond revops.

## Reversibility

Command renames keep deprecation aliases; config-gated guidance no-ops in any repo without the pipeline config; nothing couples revops to hardis internals (per ADR-025). Each piece is individually revertible.
