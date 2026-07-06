# Cadence GitHub integration — research findings

**Issue:** [BC-5811](https://linear.app/brite-nites/issue/BC-5811/cadence-github-integration-research-gh-cli-vs-github-mcp-vs-none)
**Blocks:** [BC-5758](https://linear.app/brite-nites/issue/BC-5758) (Cadence scaffold) — decides whether `plugins/cadence/.mcp.json` ships with a GitHub server.
**Purpose:** Lock the GitHub-integration decision for the Cadence plugin — `gh` CLI vs official GitHub MCP vs no integration — with a reassessment trigger so any future phase issue can revisit without re-litigating the fundamentals.
**Date:** 2026-04-19
**Supersedes:** No prior doc. [BC-5757](https://linear.app/brite-nites/issue/BC-5757) ([`docs/designs/cadence-plugin.md`](../designs/cadence-plugin.md)) left this decision unscoped; [BC-5810](https://linear.app/brite-nites/issue/BC-5810) ([`docs/designs/cadence-orchestration.md`](../designs/cadence-orchestration.md)) locked orchestration shape but punted GitHub to this issue.

---

## 1. Live Linear-project → GitHub-repo mapping

### 1.1 Method

- **Linear side:** `mcp__plugin_workflows_linear-server__list_projects` with cursor pagination, `limit: 20` per call. The `team: "Brite Company", state: "started"` combo returns empty (documented gotcha in [`docs/designs/cadence-plugin.md` § 2.3](../designs/cadence-plugin.md)); the reliable pattern is list-all then client-side filter. Pagination cursor did not advance past page 2 during this session — the sample below is 20 unique projects across 5 teams (BC, BN, BL, BS, EXE, DRO) rather than the full active set. Sample covers every project status visible at a glance plus the cross-team projects that matter for the `/cadence:weekly` flow.
- **GitHub side:** `gh repo list Brite-Nites --limit 100 --json name,url,description,pushedAt,isArchived,isPrivate` — 55 repos, 7 archived. Live snapshot, pasted inline below.

### 1.2 Mapping table (20 projects)

Status column is the Linear `status.type` at query time. Repo match uses live `gh repo list` output; ambiguous matches get a `?` and are explained in § 1.4.

| Linear project | Team(s) | Status | Likely GitHub repo | Confidence |
|---|---|---|---|---|
| Commercial Site Documentation (The Standard…) | BC | started | *(none — documentation project, content lives in handbook)* | high (no repo expected) |
| St. Nick's Refurb Tracker | BC | backlog | *(none yet — app to build)* | high (pre-repo) |
| Meeting Automation | BC | started | *(none — Google Apps Script, no Git)* | high (no repo expected) |
| Organization and Infrastructure | EXE | backlog | *(none — executive/planning)* | high (no repo expected) |
| Asset Studio | BC | started | `gtm_assets` **?** / new repo TBD | low — see § 1.4 |
| Public Safety ICP — 250th Anniversary | BN, BC | backlog | *(none — ICP/strategy)* | high (no repo expected) |
| Meeting Agenda Automation | BN | backlog | *(none — duplicate of "Meeting Automation" concept)* | high |
| Warehouse Classification | BC | started | *(none — documentation/buildout standards)* | high |
| Brite GTM | BC, BN, BL, BS | started | `brite-gtm` | high — name match + description match |
| Brite LMS | BN, BC | started | `brite-lms` | high — name match + description match |
| Droidor - Brite Supply | DRO | started | `brite-supply` (theme files) | high — description cites "Brite Supply Site Revision Plan" |
| Linear Workspace Configuration | BC | completed | *(none — Linear config, no code)* | high |
| Vzw iPad Service Management | BC | completed | `Vzw-Service-Project` | high — description match |
| Brite Training | BC | started | `brite-training` | high |
| Brite Platform SDK | BC | started | *(not in `gh repo list` — planned/nascent)* | low — see § 1.4 |
| Brite Recruiting | BN, BC | started | `brite-recruiting` | high |
| Communication Infrastructure | BN, BC | started | `comms-infra` | high — description match |
| Outbound Sales Ops System | BC | started | `outbound-sales-ops` | high |
| Salesforce Implementation | BC | started | `brite-salesforce` | high |
| Brite Labs Website | BL, BC | started | `brite-labs-landing-page` **?** / `brite-labs` **?** | low — see § 1.4 |

### 1.3 Summary shape

- **10 / 20** projects have a clear, high-confidence repo match (half the sample).
- **7 / 20** projects legitimately have no code repo — documentation, Google Apps Script, Linear config, and ICP/strategy projects are *correctly* repo-less. A GitHub integration that assumes 1:1 mapping would paint these red when nothing is wrong.
- **3 / 20** projects are ambiguous (Asset Studio, Brite Platform SDK, Brite Labs Website). These are the *real* mapping holes.
- **Multi-team projects are common.** Brite GTM appears under 4 teams simultaneously; Salesforce Implementation + Outbound Sales Ops are dual-team. Any connectivity check must dedupe by `project.id` before querying GitHub.

### 1.4 Ambiguities (explicit)

- **Asset Studio** — summary says "production system for interactive code-based sales assets served at sales.britelabs.io." Could be `gtm_assets` (Brite Labs sales enablement), could be a subdirectory of `brite-labs`, could be a net-new repo not yet created. Human triage needed; not filed as a follow-up per the approved § 7 policy.
- **Brite Platform SDK** — description says "~46 repos, pnpm + Turborepo + Changesets, published via GitHub Packages." The SDK repo name isn't in the live `gh repo list` output. Either it's under a different org, private and scoped-out of the list call, or not yet created. Flag for human confirmation.
- **Brite Labs Website** — two plausible repos in live list: `brite-labs-landing-page` (older, likely the marketing site) and `brite-labs` (described as "Brite Labs website and initial landing page mock-up"). These may be at different stages of the same initiative or may need consolidation.

### 1.5 Orphan repos (in `gh repo list`, no Linear project match in the sampled 20)

Many of these almost certainly map to projects beyond page 2 of the pagination — not filed as holes. Listed for completeness and to confirm the Brite portfolio is repo-heavy.

```
brite-claude-plugins (this repo; maps to "Brite Plugin Marketplace")
handbook
brite-data-platform
email-infrastructure-orchestration-platform
brite-base
brite-supply-master
brite-labs
partner-management
brite-sites
muni-intel
gtm_assets
product-information-manager
weekly-planning           ← Cadence source of truth (W15/W16 narratives)
brand-hub
lseo-tool
experiential_activations
brite-nites-pricing-matrix
bison-lead-upload-script
platform-planning
britenites-web
brite-paperclip
brite-symphony
git-large-file-storage
outbound-ops
brite-company-dashboard
universities-gtm
brite-design-system
municipality-gtm
podium-connector-hubspot
revolver-term-loan-facility
hoa-gtm
finance-team-infra-foundation
working-areas-dashboard
brite-supply-gtm
brite-supply-product-development
strand-smart
go-to-market-data-platform (legacy)
```

Archived repos (7) excluded: `brite-cpq`, `brite-supply-hydrogen`, `campaign-manager`, `creative-process-discovery`, `imagekit-metafield-validator`, `master-inbox`, `serper_tap`.

---

## 2. Option comparison matrix

Three options, scored on seven axes.

| Axis | (a) `gh` CLI via Bash | (b) Official GitHub MCP | (c) No integration |
|---|---|---|---|
| **Auth** | Ambient — every Brite dev has `gh auth login` already; no new flow. | OAuth (works for HTTP MCP on Claude Code — same class as Linear/Context7) **or** PAT via `Authorization: Bearer ${...}` header (header substitution is broken by the BC-5551 bug class — see `memory/gotcha_http_mcp_substitution_broken.md`). OAuth route is viable; PAT route is not. | N/A |
| **Tool surface** | Full `gh` CLI — reads, writes, search, workflows, runs, releases. Shell-native. | ~40+ MCP tools (repos, issues, PRs, actions, code-security, discussions). 29,081 GitHub stars, actively maintained (pushedAt 2026-04-20). Hosted at `https://api.githubcopilot.com/mcp/`. | Zero — Cadence plugin cannot see any GitHub data. |
| **MCP server-budget impact** | 0 slots on any plugin. | +1 slot on the host plugin. If registered in `plugins/cadence/.mcp.json`: Cadence 0→1 of 6. If registered in `plugins/workflows/.mcp.json`: workflows 3→4 of 6. Either path is under the soft cap today, but consumes a slot before a phase issue names a specific consumer. | 0 slots. |
| **Developer friction on first run** | Zero. `gh` is already installed and authed on every Brite dev machine (CLAUDE.md assumes it). | Medium. OAuth popup per dev on first MCP connect. If we ever fall back to PAT, we inherit the EB-style user-level `.mcp.json` onboarding flow — an entire slash command exists (`/marketing:setup-email-bison`) to paper over that friction. | None. |
| **Skill-layer simplicity** | Shell calls in prose. No `mcp__plugin_...` namespace, no `allowed-tools` wildcard for GitHub. `Bash(gh repo view:*)` allowlist entry if we want to bound the surface. | Semantic tool names via `allowed-tools: mcp__plugin_cadence_github__*`. Matches the established pattern in `create-issues`. | Can't reference GitHub data at all. |
| **Failure mode if repo missing** | `gh repo view X` returns nonzero; shell `||` branch handles it. Quiet, easy to distinguish from auth failures via exit-code semantics. | MCP tool error — distinguishable, but requires per-tool error handling in the skill body. | Undetectable — the connectivity check itself cannot run. |
| **Cross-session reliability** | High — `gh` is stable across Claude Code versions; zero MCP-plumbing surface. | High once registered. OAuth refresh is handled by the MCP host the same way Linear's is. PAT fallback inherits the header-substitution bug class. | N/A. |

---

## 3. Per-phase GitHub consumption

What each Cadence phase *actually* reads from GitHub, traced back to the locked orchestration shape in [`docs/designs/cadence-orchestration.md`](../designs/cadence-orchestration.md) and the Phase issue bodies.

| Phase | GitHub data consumed | Source | Fit for `gh` CLI? |
|---|---|---|---|
| Phase 1 — audit ([BC-5759](https://linear.app/brite-nites/issue/BC-5759)) | **None.** Audit is Linear-sourced: cycle metadata, shipped / dropped / carried-over issues, per-assignee rollups. | Linear MCP only | N/A |
| Phase 2 — scope ([BC-5760](https://linear.app/brite-nites/issue/BC-5760)) | **None.** Pre-draft reads prior narrative (`weekly-planning/` text files) + Linear current state + handbook. | File reads + Linear MCP | N/A |
| Phase 3 — housekeeping ([BC-5761](https://linear.app/brite-nites/issue/BC-5761)) | **None.** Writes back to Linear only (cycle assignment, reassignments, milestone renames). | Linear MCP only | N/A |
| Phase 4 — narrative ([BC-5762](https://linear.app/brite-nites/issue/BC-5762)) | **Optional stretch:** shipped-PR color for the Context paragraph ("… and the auth refactor landed in `brite-salesforce#175`"). Not in W15/W16 narratives — the human voice spec doesn't cite PRs. | `gh pr list --state merged --search "merged:>=YYYY-MM-DD" --json title,number,mergedAt` | ✅ one-liner |
| Phase 5 — ops checklist ([BC-5762](https://linear.app/brite-nites/issue/BC-5762)) | **One load-bearing use:** "verify connection to the associated GitHub project for each Linear project" — flag projects whose repo is stale, archived, or missing. | `gh repo view <owner>/<name> --json pushedAt,isArchived` per mapping row | ✅ one-liner |

**The only load-bearing GitHub use across all five phases is the Phase 5 connectivity check.** Phase 4's PR-color is a nice-to-have that doesn't appear in the W15/W16 corpus the voice spec was built from. Phase 1-3 are pure Linear.

---

## 4. Decision

**Adopt option (a): `gh` CLI via Bash. Do not register the GitHub MCP server in `plugins/cadence/.mcp.json`. Do not register it in `plugins/workflows/.mcp.json`.**

### 4.1 Three reasons

1. **MCP budget discipline.** Cadence opens at 0 of 6 MCP slots, and future phase issues may need servers we haven't enumerated (e.g., PDF rendering, voice/TTS, Snowflake for metrics rollup). The `skill-tool-integration-pattern.md` § Tool depth table is explicit: "only add a CLI wrapper when you can name a non-Claude caller." Inverted, the same discipline says don't add an MCP server when the only caller is a single connectivity check + an optional narrative color widget. Burning a slot here would violate the spirit of the per-plugin 5–6 soft cap before any phase issue names a concrete data point that only MCP can express.
2. **Substitution-bug exposure, even if today's OAuth path would sidestep it.** [`memory/gotcha_http_mcp_substitution_broken.md`](../../.claude/projects/.../memory) documents that `${ENV_VAR}` and `${user_config.*}` substitution into HTTP MCP headers is broken in Claude Code v2.1.112 (upstream bugs [#6204](https://github.com/anthropics/claude-code/issues/6204), [#9427](https://github.com/anthropics/claude-code/issues/9427), [#28293](https://github.com/anthropics/claude-code/issues/28293), [#14977](https://github.com/anthropics/claude-code/issues/14977)). GitHub MCP's PAT path lives in that bug class. OAuth works today — but OAuth is one vendor-config change or one MCP host update away from needing header substitution we can't reliably ship. `gh` CLI has zero substitution surface; its failure modes are shell-local.
3. **No phase currently consumes what MCP uniquely adds.** The comparison is not "gh CLI vs MCP for the same workload." It's "gh CLI covers the entire workload" vs "gh CLI covers the entire workload AND we also register MCP for a workload that doesn't exist yet." Adding the server before the need is named creates speculative surface area — a new auth error path to debug, a new integration guide to maintain, a new entry in `validate.sh`. The pattern guide's anti-pattern #4 ("Adding a 6th active MCP server without retiring one") applies in spirit even when we're adding the 2nd.

### 4.2 What ships in `plugins/cadence/.mcp.json`

Phase 1-5 needs that ARE load-bearing, and that BC-5758 scaffold should target (informative — actual scaffolding is BC-5758's job):

```json
{
  "mcpServers": {}
}
```

Cadence consumes `linear-server` via the workflows plugin's registration — the `mcp__plugin_workflows_linear-server__*` tools are accessible from any plugin's skill frontmatter. No Cadence-owned MCP servers are required for Phase 1-3. Phase 4 and 5 use `Bash` + `gh`.

If BC-5758 decides a PDF-rendering MCP ships alongside the scaffold, that goes here — outside BC-5811's scope.

---

## 5. Reject path — deferred scaffold shape (for future reassessment)

This section is a **template**, not a commitment. If the reassessment trigger in § 6 fires, a follow-up PR can execute this scaffolding mechanically without re-deciding fundamentals.

### 5.1 `.mcp.json` delta (if we ever adopt)

Add to `plugins/cadence/.mcp.json`:

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

OAuth flow triggers automatically on first connect, per the GitHub MCP README. No headers needed — same shape as `linear-server`.

### 5.2 `plugins/cadence/tools/integrations/github.md` skeleton

Must conform to the 9-section structure in [`docs/guides/skill-tool-integration-pattern.md`](../guides/skill-tool-integration-pattern.md):

- **Purpose** — "Connectivity check + optional narrative-color PR listing for the Cadence weekly loop."
- **Consumed by** — `plugins/cadence/skills/narrative-writer/` (Phase 4, optional), `plugins/cadence/skills/weekly-ops/` (Phase 5, load-bearing).
- **Auth** — OAuth via Claude Code MCP host. First connect prompts a browser popup. No per-dev secret distribution.
- **Registration** — snippet in § 5.1.
- **Tool inventory** — pin the specific tools the scaffold actually calls (likely `search_repositories`, `get_repository`, `list_pull_requests`) rather than the full ~40+ surface. Do NOT enable `--allow-non-ga-tools`.
- **Rate limits** — GitHub API's 5000 requests/hour authenticated. One `gh`-equivalent call per Linear project per week is ~20 calls, well under budget.
- **Known gotchas** — two to pre-document: (i) private repos need the user's PAT/OAuth scope to include `repo` not just `public_repo`; (ii) archived repos return `isArchived: true` — the skill must branch on that distinct from "missing."
- **Related skills** — primary consumer is `weekly-ops`; alternatives considered and rejected were `gh` CLI (this doc) and no-integration (this doc).
- **Last verified** — ISO date of scaffold.

### 5.3 Skill-body shape (if we ever adopt)

In `plugins/cadence/skills/weekly-ops/SKILL.md`:

```yaml
allowed-tools: mcp__plugin_workflows_linear-server__*, mcp__plugin_cadence_github__*, Read, Write, Glob, Grep
```

Call tools by semantic name only: `search_repositories`, `get_repository`. No URLs, no tokens, no `Bearer` prose — per the pattern guide's 6-item PR checklist.

---

## 6. Reassessment trigger

**Reopen this decision when any Cadence phase issue names a specific GitHub data point that `gh` CLI cannot express in a single-line shell call ergonomically.**

Examples that would flip the decision:

- **Cross-repo CI-status rollup** — "show the red-build count across all 20 mapped repos this cycle" is multiple `gh run list` calls + client-side aggregation; MCP could expose a batched tool. If Phase 5 grows this, adopt.
- **PR review-thread diffing** — "show me the comments that remained unresolved 48h" needs structured access to review threads that `gh api` exposes awkwardly; MCP's semantic tools are cleaner.
- **Branch-protection summaries at scale** — "which repos have outdated CODEOWNERS" is a multi-API-call aggregation MCP may express as one call.
- **Bidirectional Linear↔GitHub mutation** — if Phase 3 housekeeping grows to close PRs based on Linear issue state transitions (currently out of scope), MCP's uniform auth simplifies the write path.

Re-entry test: a downstream phase issue names one of the above (or similar) with a concrete paste of the `gh` command that is "painful" — then a follow-up ADR amends this decision and executes § 5.

---

## 7. Follow-ups

**Policy (approved):** flag mapping holes inline in § 1.4, file no Linear issues pre-emptively. Per-project follow-ups only get filed when a hole indicates real missing infrastructure (not just "this project legitimately has no repo"). Confirmed during BC-5811 Plan checkpoint — the doc itself is the artifact; triage happens during review.

**Candidates for possible follow-up** (human judgement required — not auto-filed):

- **Asset Studio** (§ 1.4) — if this is supposed to be a code project, the repo is missing. Could be `gtm_assets` reuse, a subdirectory of `brite-labs`, or a net-new repo. Worth one `AskUserQuestion`-style ping to Sarah Cullen (project lead).
- **Brite Platform SDK** (§ 1.4) — description claims existing packages. If the repo doesn't exist yet, the project description is ahead of reality.
- **Brite Labs Website** (§ 1.4) — two repos plausibly match; consolidating would clean up the mapping.

None filed by this PR.

---

## 8. Links

- Parent issue: [BC-5811](https://linear.app/brite-nites/issue/BC-5811)
- Cadence plugin design: [`docs/designs/cadence-plugin.md`](../designs/cadence-plugin.md) (BC-5757)
- Cadence orchestration: [`docs/designs/cadence-orchestration.md`](../designs/cadence-orchestration.md) (BC-5810)
- Skill-tool pattern: [`docs/guides/skill-tool-integration-pattern.md`](../guides/skill-tool-integration-pattern.md) (PR #116)
- GitHub MCP server: [github/github-mcp-server](https://github.com/github/github-mcp-server) — 29,081 stars, updated 2026-04-20
- Substitution bug memory: `memory/gotcha_http_mcp_substitution_broken.md`
