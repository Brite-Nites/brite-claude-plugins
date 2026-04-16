# BC-5579 — Provision "Marketing Claude MCP" Connected App + JWT cert + ECA wrapper

**Linear:** https://linear.app/brite-nites/issue/BC-5579
**Blocks:** BC-5535 Task 3 (availability-check transcript) + final verification
**Transitively unblocks:** BC-2717, BC-2720, BC-2725, BC-2727, BC-2728
**All design decisions:** locked in `docs/research/salesforce-mcp-findings.md` (BC-5534) — zero open questions
**No code lands in this repo** — work spans prod SF org, `brite-salesforce` repo, and Bitwarden. This plan is procedural guidance.

## Readiness (confirmed pre-plan)

- ✅ SF prod admin (System Administrator) — can create Connected App, upload cert, set policies
- ✅ `brite-salesforce` checked out at `/Users/holdenhalford/Projects/work/brite-nites/brite-salesforce` (currently on `holden/bc-5608-fix-remediation-test-fixtures` with WIP — will use worktree so BC-5608 stays untouched)
- ✅ Engineering Bitwarden collection admin — can create item + manage ACLs

## Architecture constraints (from BC-5534 + BC-5535)

- Cert: self-signed X.509, 10-yr validity, `CN=Marketing Claude MCP`, `O=Brite Nites`
- Connected App name: `Marketing Claude MCP` (display) / `Marketing_Claude_MCP` (API)
- OAuth scopes: **`Api` only** — drop `RefreshToken` (explicit divergence from Outbound_Sales_Ops exemplar)
- Policies: `isAdminApproved=true`, `refreshTokenPolicy=ZERO`, `ipRelaxation=ENFORCE`
- Device Flow: disabled
- Credential vault: Engineering Bitwarden collection, item `"Marketing Claude MCP — JWT private key"`
- Verification: `run_soql_query` with `SELECT Id FROM User LIMIT 1` — full round-trip probe (NOT `get_username`)

---

## Phase A — Generate JWT cert (local, ~2 min)

**Where:** local shell, anywhere outside version-controlled dirs (suggest `~/marketing-claude-mcp-cert-provisioning/` — delete after distribution).

**Commands:**

```bash
mkdir -p ~/marketing-claude-mcp-cert-provisioning
cd ~/marketing-claude-mcp-cert-provisioning

# 10-year self-signed X.509, 2048-bit RSA
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout marketing-claude-mcp.key \
  -out marketing-claude-mcp.crt \
  -subj "/CN=Marketing Claude MCP/O=Brite Nites"

chmod 600 marketing-claude-mcp.key

# Show fingerprints for verification at Gate A
openssl x509 -in marketing-claude-mcp.crt -noout -fingerprint -sha256
openssl x509 -in marketing-claude-mcp.crt -noout -dates -subject
```

**Outputs:**
- `marketing-claude-mcp.key` — private half, goes to Bitwarden ONLY. Never commit. Never email.
- `marketing-claude-mcp.crt` — public half, uploaded to SF Connected App in Phase B.

### Gate A — cert inspection

Confirm:
- [ ] Subject is `CN=Marketing Claude MCP, O=Brite Nites`
- [ ] `notAfter` is ~2036
- [ ] `.key` is `chmod 600`
- [ ] `.crt` is readable and in PEM format (starts with `-----BEGIN CERTIFICATE-----`)

Checkpoint with user before proceeding — if fingerprint looks wrong, regenerate.

---

## Phase B — Create Connected App in prod SF Setup UI (~15 min)

**Why Setup UI, not metadata deploy:** Brite's repo-as-source-of-truth policy (from `brite-salesforce/CLAUDE.md`) makes an exception for Connected App creation because the ECA wrapper's `oauthLink` needs the Connected App's record ID, which only exists after creation. The existing `Outbound_Sales_Ops` ECA follows this same pattern (Setup UI creates the app; the repo tracks the OAuth settings wrapper only).

**User does hands-on-keyboard** in the prod SF Setup UI — I provide the checklist.

### Task 2 — New Connected App

1. Setup → **App Manager** → **New Connected App** (choose "Create a Connected App" if prompted).
2. **Basic Information:**
   - Connected App Name: `Marketing Claude MCP`
   - API Name: `Marketing_Claude_MCP` (should auto-derive)
   - Contact Email: your email
3. **API (Enable OAuth Settings):**
   - ☑ Enable OAuth Settings
   - Callback URL: `http://localhost:1717/OauthRedirect` (required field but unused for JWT flow)
   - ☑ Use digital signatures → upload `marketing-claude-mcp.crt` from Phase A
   - ☐ Enable for Device Flow (leave UNCHECKED)
   - Selected OAuth Scopes:
     - ☑ Manage user data via APIs (`api`)
     - ☐ **Do NOT select** `Perform requests at any time` (refresh_token/offline_access) — scope minimization per BC-5534 Q3
4. Save. Wait ~10 min for the app to propagate (Salesforce says "2–10 minutes"; in practice ~2 min but budget 10).

### Task 3 — Set OAuth Policies

1. Setup → **App Manager** → find `Marketing Claude MCP` → drop-down → **Manage**.
2. Click **Edit Policies**:
   - **Permitted Users:** `Admin approved users are pre-authorized` (sets `isAdminApproved=true`)
   - **IP Relaxation:** `Enforce IP restrictions` (sets `ipRelaxation=ENFORCE`)
   - **Refresh Token Policy:** `Immediately expire refresh token` (sets `refreshTokenPolicy=ZERO`) — even though we dropped the scope, this belt-and-suspenders ensures no stale tokens if someone re-adds it
3. Save.

### Task 4 — Record consumer key + Connected App record ID

1. On the `Marketing Claude MCP` Manage page, copy the **Consumer Key** (a.k.a. Client ID — looks like `3MVG9...`). Save it for Phase E (Bitwarden).
2. Get the Connected App's 15-char record ID:
   - On the same Manage page, the URL contains `/lightning/setup/ConnectedApplication/page?address=%2F0CiXXXXXXXXXXXX...` — that `0Ci...` is the 15-char ID.
   - OR run from shell (uses your existing `sf` auth):
     ```bash
     sf data query --target-org brite-prod \
       --query "SELECT Id, Name FROM ConnectedApplication WHERE Name = 'Marketing_Claude_MCP'" \
       --use-tooling-api
     ```
3. Save the 15-char ID. Phase C uses it in `oauthLink`.
4. Get the prod org's 18-char ID (one-time — same for every app, so check if you already know it):
   ```bash
   sf org display --target-org brite-prod --verbose | grep "Org Id"
   ```
   Matches the exemplar's `00Da500001VTpUj` prefix if this is the correct prod org.

### Gate B — Connected App exists, scope is Api-only, policies are set

Verify via screenshot / shell:

- [ ] Connected App `Marketing Claude MCP` visible in App Manager
- [ ] OAuth scopes show `api` ONLY (no `refresh_token` / `offline_access`)
- [ ] Admin-approved, IP-enforced, refresh-token-zero policies applied
- [ ] Consumer key recorded (stash temporarily in `~/marketing-claude-mcp-cert-provisioning/notes.txt`; moves to Bitwarden in Phase E)
- [ ] Connected App record ID recorded

Checkpoint with user before Phase C.

---

## Phase C — Draft + commit ECA wrapper XML (`brite-salesforce`) (~20 min)

### Task 5a — Create worktree (keeps BC-5608 untouched)

```bash
cd /Users/holdenhalford/Projects/work/brite-nites/brite-salesforce
git fetch origin
git worktree add ../brite-salesforce-bc-5579 -b holden/bc-5579-marketing-claude-mcp-eca origin/main
cd ../brite-salesforce-bc-5579
```

### Task 5b — Draft the XML

Create `force-app/main/default/extlClntAppOauthSettings/Marketing_Claude_MCP_oauth.ecaOauth-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ExtlClntAppOauthSettings xmlns="http://soap.sforce.com/2006/04/metadata">
    <commaSeparatedOauthScopes>Api</commaSeparatedOauthScopes>
    <externalClientApplication>Marketing_Claude_MCP</externalClientApplication>
    <isFirstPartyAppEnabled>false</isFirstPartyAppEnabled>
    <label>Marketing_Claude_MCP_oauth</label>
    <oauthLink>{ORG_18_ID}:{CONNECTED_APP_15_ID}</oauthLink>
</ExtlClntAppOauthSettings>
```

Substitute the two IDs from Phase B Task 4. Final `oauthLink` looks like `00Da500001VTpUj:0CiYYYYYYYYYYYY`.

**Divergences from `Outbound_Sales_Ops_oauth.ecaOauth-meta.xml`:**
- `commaSeparatedOauthScopes`: `Api` (not `Api, RefreshToken`) — per BC-5534 Q3 scope minimization
- `externalClientApplication`: `Marketing_Claude_MCP` (not `Outbound_Sales_Ops`)
- `label`: `Marketing_Claude_MCP_oauth`
- `oauthLink`: new Connected App ID

### Task 5c — Dry-run deploy against prod (validation, no changes)

Per `brite-salesforce/CLAUDE.md`: always dry-run before real deploy.

```bash
cd /Users/holdenhalford/Projects/work/brite-nites/brite-salesforce-bc-5579
sf project deploy start \
  --source-dir force-app/main/default/extlClntAppOauthSettings/Marketing_Claude_MCP_oauth.ecaOauth-meta.xml \
  --dry-run \
  --target-org brite-prod
```

Expect: `Status: Succeeded`, 1 component, 0 errors. If the dry-run complains that the Connected App isn't found, the propagation delay from Phase B hasn't finished — wait 5 min and retry.

### Task 5d — Commit + PR

```bash
git add force-app/main/default/extlClntAppOauthSettings/Marketing_Claude_MCP_oauth.ecaOauth-meta.xml
git commit -m "BC-5579: Add Marketing_Claude_MCP ECA wrapper

Mirrors Outbound_Sales_Ops_oauth.ecaOauth-meta.xml pattern with:
- New externalClientApplication name (Marketing_Claude_MCP)
- Api scope only (RefreshToken omitted per BC-5534 Q3 scope minimization)
- New Connected App record ID in oauthLink

Unblocks BC-5535 final verification and 5 downstream marketing skills
(BC-2717, BC-2720, BC-2725, BC-2727, BC-2728)."

git push -u origin holden/bc-5579-marketing-claude-mcp-eca

gh pr create --repo Brite-Nites/brite-salesforce \
  --title "BC-5579: Add Marketing_Claude_MCP ECA wrapper" \
  --body "$(cat <<'EOF'
## Summary

Adds the ExternalClientApplication OAuth wrapper for the net-new
`Marketing Claude MCP` Connected App (created in prod Setup UI in
Phase B of BC-5579). Mirrors the `Outbound_Sales_Ops_oauth` pattern,
with `Api` scope only (drops `RefreshToken` per BC-5534 Q3 scope
minimization — JWT Bearer flow doesn't rely on refresh tokens).

## Test plan
- [x] `sf project deploy start --dry-run --target-org brite-prod` succeeds
- [ ] Post-merge: `sf project deploy start --target-org brite-prod` succeeds
- [ ] Post-deploy: `sf org login jwt` with the new cert succeeds against prod
- [ ] Post-deploy: `run_soql_query` via @salesforce/mcp returns a row

## Links
- Linear: https://linear.app/brite-nites/issue/BC-5579
- Decisions: `britenites-claude-plugins/docs/research/salesforce-mcp-findings.md` (BC-5534)
- Plugin integration guide: `britenites-claude-plugins/plugins/marketing/tools/integrations/salesforce.md` (BC-5535)
EOF
)"
```

### Gate C — PR approved + merged

- [ ] PR opened and linked above
- [ ] Dry-run passed
- [ ] Reviewer approval (ping whoever normally reviews `brite-salesforce` deploys)
- [ ] Merged to `main`

Checkpoint with user. This is the async wait point — the session may pause here if review takes time.

---

## Phase D — Deploy ECA to prod (~5 min)

After PR merges:

```bash
cd /Users/holdenhalford/Projects/work/brite-nites/brite-salesforce
git checkout main
git pull origin main

sf project deploy start \
  --source-dir force-app/main/default/extlClntAppOauthSettings/Marketing_Claude_MCP_oauth.ecaOauth-meta.xml \
  --target-org brite-prod
```

Expect: `Status: Succeeded`, deploy ID recorded.

### Gate D — deploy verified

- [ ] Deploy ID captured
- [ ] Setup UI → ExternalClientApp shows `Marketing_Claude_MCP_oauth` with `Api` scope
- [ ] Worktree removed: `git worktree remove ../brite-salesforce-bc-5579`

---

## Phase E — Bitwarden item + ACLs (~10 min)

### Task 7 — Create item

1. Bitwarden web vault → Engineering collection → **New Item** → type **Secure Note**.
2. **Name:** `Marketing Claude MCP — JWT private key`
3. **Notes field** (copy-paste this template, substitute concrete values):

   ```
   # Marketing Claude MCP — Salesforce JWT auth

   Consumer key (client ID): <paste from Phase B Task 4>
   Service-user email:       <the service user this app authenticates as — pick from existing Salesforce integration users, e.g. same one Outbound Sales Ops uses, or a dedicated one>
   Prod instance URL:        https://<prod-instance>.my.salesforce.com

   ## Onboarding
   See plugins/marketing/tools/integrations/salesforce.md § "One-time per-dev onboarding"
   in britenites-claude-plugins.

   ## Linear / decision trail
   - BC-5579 (admin provisioning, this item)
   - BC-5535 (plugin adoption)
   - BC-5534 (decision memo)

   ## Rotation
   Cert expires ~2036. Rotate ≥6 months before expiry.
   ```

4. **Attachments:** upload `marketing-claude-mcp.key` (private key from Phase A).
5. Save.

### Task 8 — Grant ACLs

Grant **Can edit** (not Can view — editors can download attachments, viewers may be blocked depending on collection config; verify) to:

- Holden Halford (self — should be auto via collection membership)
- Anyone currently assigned to BC-2717, BC-2720, BC-2725, BC-2727, BC-2728

Per Linear, right now that's all Holden. Widen as other devs get assigned.

### Gate E — Bitwarden artifact accessible

- [ ] Item exists in Engineering collection
- [ ] Private-key attachment opens + downloads correctly
- [ ] Notes field populated (consumer key, service-user, instance URL)
- [ ] ACL list matches current assignee roster

---

## Phase F — Verify per-dev onboarding (~10 min)

Treat your local workstation as "a fresh dev" and walk through `plugins/marketing/tools/integrations/salesforce.md` §"One-time per-dev onboarding" verbatim:

1. Confirm `sf` CLI installed (`sf --version`).
2. Download the `.key` attachment from Bitwarden to `~/.sfdx/marketing-claude-mcp.key`, `chmod 600`.
3. Run `sf org login jwt --client-id <consumer-key> --jwt-key-file ~/.sfdx/marketing-claude-mcp.key --username <service-user> --alias marketing-claude-prod --instance-url <instance-url>`. Expect: "Successfully authorized ... with org ID 00Da500001VTpUj".
4. `sf config set target-org marketing-claude-prod` (so `DEFAULT_TARGET_ORG` resolves).
5. `/reload-plugins` in Claude Code.
6. In a fresh turn, ask Claude to call `mcp__plugin_marketing_salesforce__run_soql_query` with `SELECT Id FROM User LIMIT 1`. **Capture the full request + response** — this is the transcript Task 10 needs.

### Gate F — live transcript captured

- [ ] SOQL returns exactly 1 row (or 0 — both prove round-trip; 1 is expected)
- [ ] Transcript shows tool invocation, SOQL text, returned row(s), no auth/token errors
- [ ] Onboarding steps worked end-to-end with only the Bitwarden item as reference (if something was ambiguous, log it as a follow-up to refine `salesforce.md`)

---

## Phase G — Wrap-up + ship

### Task 10 — Comment on BC-5535 with transcript

Post a comment on https://linear.app/brite-nites/issue/BC-5535 containing:

- The raw transcript from Gate F
- One sentence: "BC-5579 provisioned the Connected App + ECA + Bitwarden item. `run_soql_query` against prod succeeds end-to-end. Task 3 + final verification closed."

### Task 11 — Close BC-5579

Move BC-5579 to **Done** with a brief summary comment:

- Cert generated (fingerprint: `<sha256>`)
- Connected App ID: `0Ci...`
- ECA PR: link
- Bitwarden item: `Marketing Claude MCP — JWT private key` in Engineering
- Downstream unblocked: BC-2717/2720/2725/2727/2728

### Gate G — ship

- [ ] Delete local `~/marketing-claude-mcp-cert-provisioning/` directory (cert + notes — now lives only in Bitwarden + SF)
- [ ] Run `/workflows:ship` in this plan's session so compound-learnings + handbook-drift-check + memory update fire
- [ ] If any gotchas surfaced (e.g., onboarding step was ambiguous, dry-run failed for a non-obvious reason, IP restriction blocked first login), capture in `memory/` as feedback or gotcha

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Connected App propagation delay (2–10 min) bites Phase C dry-run | Medium | Wait + retry; documented in Phase C Task 5c |
| Service-user account locked / has IP restrictions → JWT fails despite correct cert | Low | Pre-check: confirm the service user is active, has the `Marketing Claude MCP` app pre-authorized via a permission set. If IP-enforced, ensure workstation is inside allowed range (likely already true for any dev). |
| `.key` leaks via terminal scrollback / shell history | Medium | Use `~/marketing-claude-mcp-cert-provisioning/` then delete post-Bitwarden; never `cat` the key; Bitwarden attachment is the only persistent copy |
| ECA deploy fails with "Connected App not found" | Low | Wait for propagation; confirm Connected App record ID matches `oauthLink` |
| BC-5608 work conflicts with worktree setup | Very Low | Worktree is isolated by design; BC-5608 branch + uncommitted files stay in the primary checkout |
| `DEFAULT_TARGET_ORG` resolves wrong — dev points at sandbox accidentally | Low | Phase F step 4 pins the alias explicitly; `salesforce.md` onboarding calls out that the alias must map to prod |

## Open items (deferred post-ship)

- Whether to add Email Bison's ACL pattern to Bitwarden (BC-5551 twin)
- Whether the 5 downstream skills should share a single `allowed-tools` include or declare per-skill (decision for BC-2717 author)

## Links

- Decisions: `docs/research/salesforce-mcp-findings.md` (BC-5534) — especially Q3 (auth), Q4 (creds), Q5 (toolsets), "Provisioning checklist"
- Plugin adoption: `plugins/marketing/tools/integrations/salesforce.md` (BC-5535)
- Exemplar: `Brite-Nites/brite-salesforce/force-app/main/default/extlClntAppOauthSettings/Outbound_Sales_Ops_oauth.ecaOauth-meta.xml`
- brite-salesforce engineering standards: `brite-salesforce/CLAUDE.md`
