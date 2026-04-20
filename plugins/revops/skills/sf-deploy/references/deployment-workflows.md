<!-- Parent: sf-deploy/SKILL.md -->
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). Examples 1–3 are Brite-specific; 4–8 are upstream, kept as-is. -->

# Salesforce Deployment Workflow Examples

Worked examples for common deploy scenarios. Brite-specific examples lead; generic upstream examples follow.

---

## Example 1 (Brite): Production Deploy with Full Verification

### User Request

```
"Deploy the Lead trigger + Lifecycle field changes to production"
```

### Execution

1. **Dry-run validation**

   ```bash
   sf project deploy start \
     --source-dir force-app \
     --dry-run \
     --target-org brite-prod \
     --test-level RunLocalTests \
     --wait 30 --json
   ```

   Confirm: all components pass, tests pass, org-wide coverage ≥90% (the Brite target — the SF 75% minimum is a floor, not a target).

2. **Quick deploy** (reuses the validation job, skips re-running tests)

   ```bash
   sf project deploy quick --job-id <validation-job-id> --target-org brite-prod --json
   ```

3. **Tooling API SOQL verification** — independent confirmation that critical components landed.

   ```bash
   # Trigger exists + status
   sf data query --use-tooling-api \
     --query "SELECT Name, Status FROM ApexTrigger WHERE Name = 'LeadTrigger'" \
     --target-org brite-prod

   # Custom field exists
   sf data query --use-tooling-api \
     --query "SELECT DeveloperName, TableEnumOrId FROM CustomField WHERE TableEnumOrId = 'Lead' AND DeveloperName = 'Lifecycle_Stage__c'" \
     --target-org brite-prod
   ```

4. **Manual post-deploy steps** — none for this deploy (no Flow, no Named Credential, no Scheduled Apex, no ECA).

5. **Report**

   ```text
   Deployment goal: deploy
   Target org: brite-prod
   Scope: source-dir force-app (filtered by .forceignore)
   Result: passed
   Apex coverage: 92.3% org-wide
   Tooling API verification: LeadTrigger Active, Lead.Lifecycle_Stage__c present
   Next step: monitor Apex Jobs for Queueable retry signatures over the next hour
   ```

---

## Example 2 (Brite): Named Credential URL Change via `.forceignore` Toggle

### User Request

```
"Update the Slack_Webform_Alerts Named Credential URL in production"
```

### Execution

`NamedCredential` is excluded from ongoing `--source-dir` deploys in Brite's `.forceignore` — metadata deploys would otherwise silently push the PLACEHOLDER URL over a working one. To deploy a NC shape or URL change, toggle the exclusion off for this deploy only.

1. **Comment out the `.forceignore` line**

   ```bash
   # Edit .forceignore — comment (don't delete) the NamedCredential line
   # -namedCredentials/**
   # +# namedCredentials/**   # RE-ENABLE AFTER THIS DEPLOY
   ```

2. **Dry-run with the exclusion removed**

   ```bash
   sf project deploy start \
     --source-dir force-app/main/default/namedCredentials \
     --dry-run \
     --target-org brite-prod --wait 30 --json
   ```

   Confirm only the intended Named Credential appears in the plan.

3. **Deploy**

   ```bash
   sf project deploy start \
     --source-dir force-app/main/default/namedCredentials \
     --target-org brite-prod --wait 30 --json
   ```

4. **Update the URL manually in the target org** — Setup → Named Credentials → `Slack_Webform_Alerts` → replace PLACEHOLDER with the real webhook URL.

5. **Verify via Tooling API**

   ```bash
   sf data query --use-tooling-api \
     --query "SELECT DeveloperName, Endpoint FROM NamedCredential WHERE DeveloperName = 'Slack_Webform_Alerts'" \
     --target-org brite-prod
   ```

   Endpoint should be the real URL, not PLACEHOLDER.

6. **Restore `.forceignore`** — uncomment the `namedCredentials/**` line. Commit this restore step in the same PR as the NC change.

7. **Smoke test** — trigger a Web-to-Lead form and confirm the Slack alert fires. Watch Apex Jobs for the 1-original + 3-silent-retry signature; if you see it, the URL is still wrong.

---

## Example 3 (Brite): Scratch-Org-per-PR CI Validation

### User Request

```
"Why did the CI scratch-org validation fail on my PR?"
```

### Context

Brite's CI uses a scratch org per PR, not a shared sandbox. The pipeline:

1. Authenticates Dev Hub via `SFDX_AUTH_URL_DEVHUB` (refresh token from the shared `marketingadmin@britenites.com` service user, stored as a GitHub Actions secret).
2. Runs `./scripts/prepare-scratch-deploy.sh` to append `.forceignore.scratch` and strip scratch-incompatible profile entries.
3. Creates the scratch from `config/project-scratch-def.json`.
4. Dry-runs the deploy.
5. Destroys the scratch.

Typical runtime: ~2.5 min validate + 33s lint.

### Common failure modes

| Symptom | Root cause | Fix |
|---|---|---|
| `invalid assertion` during `sf org create scratch` | CLI older than `2.130.x` | CI already pins `@salesforce/cli@2`; upgrade locally with `npm install -g @salesforce/cli@latest` |
| `FieldService:10` feature missing | FSL managed extension package not installed in scratch | FSL metadata is in `.forceignore.scratch`; see `docs/plans/BC-5424-path-a.md` if full FSL CI is required |
| Profile deploy fails on standard app | Scratch-incompatible `standard__*` app references in `Minimum Access` profile | `prepare-scratch-deploy.sh` strips these via perl regex; verify `SCRATCH_IGNORED_LAYOUT_PATTERN` covers the failing prefix |
| `.forceignore` drift after local run | Developer forgot to `git checkout .forceignore` after running `prepare-scratch-deploy.sh` locally | Never commit a merged `.forceignore` — restore before committing |

Full architecture: brite-salesforce/`docs/ci-architecture.md`. Scratch preprocessing: brite-salesforce/`scripts/prepare-scratch-deploy.sh`.

---

## Example 4: Selective Component Deployment

### User Request

```
"Deploy only the new Lightning Web Components to sandbox"
```

### Execution

1. **Identify LWC components**
   ```bash
   ls -R force-app/main/default/lwc/
   ```

2. **Deploy specific directory**
   ```bash
   sf project deploy start \
     --source-dir force-app/main/default/lwc \
     --target-org brite-sandbox \
     --test-level NoTestRun \
     --wait 15
   ```

3. **Output**
   ```
   ✓ Deployment succeeded
   ✓ Components Deployed:
     - accountCard (LWC)
     - contactList (LWC)
     - opportunityBoard (LWC)
   ```

---

## Example 5: Hotfix Deployment

### User Request

```
"I need to deploy an urgent bug fix in AccountController to production"
```

### Execution

1. **Verify the specific file**
   ```bash
   cat force-app/main/default/classes/AccountController.cls
   ```

2. **Run targeted tests**
   ```bash
   sf apex run test \
     --tests AccountControllerTest \
     --target-org brite-prod \
     --wait 5
   ```

3. **Deploy single class**
   ```bash
   sf project deploy start \
     --source-dir force-app/main/default/classes/AccountController.cls \
     --target-org brite-prod \
     --test-level RunSpecifiedTests \
     --tests AccountControllerTest \
     --wait 10
   ```

4. **Verify**
   ```bash
   sf project deploy report --job-id <job-id> --target-org brite-prod
   ```

5. **Tooling API sanity check** (Brite addition — confirm the new body actually landed)
   ```bash
   sf data query --use-tooling-api \
     --query "SELECT Body FROM ApexClass WHERE Name = 'AccountController'" \
     --target-org brite-prod
   ```

---

## Example 6: Manifest-Based Deployment

### User Request

```
"Deploy using the package.xml manifest for release v2.3"
```

### Execution

1. **Read manifest file**
   ```bash
   cat manifest/package-v2.3.xml
   ```

2. **Validate deployment**
   ```bash
   sf project deploy start \
     --manifest manifest/package-v2.3.xml \
     --target-org brite-prod \
     --dry-run \
     --test-level RunLocalTests \
     --wait 30
   ```

3. **Quick deploy**
   ```bash
   sf project deploy quick --job-id <validation-job-id> --target-org brite-prod
   ```

---

## Example 7: Destructive Changes

### User Request

```
"Remove the deprecated CustomObject__c and old Apex classes"
```

### Execution

1. **Create destructiveChanges.xml**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <Package xmlns="http://soap.sforce.com/2006/04/metadata">
       <types>
           <members>DeprecatedClass1</members>
           <members>DeprecatedClass2</members>
           <name>ApexClass</name>
       </types>
       <types>
           <members>CustomObject__c</members>
           <name>CustomObject</name>
       </types>
       <version>65.0</version>
   </Package>
   ```

2. **Deploy with destructive changes**
   ```bash
   sf project deploy start \
     --manifest manifest/package.xml \
     --post-destructive-changes manifest/destructiveChanges.xml \
     --target-org brite-prod \
     --test-level RunLocalTests \
     --wait 30
   ```

   > Current SF CLI releases support combining manifest deploy + destructive changes in a single operation.

---

## Example 8: Deployment Error Recovery

### User Request

```
"Deployment failed with 'INVALID_CROSS_REFERENCE_KEY' error"
```

### Execution

1. **Analyze error**
   ```
   Error: INVALID_CROSS_REFERENCE_KEY
   Component: CustomObject__c.SomeLookupField__c
   Message: Field references non-existent object
   ```

2. **Identify dependency**
   ```bash
   grep -r "ReferencedObject__c" force-app/
   ```

3. **Solution**

   The error indicates that `SomeLookupField__c` references an object that doesn't exist in the target org.

   Options:
   1. Deploy the referenced object first.
   2. Include both objects in the same deployment.
   3. Update the field to reference a different object.
   4. Check whether the referenced object exists: `sf org list metadata --metadata-type CustomObject --target-org <alias>`.

4. **Deploy with dependencies**
   ```bash
   sf project deploy start \
     --manifest manifest/package-with-dependencies.xml \
     --target-org brite-prod
   ```

---

## Deployment Tips (Brite)

1. **Always dry-run first** — both sandbox and production.
2. **Watch test execution** — fail fast, don't wait for the deploy to bubble failures.
3. **Target 90%+ org-wide coverage** on any prod deploy touching Apex.
4. **Deploy incrementally** — smaller scopes are easier to triage.
5. **Never test directly in production** — everything goes through sandbox or scratch first.
6. **SOQL-verify prod deploys via Tooling API** — "Succeeded" isn't enough.
7. **Respect `.forceignore`** — toggle off only for the specific deploy that needs the excluded type; restore before committing.
8. **Re-check Screen Flow status** after any deploy that includes a Flow.

---

*These examples cover the most common deploy scenarios. The `sf-deploy` skill adapts to specific cases and guides through edge conditions.*
