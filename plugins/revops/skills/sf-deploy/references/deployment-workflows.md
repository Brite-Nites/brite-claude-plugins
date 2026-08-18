<!-- Parent: sf-deploy/SKILL.md -->
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT); Brite lane examples supersede upstream raw-prod recipes. -->

# Salesforce Deployment Workflow Examples

These examples are for `brite-salesforce`. Its promotion topology is binding:

```text
brite-dev-<name> → integration / briteint → main → Brite Prod
```

Only a per-developer org is deployable from a laptop. Normal integration and production deploys are CI-owned. The only local production path is the separately gated `/revops:emergency-deploy-to-production`, and only when the CI lane itself is down.

---

## Example 1: Production deploy with full verification

### User request

```text
"Deploy the Lead trigger and lifecycle-field changes to production."
```

### Execution

1. Confirm the feature PR was squash-merged into `integration`, its required checks passed, and the integration org deploy is green.
2. A release manager opens and merges the deliberate `integration → main` promotion PR under the promotion-window ceremony.
3. From a clean, current local `main`, run:

   ```text
   /revops:push-to-production --activation plan
   ```

   Choose `canary` or `apply` only when the Flow activation is itself an approved behavioral go-live. The command verifies the `main` workflow contract, dispatches `deploy-prod.yml` with all required inputs, and watches the exact returned run URL.

4. Read the CI result. The workflow owns the deploy, Apex tests, selected Flow activation stage, six-type verification, and final summary.
5. Run the non-Flow manual steps explicitly:

   ```text
   /revops:run-manual-post-deploy-steps --production
   ```

Do not reproduce this with a laptop `sf project deploy` command. A local validation is not the reviewed production lane and cannot substitute for the Actions receipt.

---

## Example 2: Inner-loop component deploy

### User request

```text
"Check only the new Lightning Web Components in my dev org."
```

### Execution

Use the orchestrator so the target is resolved and validated, the feature delta is based on `integration`, and the dry-run precedes the deploy:

```text
/revops:preview-changes --target-org brite-dev-<name>
```

The default is branch-diff scope. `--reconcile` opts into the full source tree and should be rare. `main` and every shared/protected alias are refused.

Afterward, run only the relevant manual steps against the same explicit dev org:

```text
/revops:run-manual-post-deploy-steps --target-org brite-dev-<name>
```

---

## Example 3: Named Credential metadata change

### User request

```text
"Ship the Slack_Webform_Alerts Named Credential shape change."
```

### Execution

1. Keep the repository URL field at the required `PLACEHOLDER` sentinel. Never commit the live endpoint or secret-bearing org-issued state.
2. Develop and verify in `brite-dev-<name>` with `/revops:preview-changes`.
3. Submit the source change through `/revops:submit-changes-to-integration`; do not deploy it directly to either shared org.
4. Promote and deploy with `/revops:push-to-production`.
5. Run `/revops:run-manual-post-deploy-steps --production`. Follow the canonical Setup exception for the real environment-specific URL, then verify it is no longer the sentinel.

The `.forceignore` pre-flight runs before dispatch and in CI. Do not improvise a local prod deploy by temporarily changing `.forceignore`.

---

## Example 4: Urgent production fix

### User request

```text
"AccountController is broken and needs an urgent production fix."
```

### Execution

Urgency changes scheduling, not topology:

1. Cut the fix from `integration`.
2. Verify in `brite-dev-<name>`.
3. Open the feature PR into `integration`; obtain the required check and review.
4. Use the promotion-window ceremony for `integration → main`.
5. Dispatch `/revops:push-to-production` from `main`.

Do not deploy one class directly to prod. If GitHub Actions itself is unavailable, the release manager may use `/revops:emergency-deploy-to-production --reason <incident>`; that is break glass, not a faster hotfix lane. Afterward, `/revops:run-manual-post-deploy-steps --production-breakglass` leaves Flow activation blocked for a separate human scope decision.

---

## Example 5: Destructive change

### User request

```text
"Remove DeprecatedClass1, DeprecatedClass2, and CustomObject__c."
```

### Execution

1. Remove the source on a feature branch cut from `integration`.
2. Add one reviewed manifest named after the ticket:

   ```text
   manifest/destructive/BC-<ticket>.xml
   ```

   Enumerate every member; wildcards are refused.

3. Submit the normal PR into `integration`. The merge-triggered lane remains additive and does not execute this file.
4. A release manager dispatches `.github/workflows/destructive-deploy.yml` from `integration` in `validate-only` mode for `briteint`, reads the plan, then performs the gated deploy.
5. After normal promotion, repeat validate-only and the gated ceremony from `main` for prod.

Never commit any of these hardis auto-executed paths:

- `manifest/destructiveChanges.xml`
- `manifest/preDestructiveChanges.xml`
- `config/destructiveChanges.xml`
- `config/preDestructiveChanges.xml`

Committing one is itself an opt-in to deletion in an ordinary lane; CI intentionally trips on all four.

---

## Example 6: Scratch-org PR failure

### User request

```text
"Why did the scratch validation fail on my PR?"
```

### Procedure

1. Read the exact `Dry-run deploy to scratch org` check on the current head.
2. Separate source failures from runner/auth failures; do not rerun blindly.
3. Reproduce only in a scratch org or your `brite-dev-<name>` environment—never prod.
4. Fix the branch, push, and let the required check prove the new head.

Common failure classes:

| Symptom | Likely cause | Response |
|---|---|---|
| scratch creation/auth error | runner, CLI, or Dev Hub surface | inspect setup/auth logs; do not change metadata to create a cosmetic green |
| missing licensed feature | scratch definition/package capability | follow the repository's scratch-preparation allowlist/runbook |
| component dependency failure | incomplete source/manifest dependency | fix the source package on the feature branch |
| only persistent-org lane fails | environment drift or version cap | follow the named runbook; do not bypass protection |

---

## Example 7: Deployment error recovery

### User request

```text
"The integration deploy failed with INVALID_CROSS_REFERENCE_KEY."
```

### Procedure

1. Read the complete failure envelope; a real deploy may report fewer component failures than a dry-run.
2. Reproduce with the branch's dev/scratch validation to enumerate the full set.
3. Locate the missing dependency in the repository.
4. Commit the dependency fix to the same feature branch and let CI re-prove the current head.

Do not patch the shared org in Setup, deploy the dependency directly to it, or narrow the package merely to make the check green. The repo is the source of truth.

---

## Brite deployment rules

1. Cut Salesforce feature branches from `integration`, never `main`.
2. Laptop deploys target only an explicit `brite-dev-<name>` alias.
3. Integration and production use their reviewed CI lanes.
4. Production Flow activation is an explicit `plan|canary|apply` decision; a manual runbook never widens it.
5. Metadata deletion uses only `manifest/destructive/BC-<ticket>.xml` plus the dispatch-only ceremony.
6. A successful deploy is followed by the lane's independent verification; `Status: Succeeded` alone is not completion.
7. Never bypass the required integration check or the promotion window.
