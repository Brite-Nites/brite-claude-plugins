<!-- Parent: sf-deploy/SKILL.md -->

# Brite deployment orchestration

Use this reference when a change spans metadata dependencies or more than one
promotion lane. `brite-salesforce` owns the policy; this plugin only routes into its
reviewed commands.

## One promotion topology

```text
feature branch from integration
  → /revops:preview-changes in brite-dev-<name>
  → feature → integration PR
  → human squash merge; CI deploys briteint
  → Kells-gated integration → main PR
  → human merge commit to main
  → /revops:push-to-production from main
  → deploy-prod.yml deploy → activation → verification → summary
```

The laptop lane ends at the developer's own org. Integration, UAT, and production are
CI-owned. A local validation, quick deploy, or generic target alias cannot replace a
promotion hop.

## Authoring dependencies

Prepare source in this order when the metadata requires it:

1. objects and fields
2. permission sets and profiles
3. Apex classes and triggers
4. Flows
5. activation policy and post-deploy evidence

This is a dependency order, not permission to deploy each group separately. The
selected lane decides how the complete reviewed change moves.

## Lane procedures

### Per-developer inner loop

Run:

```text
/revops:preview-changes --target-org brite-dev-<name>
```

The command resolves only an explicit per-dev alias, blocks on deployment concurrency,
dry-runs the branch delta, deploys the same recomputed scope, runs applicable tests,
and hands browser verification to the human. `--reconcile` widens source scope but
does not widen the allowed branch or target org.

Completion: the exact branch delta is proven in the named dev org, and no deletion is
hidden in the normal deploy path.

### Integration

Run:

```text
/revops:submit-changes-to-integration
```

The command opens a PR to `integration`. Required checks and a human review gate the
squash merge; CI owns the persistent `briteint` deploy. A developer never substitutes
a local deploy to `briteint`.

Completion: the PR has current required evidence and a human decides the merge.

### Production

After the Kells-gated promotion has merged into `main`, run:

```text
/revops:push-to-production --activation plan|canary|apply
```

The command proves local and remote `main` agree, validates the workflow's exact input
schema, records the selected activation scope, double-confirms, dispatches the exact
CI workflow, and watches the returned run URL. The workflow owns the deploy, Apex gate,
selected activation stage, six-type verification, and final summary.

Completion: the exact Actions receipt is green. `plan` is read-only; `canary` and
`apply` are separate release-manager decisions. A Draft Flow is not permission for a
manual production activation.

### Break glass

`/revops:emergency-deploy-to-production --reason "..." --second-admin <other-admin> --ack-url <evidence>` is the only local production
path and exists solely for an Actions-down incident. It retains the production guards,
records the exception, and leaves Flow activation blocked for a separate decision.

Completion: the exception record and verification receipt exist. Break glass is never
used to save time or bypass a red gate.

## Deletions

Any metadata deletion stops the ordinary deploy path:

1. create `manifest/destructive/BC-<ticket>.xml`
2. review the exact members and dependency impact
3. use `.github/workflows/destructive-deploy.yml` in `validate-only` mode
4. let the release manager perform the separately gated deploy

The repository tripwire rejects root or auto-executed destructive manifests.

## Post-deploy ownership

| Concern | Owner |
|---|---|
| Flow activation in production | selected `plan|canary|apply` CI stage |
| six-type component verification | `deploy-prod.yml` |
| Named Credential org-issued URL | explicit manual production runbook |
| Scheduled Apex recovery | explicit manual production runbook |
| UI cache/browser verification | human sensor |
| test data | `sf-data`, only after the metadata lane is complete |

Return to the parent skill's Reference Map for worked examples and the final evidence
handoff template. References stay one level deep so an agent never has to chase a
second document from this one.
