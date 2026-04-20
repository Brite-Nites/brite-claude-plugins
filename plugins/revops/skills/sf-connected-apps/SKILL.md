---
name: sf-connected-apps
description: Salesforce Connected Apps and OAuth configuration with 120-point scoring. TRIGGER when: user configures OAuth flows, JWT bearer auth, Connected Apps, or touches .connectedApp-meta.xml / .eca-meta.xml files. DO NOT TRIGGER when: Named Credentials for callouts (use sf-integration), permission policies (use sf-permissions), or API endpoint code (use sf-apex).
user-invocable: false
license: MIT
allowed-tools: Bash Read Write Edit Glob Grep WebFetch AskUserQuestion TodoWrite
metadata:
  version: "1.1.0-brite.1"
  author: "Jag Valaiyapathy"
  scoring: "120 points across 6 categories"
---

<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->

# sf-connected-apps: Salesforce Connected Apps & External Client Apps

Use this skill when the user needs **OAuth app configuration** in Salesforce: Connected Apps, External Client Apps (ECAs), JWT bearer setup, PKCE decisions, scope design, or migration from older Connected App patterns to newer ECA patterns.

## Brite Context

Brite's integration auth landscape is **ECA-based, not classic ConnectedApp**. Classic `ConnectedApp` creation is blocked org-wide since Spring '26, so every net-new OAuth app must be an `ExternalClientApplication`. Four ECAs are live today; each has a distinct use case and scope posture:

- **`Marketing_Claude_MCP`** — plugin-side MCP runtime access. JWT bearer flow. Scopes `Api` + `RefreshToken`. `refreshTokenPolicy: ZERO`. Private key in the Engineering Bitwarden collection.
- **`Outbound_Sales_Ops`** — outbound automation runtime (JWT bearer, dedicated service user).
- **`CI_Deploy`** — GitHub Actions metadata deploys. SFDX refresh-token flow (long-lived creds needed in CI).
- **`OutboundSync`** — webhook relay from Email Bison into Salesforce.

Credential home: **Engineering Bitwarden collection**. JWT private keys named `<ECAName> — JWT private key`; consumer secrets named `<ECAName> — consumer secret`. Per-user distribution is out-of-band.

**CI ≠ runtime auth.** `CI_Deploy` uses refresh-token for long-lived pipeline credentials; `Marketing_Claude_MCP` uses JWT for short-lived, cert-gated tokens. Don't cross-wire — it breaks blast-radius isolation.

## Brite ECA Conventions

These rules bind any sf-connected-apps work done in a Brite repo. Violations are review blockers.

1. **Always prefer `ExternalClientApplication` for new OAuth apps.** Classic `ConnectedApp` creation is disabled org-wide since Spring '26. Even for "just a single-org app," use the ECA metadata type. Upstream table recommending Connected App for "simple single-org OAuth" does not apply at Brite.

2. **JWT flow requires BOTH `Api` and `RefreshToken` scopes.** The SFDX CLI auth layer needs `RefreshToken` to complete `sf org login jwt`, even though pure JWT token exchange does not require it. Dropping `RefreshToken` breaks CLI auth. Source: `docs/research/salesforce-mcp-findings.md` Q3.

3. **Set `refreshTokenPolicy: ZERO` on ECA OAuth policies.** Belt-and-suspenders: prevents long-lived refresh tokens even if a client mis-requests them. Applied to `Marketing_Claude_MCP`; default for new ECAs unless a flow provably needs persistence.

4. **Exclude `ExtlClntAppOauthSettings` via `.forceignore` for sandbox deploys.** The file embeds an org-specific `oauthLink` (`OrgId:ConsumerRecordId`) that does not resolve cross-org. Excluded alongside `ExternalClientApplication` type for sandbox work. Temporarily comment out those exclusions when deploying to production.

5. **JWT-from-ECA breaks `sf org create scratch`.** Upstream bugs: `forcedotcom/cli#3025`, `forcedotcom/cli#3482`. `sf org create scratch` rejects JWT sessions authenticated against ECAs. Workaround: authenticate via `SFDX_AUTH_URL` through the CLI's built-in PlatformCLI Connected App for scratch-org provisioning. Runtime MCP calls are unaffected.

6. **Separate CI auth from runtime auth.** `CI_Deploy` (refresh-token) is for long-lived GitHub Actions deploys; `Marketing_Claude_MCP` (JWT) is for short-lived MCP sessions. Do not point CI at a JWT ECA or MCP at a refresh-token ECA — the blast-radius story depends on the split.

7. **All ECA secrets live in Engineering Bitwarden, never in source.** JWT private keys and consumer secrets are stored in the Engineering Bitwarden collection with names `<ECAName> — JWT private key` and `<ECAName> — consumer secret`. Per-user distribution is out-of-band. Never commit, never echo to logs, never put in env templates with real values.

## When This Skill Owns the Task

Use `sf-connected-apps` when the work involves:
- `.connectedApp-meta.xml` or `.eca-meta.xml` files
- OAuth flow selection and callback / scope setup
- JWT bearer auth, device flow, client credentials, or auth-code decisions
- Connected App vs External Client App architecture choices
- consumer-key / secret / certificate handling strategy

Delegate elsewhere when the user is:
- configuring Named Credentials or runtime callouts → [sf-integration](../sf-integration/SKILL.md)
- analyzing access / permission policy assignments → [sf-permissions](../sf-permissions/SKILL.md)
- writing Apex token-handling code → [sf-apex](../sf-apex/SKILL.md)
- deploying metadata to orgs → [sf-deploy](../sf-deploy/SKILL.md)

---

## First Decision: Connected App or External Client App

| If the need is... | Prefer |
|---|---|
| simple single-org OAuth app | Connected App |
| new development with better secret handling | External Client App |
| multi-org / packaging / stronger operational controls | External Client App |
| straightforward legacy compatibility | Connected App |

Default guidance:
- choose **ECA** for new regulated, packageable, or automation-heavy solutions
- choose **Connected App** when simplicity and legacy compatibility matter more
- Spring ’26 note: creation of new Connected Apps is disabled by default in orgs. For new integrations, prefer External Client Apps unless Connected App compatibility is explicitly required.

---

## Required Context to Gather First

Ask for or infer:
- app type: Connected App or ECA
- OAuth flow: auth code, PKCE, JWT bearer, device, client credentials
- client type: confidential vs public
- callback URLs / redirect surfaces
- required scopes
- distribution model: local org only vs packageable / multi-org
- whether certificates or secret rotation are required

---

## Recommended Workflow

### 1. Choose the app model
Decide whether a Connected App or ECA is the better long-term fit.

### 2. Choose the OAuth flow
| Use case | Default flow |
|---|---|
| backend web app | Authorization Code |
| SPA / mobile / public client | Authorization Code + PKCE |
| server-to-server / CI/CD | JWT Bearer |
| device / CLI auth | Device Flow |
| service account style app | Client Credentials (typically ECA) |

### 3. Start from the right template
Use the provided assets instead of building from scratch:
- `assets/connected-app-basic.xml`
- `assets/connected-app-oauth.xml`
- `assets/connected-app-jwt.xml`
- `assets/external-client-app.xml`
- `assets/eca-global-oauth.xml`
- `assets/eca-oauth-settings.xml`
- `assets/eca-policies.xml`

If you need source-controlled ECA OAuth security metadata, retrieve it from an org first and treat the retrieved file as the schema source of truth:
- `sf project retrieve start --metadata ExtlClntAppOauthSecuritySettings:<AppName> --target-org <alias>`

### 4. Apply security hardening
Favor:
- least-privilege scopes
- explicit callback URLs
- PKCE for public clients
- certificate-based auth where appropriate
- rotation-ready secret / key handling
- IP restrictions when realistic and maintainable

### 5. Validate deployment readiness
Before handoff, confirm:
- metadata file naming is correct
- scopes are justified
- callback and auth model match the real client type
- secrets are not embedded in source

---

## High-Signal Security Rules

Avoid these anti-patterns:

| Anti-pattern | Why it fails |
|---|---|
| wildcard / overly broad callback URLs | token interception risk |
| `Full` scope by default | unnecessary privilege |
| PKCE disabled for public clients | code interception risk |
| consumer secret committed to source | credential exposure |
| no rotation / cert strategy for automation | brittle long-term ops |

Default fix direction:
- narrow scopes
- constrain callbacks
- enable PKCE for public clients
- keep secrets outside version control
- use JWT certificates or controlled secret storage where appropriate

---

## Metadata Notes That Matter

### Connected App
Usually lives under:
- `force-app/main/default/connectedApps/`

### External Client App
Current source-supported ECA metadata uses multiple top-level source directories, not a single `externalClientApps/` folder:
- `force-app/main/default/externalClientApps/` → `ExternalClientApplication` (`.eca-meta.xml`)
- `force-app/main/default/extlClntAppGlobalOauthSets/` → `ExtlClntAppGlobalOauthSettings` (`.ecaGlblOauth-meta.xml`)
- `force-app/main/default/extlClntAppOauthSettings/` → `ExtlClntAppOauthSettings` (`.ecaOauth-meta.xml`)
- `force-app/main/default/extlClntAppOauthSecuritySettings/` → `ExtlClntAppOauthSecuritySettings` (`.ecaOauthSecurity-meta.xml`)
- `force-app/main/default/extlClntAppOauthPolicies/` → `ExtlClntAppOauthConfigurablePolicies` (`.ecaOauthPlcy-meta.xml`)
- `force-app/main/default/extlClntAppPolicies/` → `ExtlClntAppConfigurablePolicies` (`.ecaPlcy-meta.xml`)

Important file-name gotchas:
- the global OAuth suffix is `.ecaGlblOauth`, not `.ecaGlobalOauth`
- the general policy suffix is `.ecaPlcy`, not `.ecaPolicy`
- use `.ecaOauthSecurity` for `ExtlClntAppOauthSecuritySettings`

---

## Output Format

When finishing, report in this order:
1. **App type chosen**
2. **OAuth flow chosen**
3. **Files created or updated**
4. **Security decisions**
5. **Next deployment / testing step**

Suggested shape:

```text
App: <name>
Type: Connected App | External Client App
Flow: <oauth flow>
Files: <paths>
Security: <scopes, PKCE, certs, secrets, IP policy>
Next step: <deploy, retrieve consumer key, or test auth flow>
```

---

## Cross-Skill Integration

| Need | Delegate to | Reason |
|---|---|---|
| Named Credential / callout runtime config | [sf-integration](../sf-integration/SKILL.md) | runtime integration setup |
| deploy app metadata | [sf-deploy](../sf-deploy/SKILL.md) | org validation and deployment |
| Apex token or refresh handling | [sf-apex](../sf-apex/SKILL.md) | implementation logic |
| permission review after deployment | [sf-permissions](../sf-permissions/SKILL.md) | access governance |

---

## Reference Map

### Start here
- [references/oauth-flows-reference.md](references/oauth-flows-reference.md)
- [references/security-checklist.md](references/security-checklist.md)
- [references/testing-validation-guide.md](references/testing-validation-guide.md)

### Migration / examples
- [references/migration-guide.md](references/migration-guide.md)
- [references/example-usage.md](references/example-usage.md)
- [assets/](assets/)

---

## Score Guide

| Score | Meaning |
|---|---|
| 80+ | production-ready OAuth app config |
| 54–79 | workable but needs hardening review |
| < 54 | block deployment until fixed |
