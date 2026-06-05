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
The two Salesforce **org aliases** revops commands target. `brite-sandbox` is the deploy/validation target; `brite-prod` is production. Commands always pass `--target-org` explicitly — never the CLI default org. Under the promotion topology, `brite-sandbox` is being renamed **`brite-integration`** (its role becomes the CI-deployed Integration org) — see **Integration (org)**.
_Avoid_: "the org", "default org" (revops never relies on an implicit default).

**Integration (org)**:
The CI-deployed persistent org at the first stage of the promotion topology — the shared target the pipeline rebuilds from `main` on merge, replacing the manual shared-sandbox model. In Phase 1 this is the `bndev` org repurposed; its alias migrates `brite-sandbox` → `brite-integration` ([ADR-022](docs/decisions/022-revops-promotion-topology.md); bn-salesforce ADR-016).
_Avoid_: "the sandbox" — ambiguous now that Integration, UAT, and per-dev orgs are all sandboxes.

**promotion · push · deploy** (keep distinct):
**promotion** = advancing a change up the environment chain (e.g. integration → uat → prod); the order is the topology's invariant. **push** (as in `push-to-production`) = the human command that *triggers* a prod promotion — CI performs the actual deploy. **deploy** = the machine action CI runs. The human promotes/pushes; CI deploys.
_Avoid_: calling the human action "deploy" — under the CI-driven topology the human no longer deploys.

**emergency path**:
The sanctioned break-from-normal route to production (`emergency-deploy-to-production`) — re-triggers the *enforced* CI deploy rather than bypassing it.
_Avoid_: "break-glass" (jargon/idiom — superseded; see the naming convention in [CONTRIBUTING.md](CONTRIBUTING.md)).

**config-gated guardrail**:
A revops guidance/guard mechanism (status line, advisory nudge, pre-flight) that reads a repo-local pipeline config and stays silent where it is absent — so the portable `revops` plugin carries the *capability* while a repo's config *activates* it ([ADR-022](docs/decisions/022-revops-promotion-topology.md)).
_Avoid_: hardcoding brite-salesforce branch names into revops — that breaks portability ([ADR-007](docs/decisions/007-revops-plugin-design.md) §3.1).
