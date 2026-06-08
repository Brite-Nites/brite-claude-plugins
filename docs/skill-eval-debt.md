# Skill / command eval-debt list (ADR-028 Phase-1, BC-12590)

<!--
  MACHINE-READ by scripts/eval/eval_gate.py. Keep the table below as the single
  source of truth for which existing commands are grandfathered (no behavioral
  eval yet). Schema (positional columns; rows keyed on the full repo-relative path
  so colliding basenames like ship/review/session-start stay distinct):

    | command | plugin | status | reason | added |

  status ∈ { grandfathered, waiver }.
    - grandfathered: a PRE-EXISTING (bootstrap-time) command with no eval yet — the
      Phase-2 backfill set. A grandfathered row does NOT clear a NET-NEW command
      (one added in the same PR): note #1 keys net-new on the git ADD status, so
      laundering a new command in as "grandfathered" is blocked by the diff-gate.
    - waiver: a command that genuinely can't be eval'd yet. It MUST also carry an
      in-file `# eval-waiver: <reason>` marker (ADR-028 D1: explicit, finite, never
      silent). The --check lint enforces the coupling in BOTH directions.

  Regenerate the grandfathered set from the live surface with:
    python3 scripts/eval/eval_gate.py --bootstrap --added <YYYY-MM-DD>
  …and PR-review the diff. After bootstrap, add/remove rows BY HAND as commands land
  or get evals (re-running --bootstrap overwrites hand edits — it's a regen, not a
  merge). The --check integrity lint keeps the file honest vs the live surface.
-->

This file is the **forward-only ratchet's grandfather record** (ADR-028 D1) and the
**Phase-2 backlog**. The M5 gate (`scripts/eval/eval_gate.py`) reads it two ways:

- **diff-gate** (the `pull_request` CI job): a *changed, pre-existing* command on this
  list stays **eval-exempt** (Split A′ — the eval is grandfathered, deferred to
  Phase 2). A *net-new* command (git ADD) is NOT cleared by a grandfathered row — it
  needs a passing eval or a `# eval-waiver` marker. Structural R1
  (`disable-model-invocation`) is **not** grandfathered — it blocks any changed
  command regardless of this list (gated by changed-set membership alone).
- **`--check`** (the integrity lint, run in `validate.sh`): enforces
  `debt ∩ ADAPTERS == ∅`, `debt ∪ ADAPTERS == the full command surface`, and the
  symmetric `status: waiver` ⇔ in-file `# eval-waiver` coupling — so a net-new command
  can't merge un-recorded, a deleted command can't leave a stale row, and a waiver can
  never be silent. This is what keeps the list honest and waivers "never silent."

## Phase-2 trigger (ADR-028 D1)

Phase 2 (retroactive backfill of behavioral evals across the commands below, and
promotion of advisory structural checks to blocking) starts when **both** hold:

1. the behavioral-eval harness has shipped and is **proven on ≥3 forward commands**
   (today: 1 — `plan-campaign`); **and**
2. the **per-eval authoring cost is known** (so the retrofit across this list is
   estimable).

Until then this is a forward-only gate: it bites net-new / changed commands, not the
grandfathered surface. Committing to Phase 2 up front is what stops "forward-only"
from becoming "forever-only."

## Grandfathered / waived commands

| command | plugin | status | reason | added |
|---|---|---|---|---|
| `plugins/cadence/commands/weekly.md` | cadence | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/add-domain.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/add-sub-flow.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/audit.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/deprecate-legacy.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/flow-architecture/commands/office-hours.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/plan-design.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/plan-docs.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/plan-eng.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/plan-qa.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/plan-story.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/retro.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/retrofit-project.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/review.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/session-start.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/flow-architecture/commands/ship.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/flow-architecture/commands/start-project.md` | flow-architecture | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/capture-idea.md` | marketing | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/marketing/commands/icp-refinement-review.md` | marketing | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/marketing/commands/import-campaign.md` | marketing | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/marketing/commands/launch-campaign.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/new-offer.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/new-persona.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/new-vertical.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/offer-performance.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/portfolio-snapshot.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/setup-email-bison.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/setup-tam-map.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/sync-campaign-status.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/marketing/commands/tam-map.md` | marketing | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/revops/commands/deploy-prod.md` | revops | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/revops/commands/deploy-sandbox.md` | revops | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/revops/commands/doctor.md` | revops | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/revops/commands/post-deploy-runbook.md` | revops | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/revops/commands/setup-sandbox.md` | revops | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/revops/commands/update-sf-campaign-status.md` | revops | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/analytics.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/architecture-decision.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/audit-trail.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/bug-report.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/code-review.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/create-plugin.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/deployment-checklist.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/fact-check.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/flywheel-metrics.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/onboarding-checklist.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/project-start.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/promote-precedent.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/raise-a-ticket.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/report-issue.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/retrospective.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/review.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/scope.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/security-audit.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/session-start.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/setup-claude-md.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/ship.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/smoke-test.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |
| `plugins/workflows/commands/sprint-planning.md` | workflows | grandfathered | no-eval (pre-ADR-028); R1 side-effecting (untouched) | 2026-06-08 |
| `plugins/workflows/commands/tech-stack.md` | workflows | grandfathered | no-eval (pre-ADR-028) | 2026-06-08 |

