# Brite Claude Plugins

Brite's Claude Code plugin monorepo — process, org, and domain plugins under `plugins/`. This glossary fixes the vocabulary for concepts that recur across plugins and are easy to conflate. It is a glossary only: no implementation detail, no architecture — those live in `docs/decisions/` (ADRs).

## Language

### Salesforce / RevOps

**revops**:
The Salesforce **engineering** layer — a portable plugin bundling SF dev knowledge (skills), deploy discipline (commands), and the org MCP, usable from any repo. Its charter is concerns 1–2 only: SF knowledge + deploy/ops discipline. The CRM-write surface it also hosts (`create-sf-campaign`, `update-sf-campaign-status`) is a **GTM seam owned by `marketing`**, implemented here as commands per [ADR-015](docs/decisions/015-gtm-sigma3-sf-campaign-sync.md) — not part of revops's core identity.
_Avoid_: "the Salesforce plugin" (revops scopes to the revenue-ops function, not one tool — [ADR-007](docs/decisions/007-revops-plugin-design.md) §3.1); "RevOps seat" (was the withdrawn `revenue-rhythm` L10 plugin, not this).

**brite-salesforce**:
Brite's live Salesforce DX (SFDX) metadata **repository** (`github.com/Brite-Nites/brite-salesforce`) — the thing deploys actually ship to. Its own `CLAUDE.md` is the authoritative source for Brite deploy discipline; `revops` mirrors that discipline outward so agents in other repos inherit it. Authority is one-way: brite-salesforce defines, revops reflects.
_Avoid_: "bn-salesforce" (only a local clone's folder name); "the SF repo".

**brite-sandbox / brite-prod**:
The two Salesforce **org aliases** revops commands target. `brite-sandbox` is the deploy/validation target; `brite-prod` is production. Commands always pass `--target-org` explicitly — never the CLI default org.
_Avoid_: "the org", "default org" (revops never relies on an implicit default).
