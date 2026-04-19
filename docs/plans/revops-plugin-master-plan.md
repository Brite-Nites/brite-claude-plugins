# RevOps Plugin — Master Plan

**Created:** 2026-04-19
**Author:** Holden Halford (session-driven)
**Status:** Decisions locked; issues being filed
**Linear project:** Brite Plugin Marketplace
**Linear milestone:** RevOps Plugin
**Related (already filed):** BC-5780 (marketing setup-email-bison fix), BC-5781 (proactive marketing onboarding)

## Locked Decisions (2026-04-19)

1. **Plugin name:** `revops`
2. **Subtree prefix:** `plugins/revops/` (flat — subtree IS the plugin)
3. **Skill renaming timing:** deferred to per-skill Phase 3 issues; Issue 1.2 only imports + filters
4. **Phase 3 granularity:** 13 issues, one per kept skill (no batching)
5. **sf-diagram-mermaid:** deferred — no customization issue right now
6. **Phase 4 scope:** 4.1 SessionStart banner only; 4.2 sfdx warner deferred pending post-Phase-1 check; 4.3 XML validator cut
7. **Issue filing strategy:** file all 23 at once under new RevOps Plugin milestone

---

## 1. Executive Summary

Build a new `plugins/revops/` Claude Code plugin that gives every Brite engineer rich Salesforce intelligence (skills + agents + hooks + orchestration commands + MCP) whenever they touch an SF-adjacent repo, most importantly `brite-salesforce`. The plugin adopts `Jaganpro/sf-skills` (CTA-authored, MIT-licensed, 36 skills + 7 agents + LSP loops + scoring rubrics) via `git subtree` as our own code going forward, then Brite-customizes the subset that matters (~15 skills) against conventions from `brite-salesforce/CLAUDE.md`.

**Design principle:** augment `workflows:*`, don't replace it. `workflows:session-start` → `workflows:review` → `workflows:ship` orchestrate the same way for SF work as any other domain. RevOps adds (a) auto-activating skills that inject SF knowledge during each phase and (b) 3 new `/revops:*` commands for deploy orchestration that `workflows` doesn't cover.

**Current gap being closed:** shipping SF changes via `workflows:*` alone misses dry-run discipline, FLS sync across 7 permsets, Scheduled Apex re-schedule, Screen Flow activation, post-deploy Tooling API verification, Named Credential placeholder management, and 40+ other SF gotchas documented in `brite-salesforce/CLAUDE.md`. Today Holden feels this gap on every SF ship.

---

## 2. Research Findings (Summary)

### 2.1 Salesforce Headless 360 announcement (TDX 2026, 2026-04-15)
- **"60+ new MCP tools + 30+ preconfigured skills" announced but NOT yet shipped.** Latest public `@salesforce/mcp` is 0.30.5 (2026-04-03), predates TDX by 12 days. Expect landing late April / May 2026 via Wednesday stable cadence.
- **ZERO Claude-Code-native skills shipped by Salesforce themselves.** Their strategy is MCP-first + client-agnostic; each IDE wraps tools with its own prompt layer. No installable `.claude-plugin/` anywhere in the `salesforcecli` org (73 repos surveyed).
- Govindarjan (SF EVP) hedged: *"To be very honest, not at all sure MCP will remain the standard… CLI is just as good, if not better."* Salesforce is deliberately multi-surface (API + CLI + MCP).
- **Relevant to Brite:** monitor `@salesforce/mcp` for 0.31+ Data 360 exposure and new toolsets; don't pre-adopt.
- **Not relevant:** Agent Script DSL, AXL, Testing Center, A/B Testing, DevOps Center MCP, Agent Fabric, Agentforce Vibes 2.0 — all for agents that live inside Agentforce runtime (a runtime model Brite doesn't use).

### 2.2 @salesforce/mcp deep-dive (0.30.5 source code)
- 8 flags supported; we currently use only `--orgs` + `--toolsets`. **Missing:** `--no-telemetry` (telemetry is ON by default, sends toolset names + sanitized org sentinel + lifecycle events).
- `--tools` flag supports cherry-picking individual tools across toolsets (e.g., `--toolsets data --tools assign_permission_set`) — pattern underdocumented in our `salesforce.md`.
- **Hidden trap:** every data/metadata tool requires a `directory` parameter pointing at a real SFDX project path. Our marketing plugin's planned consumer skills (BC-2717/2720/2725/2727/2728) will fail from non-SFDX cwds until we solve this.
- No server-side read-only mode; blast radius is entirely controlled by the SF service user's permission sets. Gap: we haven't audited what `Marketing_Claude_MCP` ECA's service user can actually do.

### 2.3 Jaganpro/sf-skills evaluation
- **36 skills + 7 agents + hooks + LSP auto-fix loops (Apex + LWC + Agent Script) + 90/110/165-pt scoring rubrics.**
- MIT license, pushed 2026-04-10, 357 stars, CTA author, actively maintained.
- Installs via curl to `~/.claude/` (Claude Code) or via `npx skills add` (other IDEs).
- **Brite-relevance breakdown:**
  - **Keep ~13-15 skills:** Development (sf-apex, sf-flow, sf-lwc, sf-soql), Quality (sf-testing, sf-debug), Foundation (sf-metadata, sf-data, sf-docs, sf-permissions), Integration (sf-connected-apps, sf-integration), DevOps (sf-deploy, sf-diagram-mermaid).
  - **Skip 21 skills:** 7 Data Cloud family (needs external runtime), 5 Agentforce AI (we don't license Agentforce), 7 Industries/Vlocity (telecom/energy vertical, irrelevant), 1 Flex Estimator (Agentforce pricing), 1 nanobananapro diagram (overkill).
  - **Skip all 7 agents:** they're Salesforce consulting personas (FDE = Forward Deployed Engineer, PS = Professional Services Architect). Brite is a product company, not a SF consultancy. Build Brite-specific agents later if needed.
- **Primary focus:** development workflows (Apex, LWC, metadata, deploy, test, debug) — NOT end-user SF data consumption.

### 2.4 brite-salesforce context
- SFDX source format, API v65.0, Apex-first automation, 100% class coverage target, LWC Jest, pre-commit hooks.
- 11 customized objects, 4 ECAs (Marketing_Claude_MCP, Outbound_Sales_Ops, CI_Deploy, OutboundSync), scratch-org-per-PR CI.
- `brite-salesforce/CLAUDE.md` has ~40 SF-specific gotchas that are currently invisible to `workflows:*` — these are the source material for Brite customization of adopted skills.
- Has its own `.mcp.json` with broad dev scope (`--toolsets orgs,metadata,data,users,testing --allow-non-ga-tools`) — CORRECT separation from our marketing plugin's narrow scope.

---

## 3. Architectural Decisions

### 3.1 Plugin naming: `revops`
"Revenue Operations" — broader than "salesforce" so dbt audience views, Outreach, Gong, or future CRM integrations fit cleanly without renaming. Peer to `marketing` and `workflows`.

### 3.2 Adoption method: `git subtree` (fork-behavior by default)
Import Jaganpro via `git subtree add`, treat as our own code going forward. `git subtree pull` remains available IF we ever want upstream updates, but we commit to "this is ours now." Zero-cost optionality to sync selectively.

Rationale: subtree is strictly more flexible than wholesale fork. If we never pull upstream, it behaves identically to a fork. If upstream ships a bug fix we want, one command pulls it in.

### 3.3 Workflow integration: augment, don't replace
`workflows:session-start` / `workflows:review` / `workflows:ship` stay unchanged. RevOps adds:
- **Auto-activating skills** that inject SF knowledge during each workflows phase (via intent-matching against skill descriptions)
- **3 new `/revops:*` commands** for SF-specific orchestration that workflows doesn't cover: `deploy-sandbox`, `deploy-prod`, `post-deploy-runbook`
- **Hooks** that fire only in SFDX-adjacent contexts (cwd-aware)

### 3.4 MCP configuration strategy
Three SF MCP server instances exist, each with the right scope:
| Context | MCP server | Toolsets | Purpose |
|---|---|---|---|
| `plugins/marketing/.mcp.json` | `plugin:marketing:salesforce` | `data` | Narrow marketing-consumption (SOQL reads only) |
| `plugins/revops/.mcp.json` (new) | `plugin:revops:salesforce` | `data,metadata,testing` | Medium SF dev scope, GA-only, `--no-telemetry` |
| `brite-salesforce/.mcp.json` | `Salesforce DX` | `orgs,metadata,data,users,testing` + `--allow-non-ga-tools` | Broad dev scope for active org development |

Different scope per context is correct. Claude Code project-scope precedence means they don't conflict.

### 3.5 Skill filter (what we adopt)
**Adopt (15):** sf-apex, sf-flow, sf-lwc, sf-soql, sf-testing, sf-debug, sf-metadata, sf-data, sf-docs, sf-permissions, sf-connected-apps, sf-integration, sf-deploy, sf-diagram-mermaid, (+ hooks, LSP loops, scorer rubrics shared infra)

**Skip (21 skills + 7 agents):** Data Cloud family (7), Agentforce AI family (5), Industries/Vlocity (7), sf-flex-estimator (1), sf-diagram-nanobananapro (1), all consulting agents (7).

### 3.6 Naming: prefix all Brite-customized skills `brite-*`
Original names like `sf-apex` become `brite-apex` after customization. Clear signal that these are Brite-maintained forks, not pristine upstream.

### 3.7 Documented in an ADR
Architecture Decision Record lives in `docs/decisions/007-revops-plugin-design.md`. Captures: subtree over fork, augment over replace, skill filter, MCP strategy. Prevents re-litigation.

---

## 4. Issue Chain (Dependency View)

```
PHASE 0 — Quick wins (all parallel, no dependencies):
  ├── BC-XXXX  Tighten marketing MCP config
  ├── BC-XXXX  Audit Marketing_Claude_MCP service user permissions
  ├── BC-XXXX  Document SF capability adoption decision framework
  └── BC-XXXX  Watch @salesforce/mcp for Headless 360 landing

PHASE 1 — RevOps foundation (sequential):
  ├── BC-XXXX  ADR — RevOps plugin design decisions
  └── BC-XXXX  Scaffold plugins/revops/ + git subtree import + filter upstream

PHASE 2 — Orchestration commands (parallel, depends on Phase 1):
  ├── BC-XXXX  /revops:deploy-sandbox
  ├── BC-XXXX  /revops:deploy-prod
  └── BC-XXXX  /revops:post-deploy-runbook

PHASE 3 — Brite skill customizations (parallel per-skill, depends on Phase 1):
  ├── BC-XXXX  Customize sf-deploy → brite-deploy (HIGH PRIORITY)
  ├── BC-XXXX  Customize sf-permissions → brite-permissions
  ├── BC-XXXX  Customize sf-connected-apps → brite-connected-apps
  ├── BC-XXXX  Customize sf-apex → brite-apex
  ├── BC-XXXX  Customize sf-metadata → brite-metadata
  ├── BC-XXXX  Customize sf-soql → brite-soql
  ├── BC-XXXX  Customize sf-testing → brite-testing
  ├── BC-XXXX  Customize sf-debug → brite-debug
  ├── BC-XXXX  Customize sf-flow → brite-flow
  ├── BC-XXXX  Customize sf-lwc → brite-lwc
  ├── BC-XXXX  Customize sf-data → brite-data
  ├── BC-XXXX  Customize sf-docs → brite-docs
  └── BC-XXXX  Customize sf-integration → brite-integration

PHASE 4 — Hooks (depends on Phase 1):
  └── BC-XXXX  SessionStart hook (cwd-aware SF banner)
  [DEFERRED] PreToolUse deprecated sfdx warner — revisit after Phase 1 to check Jaganpro hooks
  [CUT]      PostToolUse XML validator — covered by `sf project deploy start --dry-run`

Total: 23 issues.
```

**Critical path:** Phase 1 ADR → Phase 1 scaffold → Phase 3 sf-deploy customization. Everything else is parallelizable.

---

## 5. Standard Issue Template (applies to every issue below)

Every issue in this plan follows the same structure. Each agent picking up an issue MUST:

### 5.1 Task tracking (first action)
Before any other work, call `TaskCreate` to generate a task list with one entry per phase:
- `Explore: [issue title]`
- `Plan: present to user and get approval`
- `Execute: [specific work]`
- `Verify: run objective test criteria`
- `Check-in gate 1: [milestone-specific]`
- `Check-in gate 2: [milestone-specific]`

Update each task via `TaskUpdate` as it starts (`in_progress`) and completes (`completed`). **Never batch task updates — mark completed immediately.**

### 5.2 Check-in cadence
**Check in with the user at every major decision point.** At minimum:
- After Explore, before Plan (present findings + ask clarifying questions)
- After Plan, before Execute (present plan + get explicit approval)
- At each Check-in gate marked in the issue
- Before any destructive action (git rebase, force push, file deletion)
- Before marking the issue Done

**One question at a time** at check-ins, never batched. Per `feedback_one_question_at_a_time.md`.

### 5.3 Explore → Plan → Execute → Verify phases

**Explore:**
- Read exact files listed in the issue
- Answer specific questions listed in the issue
- Gather context from brite-salesforce/CLAUDE.md if SF-relevant
- Check Linear for related issues
- Check `memory/MEMORY.md` for relevant prior decisions

**Plan:**
- Draft the concrete approach with file paths, function names, CLI commands
- Surface trade-offs explicitly
- **Check-in gate:** present plan to user, answer questions, get approval before executing

**Execute:**
- Follow the plan step-by-step
- Use dedicated tools (Read/Edit/Write/Glob/Grep) over Bash when available
- Commit at natural checkpoints with clear messages
- **Check-in gate:** present progress at each major milestone defined in the issue

**Verify — Objective criteria:**
Every issue defines a concrete verification table:

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | ... | ... | ... |

**All tests must pass before marking Done.** Paste test results into PR body. Verify at least one cross-repo scenario where the issue affects SF work (from brite-salesforce or brite-gtm).

### 5.4 Verdict gates before closing
Before marking Done:
- [ ] All objective verify tests pass
- [ ] PR body has test results + objective verdict per test
- [ ] `/workflows:review` run; P1 findings fixed
- [ ] User has explicitly approved completion

---

## 6. Phase 0 — Quick Wins (file now, work in parallel)

### Issue 0.1 — Tighten plugin:marketing:salesforce MCP config

**Priority:** 3
**Blocks:** none
**Blocked by:** none
**Dependencies:** none

**Context:** Our `@salesforce/mcp` registration in `plugins/marketing/.mcp.json` is missing `--no-telemetry` (telemetry is ON by default). `salesforce.md` doesn't document the `--tools` cherry-pick pattern or the hidden `directory` parameter trap (every data/metadata tool requires a real SFDX project path — marketing consumer skills calling MCP from a non-SFDX cwd will fail). Small tightening, high leverage before any consumer skill ships.

**Task tracking:** Call `TaskCreate` with entries for Explore, Plan+approval, Execute (config change + doc additions), Verify, final check-in.

**Explore:**
- Read `plugins/marketing/.mcp.json` — confirm current args
- Read `plugins/marketing/tools/integrations/salesforce.md` §Registration + §Auth
- Read `docs/research/salesforce-mcp-findings.md` Q4 (credential storage) for context
- Confirm via `gh api repos/salesforcecli/mcp/contents/packages/mcp/src/index.ts` that `--no-telemetry` + `--tools` semantics are as we understand

**Plan (check-in gate):**
- Draft exact new `.mcp.json` args array (one-line change: add `--no-telemetry` to args)
- Draft the `--tools` cherry-pick pattern documentation (~20 lines in salesforce.md)
- Draft the `directory` parameter trap documentation (~15 lines in salesforce.md Known Gotchas)
- Present to user for approval before executing

**Execute:**
- Edit `plugins/marketing/.mcp.json` — add `"--no-telemetry"` to args array
- Append new Gotcha bullet to `salesforce.md` §Known Gotchas: "Every data/metadata tool requires `directory` parameter (SFDX project path). Skills called from a non-SFDX cwd will fail."
- Append new subsection to `salesforce.md` §Registration: "Cherry-picking individual tools via `--tools`" with worked example `--toolsets data --tools assign_permission_set`
- Bump `plugins/marketing/.claude-plugin/plugin.json` version (0.3.0 → 0.3.1) AND `.claude-plugin/marketplace.json` marketing entry

**Verify — Objective criteria:**

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | Fresh Claude Code session in plugins repo | `claude mcp list` | Marketing Salesforce MCP shows `✓ Connected` |
| T2 | — | `./scripts/validate.sh` | Exit 0 |
| T3 | — | `grep -c "no-telemetry" plugins/marketing/.mcp.json` | 1 |
| T4 | — | grep `salesforce.md` for "directory parameter" | Matches appear in Known Gotchas |
| T5 | — | grep `salesforce.md` for "cherry-pick" or "--tools" | Matches appear in Registration |
| T6 | — | Version bumped in both plugin.json + marketplace.json | Values match |

**Out of scope:** Any new skills; any change to `--toolsets data` value; any change to BC-5579 ECA provisioning.

**Related:** BC-5534 findings, BC-5579, this plan §2.2.

---

### Issue 0.2 — Audit Marketing_Claude_MCP service user permission baseline

**Priority:** 2
**Blocks:** first SF-consuming skill ship (BC-2717 et al)
**Blocked by:** none

**Context:** `@salesforce/mcp` has no server-side read-only mode, no row limits, no destructive-tool gates. All blast radius is controlled by the Salesforce service user's permission set assignments. BC-5579 created the `Marketing_Claude_MCP` ECA + service user but we haven't audited what the user can actually do. If the user has `Modify All Data` or broad write permissions, our `--toolsets data` narrowness is belt-and-suspenders false comfort. This is the highest-leverage security hardening available before the first consumer skill ships.

**Task tracking:** Call `TaskCreate` with entries for Explore (read SF org state), Plan+approval (permission tightening strategy if needed), Execute (document findings + any tightening), Verify, final check-in.

**Explore:**
- In brite-salesforce, query: `sf data query --query "SELECT Username, ProfileId, Profile.Name FROM User WHERE Username LIKE '%marketing%claude%'"` (adjust for actual service user email from Bitwarden)
- Query permission set assignments: `sf data query --query "SELECT AssigneeId, PermissionSetId, PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = '<service-user-id>'"`
- For each permset: `sf data query --query "SELECT Name, PermissionsModifyAllData, PermissionsViewAllData FROM PermissionSet WHERE Id = '<permset-id>'"`
- Cross-reference with brite-salesforce/docs/artifacts/user-role-matrix.md for expected baseline
- Enumerate object permissions on Lead, Contact, Account, Campaign, Territory__c, Location, Activity, Lifecycle_Stage_History__c, Opportunity
- **Check-in gate:** present findings to user before drafting any tightening plan

**Plan (check-in gate):**
- Document actual permission baseline
- Compare to minimum-required for 5 planned consumer skills (BC-2717/2720/2725/2727/2728)
- If baseline is overprovisioned: propose specific permset changes (which permissions to remove, which permsets to un-assign)
- If baseline is correct: just document findings in salesforce.md
- Present to user for approval before any org change

**Execute:**
- Add new §Service User Permissions section to `plugins/marketing/tools/integrations/salesforce.md`
- Document actual object/field permissions, CRUD matrix, destructive capabilities
- If tightening proposed and approved: implement via brite-salesforce permset metadata changes (separate PR in brite-salesforce, not in plugins repo)

**Verify — Objective criteria:**

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | — | grep salesforce.md for new §Service User Permissions | Section exists, populated |
| T2 | — | Document lists actual permset assignments for service user | Names match live org query |
| T3 | — | Document identifies minimum-required permissions per planned skill | 5 skills × required-permission matrix present |
| T4 | If tightening: | Live query shows `PermissionsModifyAllData = false` on service user permsets | Pass |
| T5 | If tightening: | Cross-repo verify: brite-salesforce PR merged + deployed | Separate PR URL referenced |

**Out of scope:** Any tightening of the ECA consumer key/scopes (those are handled by BC-5579); any change to JWT flow.

**Related:** BC-5534, BC-5579, this plan §2.2, §2.4.

---

### Issue 0.3 — Document "SF capability adoption decision framework" in salesforce.md

**Priority:** 4
**Blocks:** none
**Blocked by:** none

**Context:** Each time Salesforce ships a major announcement (Headless 360 this month), we end up re-deriving "is this relevant to Brite?" from scratch. Capture the decision framework once so future sessions don't re-litigate.

**Task tracking:** `TaskCreate` entries: Explore, Plan+approval, Execute (write section), Verify.

**Explore:**
- Read existing `plugins/marketing/tools/integrations/salesforce.md` structure
- Read `docs/decisions/` for ADR format conventions
- Find the 6-checkpoint framework from this session: runtime model, license, plugin slot, toolset breadth, GA gate, domain fit

**Plan (check-in gate):**
- Draft new §SF Capability Adoption Decision Framework section (~40 lines)
- Decide: in-line in salesforce.md or a separate ADR `docs/decisions/008-sf-capability-adoption.md` with @import
- Present to user for approval

**Execute:**
- Add the section where approved
- Include the 6 checks with concrete examples from this session (e.g., Agentforce runtime mismatch, CC BY-NC license disqualifier)

**Verify:**

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | grep salesforce.md for "Runtime model check" | Present |
| T2 | grep for "License check" | Present |
| T3 | grep for each of 6 checks | All 6 present |
| T4 | `./scripts/check-guardrails.sh` | No anti-slop violations |

**Related:** This plan §2.1, BC-5534 findings.

---

### Issue 0.4 — Watch @salesforce/mcp for Headless 360 (0.31+) landing

**Priority:** 4
**Blocks:** Adoption of any Headless 360 feature
**Blocked by:** none
**Nature:** Monitoring + time-triggered

**Context:** Headless 360's "60 new MCP tools + 30 skills" were announced 2026-04-15 but are NOT yet in any public `@salesforce/mcp` release. Expect them in 0.31+ via weekly Wednesday stable cadence. Need a standing monitoring mechanism so we don't miss the landing.

**Task tracking:** `TaskCreate` entries: Explore, Plan, Execute (set up monitoring), Verify, then parked until trigger fires.

**Explore:**
- Review npm registry: `npm view @salesforce/mcp time` (find latest version + cadence)
- Review GitHub releases: `gh api repos/salesforcecli/mcp/releases`
- Identify: what specific indicators signal Headless 360 tools have landed (new toolset enum values? new tools? README updates?)

**Plan (check-in gate):**
- Decide monitoring mechanism: cron-scheduled session-start agent? Manual weekly check? Slack webhook?
- Decide verification mechanism once a new version lands: re-run BC-5534 Appendix A (toolset inventory diff)
- Present to user for approval

**Execute:**
- If cron: set up via `/schedule` command
- If manual: add to weekly-planning or team calendar
- Update `memory/MEMORY.md` with "Headless 360 watch active" reference

**Verify:**

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | Monitoring mechanism is active | Cron entry exists OR calendar invite set |
| T2 | Documented re-run procedure for Appendix A when version bumps | Procedure exists in docs/ |
| T3 | Follow-up issue filed for "adopt Headless 360 tools" auto-triggered when 0.31+ lands | Follow-up issue referenced |

**Related:** This plan §2.1, BC-5534.

---

## 7. Phase 1 — RevOps Foundation

### Issue 1.1 — ADR: RevOps plugin design decisions

**Priority:** 3
**Blocks:** Issue 1.2
**Blocked by:** none

**Context:** Capture the architectural decisions from this planning session in a formal ADR so future contributors don't re-litigate (plugin naming, subtree vs fork, augment vs replace, skill filter, MCP strategy).

**Task tracking:** `TaskCreate` entries: Explore (read existing ADRs), Plan+approval, Execute (write ADR), Verify.

**Explore:**
- Read `docs/decisions/` for ADR format
- Read this plan file §3 for decisions to capture

**Plan (check-in gate):**
- Draft ADR `docs/decisions/007-revops-plugin-design.md`
- Sections: Context, Decision Drivers, Decisions (6), Rejected Alternatives, Consequences
- Present draft to user for approval

**Execute:**
- Write ADR
- Add to top-level CLAUDE.md references if it's load-bearing

**Verify:**

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | ADR file exists | `docs/decisions/007-revops-plugin-design.md` present |
| T2 | grep for each of 6 decisions | All 6 appear as distinct sections |
| T3 | `./scripts/check-guardrails.sh` | Pass |

**Related:** This plan §3.

---

### Issue 1.2 — Scaffold plugins/revops/ + git subtree import + filter upstream

**Priority:** 3
**Blocks:** Phase 2, Phase 3, Phase 4
**Blocked by:** Issue 1.1

**Context:** Create the `plugins/revops/` plugin skeleton, import Jaganpro/sf-skills via `git subtree`, remove the 21 skills + 7 agents we don't want, author `plugin.json` + plugin-scoped `.mcp.json` + basic hooks. This is the single longest issue in the plan — plan for multiple check-ins.

**Task tracking:** `TaskCreate` entries:
- Explore: read Jaganpro repo, existing plugins/, plugin.json schema
- Plan: lock in subtree strategy + filter list + plugin.json shape
- Check-in gate 1: plan approval
- Execute: `git subtree add`
- Check-in gate 2: initial subtree verified in-tree
- Execute: filter (remove 21 skills + 7 agents)
- Check-in gate 3: filtered state verified
- Execute: author plugin.json + .mcp.json + UPSTREAM.md + LICENSE preservation
- Execute: rename retained skills from `sf-*` to `brite-*` (optional — could defer to per-skill issues)
- Verify

**Explore:**
- Read `plugins/marketing/.claude-plugin/plugin.json` and `plugins/workflows/.claude-plugin/plugin.json` as reference
- Read `.claude-plugin/marketplace.json` to understand plugin registration
- Read `CLAUDE.md` §Gotchas for `plugin.json` strict schema rules
- Inventory Jaganpro's top-level dirs + files via `gh api repos/Jaganpro/sf-skills/contents/`
- Read Jaganpro's `install.sh` to understand their runtime dependencies (Python toolchain, LSP jars, `uv` lockfile)

**Plan (check-in gate 1):**
- Confirm subtree prefix: `plugins/revops/` or `plugins/revops/upstream/` (user preference)
- Confirm skill filter list (15 keep, 21 skip, 7 agents skip) — see this plan §3.5
- Confirm rename strategy (rename all 15 kept skills now, or defer per-skill?)
- Draft `plugin.json` fields (name: "revops", description, version 0.1.0, skills/commands auto-discovery)
- Draft `.mcp.json` (`--toolsets data,metadata,testing --no-telemetry`, GA-only, DEFAULT_TARGET_ORG)
- Draft UPSTREAM.md documenting: source repo, pinned commit SHA, sync model, attribution notice
- Present to user for approval before executing

**Execute (with check-ins between major steps):**
- Step 1: `git subtree add --prefix=plugins/revops https://github.com/Jaganpro/sf-skills main --squash`
  - **Check-in gate 2:** verify subtree imported cleanly, `./scripts/validate.sh` still passes
- Step 2: Remove skipped items:
  - `rm -rf plugins/revops/skills/sf-datacloud*`
  - `rm -rf plugins/revops/skills/sf-industry-*`
  - `rm -rf plugins/revops/skills/sf-vlocity-*`
  - `rm -rf plugins/revops/skills/sf-ai-*`
  - `rm -rf plugins/revops/skills/sf-flex-estimator`
  - `rm -rf plugins/revops/skills/sf-diagram-nanobananapro`
  - `rm -rf plugins/revops/agents`
  - **Check-in gate 3:** verify remaining skills match filter list
- Step 3: Author `plugins/revops/.claude-plugin/plugin.json`
- Step 4: Author `plugins/revops/.mcp.json`
- Step 5: Write `plugins/revops/UPSTREAM.md` (attribution + sync model)
- Step 6: Ensure `LICENSE` (MIT) is preserved in `plugins/revops/LICENSE`
- Step 7: Update `.claude-plugin/marketplace.json` to list revops
- Step 8: Update top-level `CLAUDE.md` §Repository Structure to list revops
- Step 9: (Optional — defer if scope creeps) Rename each retained skill `sf-X` → `brite-X`

**Verify — Objective criteria:**

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | — | `ls plugins/revops/` | `.claude-plugin/`, `skills/`, `LICENSE`, `UPSTREAM.md` present |
| T2 | — | `ls plugins/revops/skills/` | Contains exactly the 15 kept skills (or brite-* renames) |
| T3 | — | grep `plugin.json` for disallowed fields | Only allowlisted fields present (name, description, author, version, homepage, repository, license, keywords, commands, skills, mcpServers, userConfig) |
| T4 | — | `./scripts/validate.sh` | Exit 0 |
| T5 | — | `./scripts/check-guardrails.sh --claude-md plugins/revops/CLAUDE.md` (if exists) | Pass |
| T6 | In fresh Claude Code session | `claude mcp list` from any cwd with plugin enabled | `plugin:revops:salesforce` shows `✓ Connected` |
| T7 | In brite-salesforce cwd | Ask Claude: "what SF skills do you have?" | RevOps skills appear in response |
| T8 | In non-SF cwd (e.g., brite-data-platform) | Same question | RevOps skills either hidden or clearly marked as SF-only |
| T9 | Cross-repo: brite-salesforce | Open a PR unrelated to this one, confirm revops plugin loads | No errors, no breakage |
| T10 | — | `git log plugins/revops/` | Subtree import commit present; pinned SHA visible in UPSTREAM.md |

**Out of scope:** Customizing skills (that's Phase 3); new commands (Phase 2); hooks (Phase 4).

**Related:** Issue 1.1, this plan §3, Jaganpro README.

---

## 8. Phase 2 — Orchestration Commands

Each Phase 2 issue follows the same template. Command scope shown per issue.

### Issue 2.1 — /revops:deploy-sandbox command

**Priority:** 2 (high — fills the workflows gap)
**Blocks:** none
**Blocked by:** Issue 1.2

**Scope:** Orchestrates sandbox deploy with dry-run, actual deploy, Apex tests, manual verification prompt.

**Explore:**
- Read `brite-salesforce/CLAUDE.md` §Commands for canonical `sf project deploy start` invocation
- Read `brite-salesforce/CLAUDE.md` §Development Flow step 2 (Validate in sandbox)
- Read existing `plugins/workflows/commands/ship.md` as a reference pattern for slash commands

**Plan (check-in gate):**
- Draft command markdown with phases:
  - Phase 1: dry-run sandbox deploy
  - Phase 2: review dry-run output, abort or proceed
  - Phase 3: actual sandbox deploy
  - Phase 4: Apex tests
  - Phase 5: manual browser verification prompt (AskUserQuestion)
  - Phase 6: completion message
- Present to user

**Execute:** Write `plugins/revops/commands/deploy-sandbox.md` with AskUserQuestion gates between phases.

**Verify — Objective criteria:**

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | In brite-salesforce with a staged no-op metadata change | Run `/revops:deploy-sandbox` | Dry-run completes, user confirms, sandbox deploys, tests pass, prompt appears |
| T2 | In brite-salesforce with a deliberately broken metadata change | Run `/revops:deploy-sandbox` | Dry-run fails, user is told exactly why, no actual deploy attempted |
| T3 | User types "no" at Phase 2 gate | — | Command exits cleanly, no deploy |
| T4 | User types "no" at Phase 5 gate | — | Command exits with instruction to rollback if needed |
| T5 | Cross-repo: run from non-SFDX cwd | — | Command halts with clear error: "Not in an SFDX project" |

---

### Issue 2.2 — /revops:deploy-prod command

**Priority:** 2
**Blocks:** none
**Blocked by:** Issue 1.2

**Scope:** Orchestrates prod deploy with explicit approval gate, dry-run first, actual deploy, Tooling API post-deploy verification.

**Explore:**
- Read `brite-salesforce/CLAUDE.md` §Development Flow step 4 (Deploy to Production)
- Read §Apex & Automation gotchas for post-deploy verification patterns (SOQL-verify after deploy)
- Read §Permissions & Security for FLS / permset deployment rules

**Plan (check-in gate):**
- Draft command phases:
  - Phase 1: confirm PR merged + on main branch
  - Phase 2: prod dry-run
  - Phase 3: **explicit double-confirmation gate** ("Deploy to PRODUCTION?")
  - Phase 4: actual prod deploy
  - Phase 5: verify 90%+ org coverage
  - Phase 6: post-deploy Tooling API SOQL verification (critical components exist)
  - Phase 7: runbook trigger — prompt to run /revops:post-deploy-runbook
- Present to user

**Execute:** Write `plugins/revops/commands/deploy-prod.md`. Double-confirmation gate is non-negotiable.

**Verify — Objective criteria:**

| Test | Setup | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | Happy path, small metadata change, on main | `/revops:deploy-prod` | All 7 phases complete; post-deploy SOQL finds deployed components |
| T2 | User not on main | — | Halts at Phase 1 with "must be on main branch" |
| T3 | Dry-run fails | — | Halts at Phase 2, no prompt to confirm |
| T4 | User declines Phase 3 | — | Exits cleanly, nothing deployed |
| T5 | Post-deploy SOQL returns 0 for critical component | — | Surfaces the component mismatch, does NOT auto-retry |
| T6 | Cross-repo: non-SFDX cwd | — | Halts immediately |

---

### Issue 2.3 — /revops:post-deploy-runbook command

**Priority:** 2
**Blocks:** none
**Blocked by:** Issue 1.2

**Scope:** Walks user through mandatory manual post-deploy steps (Flow activation, Scheduled Apex re-schedule, Named Credential URLs, Kanban layout refresh).

**Explore:**
- Read `brite-salesforce/CLAUDE.md` §Apex & Automation for Scheduled Apex pattern
- Read §Deploy & Retrieve for Named Credential placeholder gotcha
- Read §Metadata Authoring for Kanban Group By cache gotcha
- Enumerate all manual steps required post-deploy from brite-salesforce docs

**Plan (check-in gate):**
- Draft interactive checklist walker:
  - New Screen Flows deployed? → Guide through Setup UI activation
  - Scheduled Apex affected? → Guide through `System.schedule` re-setup
  - New Named Credentials? → Guide through per-org URL update
  - New picklist fields on standard objects? → Guide through layout add to flush Kanban cache
- Present to user

**Execute:** Write `plugins/revops/commands/post-deploy-runbook.md`.

**Verify:**

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | Run in brite-salesforce after a deploy that includes a new Screen Flow | Flow activation step appears, explains Setup UI path |
| T2 | Run after deploy with no Flows | Flow step is skipped or surfaces "no action needed" |
| T3 | Run after deploy affecting Named Credentials | Per-org URL update step appears with list of env URLs |
| T4 | Command handles "no relevant changes" | Short clean completion; doesn't force user through empty checklist |

---

## 9. Phase 3 — Brite Skill Customizations

All Phase 3 issues follow the same template. Per-skill specifics shown in table below.

### Template for each skill customization issue

**Task tracking:** `TaskCreate` entries: Explore (read upstream SKILL.md + Brite source material), Plan+approval, Execute (edit SKILL.md + references), Verify, final check-in.

**Explore:**
- Read the upstream skill at `plugins/revops/skills/<skill>/SKILL.md` and all references
- Read relevant sections of `brite-salesforce/CLAUDE.md` gotchas (per-skill source material — see table below)
- Read `brite-salesforce/docs/artifacts/` for relevant authoritative docs
- Identify exact Brite conventions that differ from upstream defaults

**Plan (check-in gate):**
- Draft customization diff: what upstream content to keep vs. replace
- Propose rename: `sf-<name>` → `brite-<name>` (if not done in Issue 1.2)
- Draft attribution header: `# Adapted from Jaganpro/sf-skills@<sha>` + MIT notice
- Present to user for approval

**Execute:**
- Edit SKILL.md description (update intent-match keywords for Brite context)
- Edit SKILL.md body (layer in Brite conventions; replace generic patterns)
- Edit references/ as needed (link to brite-salesforce docs)
- Preserve upstream attribution

**Verify — Objective criteria:**

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | Skill file has MIT attribution header | Present |
| T2 | Skill description references Brite conventions | grep for "brite" or "britenites" |
| T3 | In brite-salesforce, invoke skill by relevant intent | Skill activates and uses Brite-specific guidance |
| T4 | `./scripts/validate.sh` | Pass |
| T5 | Cross-repo test: invoke same skill from a non-SF repo | Skill does NOT activate (description-match correctly scoped) |

### Per-skill breakdown

| Issue | Target skill | Brite source material (brite-salesforce/CLAUDE.md sections) | Priority |
|---|---|---|---|
| 3.1 | **sf-deploy → brite-deploy** | §Deploy & Retrieve, §Development Flow, §Verification Checklist. Add: dry-run discipline, 90%+ coverage, post-deploy SOQL verification, Scheduled Apex re-schedule, Flow activation, Named Credential URLs | **1 (highest)** |
| 3.2 | sf-permissions → brite-permissions | §Permissions & Security. Add: Base_CRM_Access naming, *_Group / *_Management_Group pattern, FLS sync across 7 permsets, Lifecycle fields automation-only, session-based perm set vs Bulk API | 2 |
| 3.3 | sf-connected-apps → brite-connected-apps | §External Client Apps. Add: Spring '26 Connected App deprecation, our 4 ECAs (Marketing_Claude_MCP, Outbound_Sales_Ops, CI_Deploy, OutboundSync), JWT-from-ECA+scratch-org bug, OAuth settings cross-org gotchas | 2 |
| 3.4 | sf-apex → brite-apex | §Apex & Automation. Add: Apex-first principle, LeadTriggerHandler dispatch, Queueable BATCH_SIZE=90, @TestVisible+isRunningTest escape hatches, Bypass_Validation_Rules, 100% class coverage, with sharing + User | 2 |
| 3.5 | sf-metadata → brite-metadata | §Metadata Authoring + §Deploy & Retrieve. Add: Activity fields on Activity object, ListView column aliases, Layout related list format, restricted picklist RT definitions, PathAssistant via Setup UI, Kanban Group By cache | 2 |
| 3.6 | sf-soql → brite-soql | Object model + §Apex & Automation SOQL gotchas. Add: Territory__c/Location model, Task semi-join not supported, polymorphic Who/What non-dot-walkable, User.Email vs Username in cross-env, with sharing on User | 3 |
| 3.7 | sf-testing → brite-testing | §Apex & Automation testing patterns + §Engineering Standards test requirements. Add: 100% class coverage, @TestSetup static state, Queueable in Test.stopTest, LWC Jest pre-commit | 3 |
| 3.8 | sf-debug → brite-debug | §Apex & Automation Queueable silent-retry, Web-to-Lead BeforeUpdate cascade, TraceFlag patterns | 3 |
| 3.9 | sf-flow → brite-flow | §Metadata Authoring Flow deploy as Draft, §Apex & Automation Screen Flow activation | 3 |
| 3.10 | sf-lwc → brite-lwc | Existing LWC patterns in brite-salesforce/force-app/main/default/lwc/; Dynamic Forms FLS+admin; flexipage cache | 4 |
| 3.11 | sf-data → brite-data | §Deploy & Retrieve data operations; HubSpot migration patterns; scripts/migration/ conventions | 4 |
| 3.12 | sf-docs → brite-docs | Link to brite-salesforce/docs/artifacts/; our dbt+handbook layered reference model | 4 |
| 3.13 | sf-integration → brite-integration | Named Credentials placeholder pattern; OutboundSync + HubSpot migration integrations; Named Credential redeploy gotcha | 4 |

Each row becomes a separate Linear issue. 13 issues in Phase 3 total (one per kept skill, no batching).

**Out of scope for each Phase 3 issue:** Changes to upstream installer, hook system, LSP integration (those stay in the subtree unmodified unless a specific Phase 4 issue addresses them).

---

## 10. Phase 4 — Hooks

### Issue 4.1 — RevOps SessionStart hook (cwd-aware SF banner)

**Priority:** 3
**Blocks:** none
**Blocked by:** Issue 1.2

**Scope:** SessionStart hook that detects SFDX-adjacent cwd (presence of `sfdx-project.json` within reach) and emits a short "RevOps active" banner. Silent in non-SF repos.

**Template applies:** Explore/Plan/Execute/Verify, TaskCreate, check-ins.

**Explore:** Read `plugins/workflows/hooks/hooks.json` for banner pattern. Design probe: `find . -maxdepth 3 -name sfdx-project.json -not -path './node_modules/*'` with short-circuit.

**Verify:**

| Test | Pre-state | Pass criteria |
|---|---|---|
| T1 | Session in brite-salesforce | RevOps banner appears, lists key commands |
| T2 | Session in brite-gtm | Silent — no banner |
| T3 | Performance | <50ms probe in steady state |

---

### DEFERRED — PreToolUse hook (deprecated sfdx warner)

Originally Issue 4.2. Deferred: revisit after Phase 1 to check whether Jaganpro's imported hooks already cover this (they ship a Haiku PreToolUse Bash|MCP hook that surfaces `sfdx` deprecation). If Jaganpro's hook is sufficient, this issue stays cut. If not, file fresh.

### CUT — PostToolUse metadata XML validator

Originally Issue 4.3. Cut from scope: covered in practice by `sf project deploy start --dry-run` which is already canonical per `brite-salesforce/CLAUDE.md`. Building a separate on-save XML validator has marginal value and non-trivial implementation cost (XML schema validation, false-positive management, performance budget).

---

## 11. Cross-Cutting Guidance (applies to every issue)

### 11.1 Frequent check-ins

Every issue must check in with the user at minimum:
- **Before Plan finalization** — present findings from Explore, confirm scope, resolve ambiguity
- **Before any destructive action** — git rebase, force push, file deletion, config overwrite
- **At each explicit check-in gate listed in the issue**
- **After Verify completes** — before marking Done

**One question at a time.** Do not batch check-in questions (per `feedback_one_question_at_a_time.md`).

### 11.2 Cross-repo verification

Every issue that touches SF-related behavior must verify in:
- brite-salesforce (SFDX project — primary target)
- brite-gtm or brite-data-platform (non-SFDX — negative control)
- A fresh Claude Code session (clean state)

Paste results into PR body.

### 11.3 Objective verify criteria

Every issue has a Verify table. Every test row must have:
- A concrete setup condition
- A concrete action or command
- An unambiguous pass criterion (pass/fail, not subjective)

"Looks right" is not a criterion. "Works for me" is not a criterion. Every test produces a quotable result.

### 11.4 Task list management

`TaskCreate` at issue start, `TaskUpdate` as each task progresses. Mark completed **immediately** when done — never batch at issue end. Per `feedback_visual_task_tracking.md`.

### 11.5 No duplication of Jaganpro's work

If a skill customization issue would effectively rewrite the entire upstream skill, stop and escalate — something is wrong with the customization scope. Brite customizations should be targeted diffs (replace 10-30% of upstream content), not wholesale rewrites.

### 11.6 Upstream attribution preservation

Every Brite-customized skill file keeps:
- MIT license notice
- Upstream commit SHA reference
- `# Adapted from Jaganpro/sf-skills@<sha>` header in frontmatter metadata

Never remove upstream's CREDITS.md files without explicit approval.

---

## 12. Success Metrics

### 12.1 Phase 0 complete when
- Marketing MCP has `--no-telemetry` live
- Service user permission baseline documented (and tightened if needed)
- SF adoption decision framework written
- Headless 360 monitoring active

### 12.2 Phase 1 complete when
- `plugins/revops/` exists with 15 filtered skills
- `plugin:revops:salesforce` MCP connects
- ADR 007 documented
- Cross-repo verification passes

### 12.3 Phase 2 complete when
- All 3 `/revops:*` commands exist and pass their verify tables
- End-to-end test: real metadata deploy to sandbox → review → prod deploy → runbook, all driven by RevOps commands

### 12.4 Phase 3 complete when
- All 15 skills Brite-customized with proper attribution
- sf-deploy customization (Issue 3.1) verified closes the workflows-plugin gap described in §1

### 12.5 Phase 4 complete when
- 3 hooks live, all verify tests pass
- SessionStart banner appears in brite-salesforce, silent elsewhere

### 12.6 Whole-plan definition of done
- Holden ships a real SF feature to production using `/workflows:session-start` → edit metadata → `/revops:deploy-sandbox` → `/workflows:review` → `/revops:deploy-prod` → `/workflows:ship` → `/revops:post-deploy-runbook`, and reports: "this closed the gap I was feeling"
- Cross-repo smoke: any Brite engineer enabling the plugin gets the full SF intelligence layer in `brite-salesforce`, nothing extra in non-SF repos

---

## 13. Answered Questions (2026-04-19)

1. **Plugin naming:** `revops` (broader umbrella for future non-SF RevOps tooling)
2. **Subtree prefix:** flat — `plugins/revops/` IS the subtree
3. **Skill renaming:** deferred to per-skill Phase 3 issues
4. **Phase 3 priority:** sf-deploy is #1 (closes workflows-plugin gap Holden feels today); 5 Priority-2 skills next (permissions, connected-apps, apex, metadata); Priority-3 (soql, testing, debug, flow); Priority-4 (lwc, data, docs, integration)
5. **Phase 0 / Phase 4 defers/cuts:** keep all 4 Phase 0; keep 4.1 SessionStart; defer 4.2 sfdx-warner pending post-Phase-1 Jaganpro-hook check; cut 4.3 XML validator
6. **Batching:** file all 23 at once under new RevOps Plugin milestone

---

## 14. References

- This planning session transcript (2026-04-19)
- `docs/research/salesforce-mcp-findings.md` (BC-5534)
- `docs/designs/outbound-agent-architecture-adrs.md` (ADR 2a/2c)
- `plugins/marketing/tools/integrations/salesforce.md`
- `plugins/marketing/tools/integrations/email-bison.md`
- `brite-salesforce/CLAUDE.md` (primary source material for Brite customizations)
- [Jaganpro/sf-skills README](https://github.com/Jaganpro/sf-skills)
- [@salesforce/mcp README](https://github.com/salesforcecli/mcp)
- [Headless 360 announcement](https://www.salesforce.com/news/stories/salesforce-headless-360-announcement/)
- [VentureBeat coverage](https://venturebeat.com/ai/salesforce-launches-headless-360-to-turn-its-entire-platform-into-infrastructure-for-ai-agents)
- Already-filed related issues: BC-5780, BC-5781
