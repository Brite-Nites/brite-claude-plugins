# sf-deploy — Brite edition

Deploy orchestration for `Brite-Nites/brite-salesforce`. The repository owns the
metadata, and each environment is reached through one lane.

## Lanes

| Destination | Entry point | Owner |
|---|---|---|
| `brite-dev-<name>` | `/revops:preview-changes --target-org brite-dev-<name>` | developer inner loop |
| `briteint` | `/revops:submit-changes-to-integration` | integration PR + CI |
| `main` / `brite-prod` | Kells-gated promotion, then `/revops:push-to-production --activation plan\|canary\|apply` | release manager + CI |
| production break glass | `/revops:emergency-deploy-to-production --reason "..." --second-admin <other-admin> --ack-url <evidence>` | two-admin Actions-down exception |

The local deploy surface accepts only an explicit per-developer alias. Shared
integration, UAT, and production orgs are CI-owned. The normal production command
dispatches and watches `deploy-prod.yml`; it does not deploy from the laptop.

## Safe sequence

1. Preview the feature-branch delta in the developer's own org.
2. Open the feature → `integration` PR and let required CI validate it.
3. A human squash-merges to `integration`; CI owns the persistent integration deploy.
4. Kells opens and gates the `integration` → `main` promotion.
5. A release manager selects production Flow activation scope and dispatches the CI
   deploy from `main`.
6. Read the exact Actions receipt. The selected activation stage and six-type
   verifier run after a successful deploy, and the summary runs last.
7. Use `/revops:run-manual-post-deploy-steps --production` only for the remainder CI
   cannot automate. It does not activate production Flows.

Metadata deletions leave this sequence: create
`manifest/destructive/BC-<ticket>.xml` and follow the separate release-manager
ceremony in `destructive-deploy.yml`. Never place an auto-executed destructive
manifest at the repository root.

## References

- [SKILL.md](SKILL.md) — routing and operating rules
- [references/deployment-workflows.md](references/deployment-workflows.md) — worked lane examples
- [references/orchestration.md](references/orchestration.md) — dependency and promotion sequence
- [references/trigger-deployment-safety.md](references/trigger-deployment-safety.md) — trigger-specific review gates
- [references/deployment-report-template.md](references/deployment-report-template.md) — evidence handoff

## Requirements

- `sf` CLI v2 for the per-dev command and the documented break-glass path
- authenticated `gh` CLI for production CI dispatch
- a current `brite-salesforce` checkout and an explicit lane decision

## License

MIT License. Adapted from Jaganpro/sf-skills; Brite-specific deployment policy and
orchestration are maintained by Brite Company.
