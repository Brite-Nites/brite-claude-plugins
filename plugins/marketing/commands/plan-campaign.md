---
description: Scaffold one GTM campaign across all 4 layers — Linear milestone in "Brite GTM" project + 8 standard sub-issues (with up to 2 optional) + plugin docs/campaigns/{entity}/{slug}/manifest.json + Salesforce Campaign via /revops:create-sf-campaign (soft-fail) + Email Bison workspace assignment. Hybrid flag-or-prompt mode — operator can pass --vertical/--persona/--offer (and entity/month/year) explicitly, OR be walked through the missing pieces interactively (one question at a time). Triggers on "plan campaign", "scaffold campaign", "new GTM campaign", "set up campaign", "campaign orchestration", or direct /marketing:plan-campaign invocation.
argument-hint: --vertical <slug> --persona <slug> --offer <slug> [--entity <nites|supply|labs|cross-entity>] [--month <1-12>] [--year <YYYY>] [--launch-date <YYYY-MM-DD>] [--owner-email <email>] [--eb-workspace <emailbison-personal|emailbison-b2b>] [--theme <slug>] [--situation-mining] [--creative-angles] [--dry-run]
allowed-tools: Read, Write, Bash, AskUserQuestion, Skill, mcp__plugin_workflows_linear-server__list_projects, mcp__plugin_workflows_linear-server__list_milestones, mcp__plugin_workflows_linear-server__save_milestone, mcp__plugin_workflows_linear-server__save_issue, mcp__plugin_workflows_linear-server__list_issue_labels, mcp__plugin_workflows_linear-server__create_issue_label, mcp__plugin_revops_salesforce__get_username
---

# /marketing:plan-campaign

> **How this command runs**: When invoked, the model reads this spec and executes each Step (1, 1b, 2, 3, ...) in order using its tool palette (Read, Write, Bash, Skill, the Linear MCP, etc.). There is no separate "runner" or background process — the spec IS the program. To debug a partial run, re-invoke from the failure point with corrected flags or apply hot-patches inline; expect a procedural, multi-turn execution. (Dogfood-surfaced 2026-05-19 BC-8727 / friction-log F2.)

The campaign-scaffolding orchestrator. One invocation creates one campaign across all four layers of Brite's GTM stack:

| Layer | What lands | Source-of-truth |
|---|---|---|
| Plugin filesystem | `docs/campaigns/{entity}/{slug}/manifest.json` | Cross-layer index — the breadcrumb that ties Linear ↔ SF ↔ EB together |
| Linear | 1 project-milestone in "Brite GTM" + 8 standard sub-issues + up to 2 optional sub-issues (blocked-by chained) | Orchestration + work-tracking surface |
| Salesforce | 1 Campaign record (Status=Planned, custom fields populated) | Portfolio reporting surface (rollups, pipeline attribution) |
| Email Bison | Workspace assignment recorded in manifest (NO EB campaign created here) | Sending-execution surface — actual EB campaign is created later by `/marketing:launch-campaign` at sub-issue #6 |

## Inputs / outputs / precedent

**Inputs**: campaign-defining tuple (vertical / persona / offer) plus month-targeting context (entity / month / year / launch-date / theme for cross-entity).

**Outputs**:
- `docs/campaigns/{entity}/{slug}/manifest.json` — fully populated per the schema in Step 7.
- 1 Linear milestone (with labels applied to the 8-10 child issues, not the milestone itself — see § Step 8a).
- 8 standard sub-issues (+ optional #9 Situation Mining for Labs, + optional #10 Creative Angles).
- 1 Salesforce Campaign record (if `/revops:create-sf-campaign` succeeded; null `campaign_id` in manifest if it soft-failed).
- Operator-readable summary printed at Step 11.

**Precedent + sources**:
- `plugins/revops/commands/create-sf-campaign.md` (BC-8717) — the slash command this orchestrator composes for σ3 SF auto-create.
- `plugins/revops/commands/update-sf-campaign-status.md` (BC-8723) — the σ3 status-sync command referenced in the soft-fail reconciliation reminder.
- `plugins/marketing/data/canonicals/` (BC-8718, ADR-016) — the canonicals data layer this orchestrator reads at Step 2.
- `docs/precedents/BC-2707.md` — two-call confirm semantics (turn structure, not vocabulary) used at Step 6.
- `docs/gtm-campaign-orchestration-README.md` § 3.6 — worked example end-to-end (Path A: canonicality-gate-fails-first walk).
- `docs/decisions/012-gtm-campaign-unit.md` (campaign = V × P × O × M), `013-gtm-three-layer-split.md` (Handbook = HOW / Linear = orchestration / Plugin = WHAT), `015-gtm-sigma3-sf-campaign-sync.md` (σ3 SF mapping), `016-gtm-plugin-side-canonicals.md` (canonicals on plugin side), `017-gtm-offer-posture-rename.md` (offer.posture vs offer.status).

## Soft-fail philosophy

The Salesforce auto-create step (Step 8b) is **soft-fail**: any error returned by `/revops:create-sf-campaign` (duplicate slug, missing owner, SF CLI error, invalid slug format) does NOT halt scaffolding. The manifest gets `salesforce.campaign_id: null`, a WARN line is logged, and the operator is told at Step 11 how to reconcile (manual re-run of `/revops:create-sf-campaign --slug=<slug> ...` once the underlying issue is resolved). Linear milestone + sub-issues + plugin manifest must always land — they are the gate that keeps the team able to plan against the campaign even if SF is temporarily unhealthy.

Hard-fail paths (which DO halt scaffolding) are limited to:
- Canonicality validation (Step 2) — invalid vertical/persona/offer tuple. Pointer to `/marketing:new-vertical|new-persona|new-offer` (BC-8725).
- Cross-entity slug missing required `--theme`.
- Operator cancels at the Step 6 two-call confirm gate.

## Non-goals

- Do NOT create the Email Bison campaign — that's `/marketing:launch-campaign` invoked at sub-issue #6.
- Do NOT generate copy — that's `/marketing:email-copywriting` invoked at sub-issue #3.
- Do NOT fill out the brief content (Audience / Messaging / etc.) at scaffold time — the brief is a sub-issue #1 deliverable. This command provides the template SKELETON populated with handbook citations + canonicals metadata; the marketing brief author fills the substantive content at sub-issue #1.
- Do NOT support `--reference <campaign-id>` for cloning — that lives in `/marketing:launch-campaign`; not part of plan-campaign's surface.

---

## Step 1 — Operator invocation + flag parsing + interactive fallback

Parse the invocation arguments. Required flags: `--vertical`, `--persona`, `--offer`. For everything else, derive defaults or prompt one-at-a-time (per [`memory/feedback_one_question_at_a_time.md`](../../../memory/feedback_one_question_at_a_time.md) + [`memory/feedback_interview_chunking.md`](../../../memory/feedback_interview_chunking.md) — present ONE assumption per question, never batch sub-questions a/b/c).

### Flag table

| Flag | Required | Default / resolution |
|---|---|---|
| `--vertical` | yes | If missing, prompt: "Which vertical?" with options sourced from `_manifest.yaml`'s `verticals[]` (offer first 3-4 most-active per CLAUDE.md memory `project_gtm_cohort1_hotels_resorts.md` — fall through to "Other" for the rest). |
| `--persona` | yes | If missing, prompt: "Which persona?" with options sourced from `{vertical}.yaml`'s `personas[].slug`. |
| `--offer` | yes | If missing, prompt: "Which offer?" with options sourced from `{vertical}.yaml`'s `offers[].slug` filtered to `target_personas` containing the chosen `--persona` (or no `target_personas` constraint). |
| `--entity` | no | Auto-detect: read `{vertical}.yaml` `default_entity` key if present (future enhancement; absent in v1 canonicals). If absent, prompt: "Which entity?" with options `[nites, supply, labs, cross-entity]`. |
| `--month` | no | Default to current month: `date +%m` → integer 1-12. Surface in dry-run preview. |
| `--year` | no | Default to current year: `date +%Y` → 4-digit. Surface in dry-run preview. |
| `--launch-date` | no | Default to `{year}-{month:02d}-01` (first day of target month). Surface in dry-run preview. |
| `--owner-email` | no | Resolve via the chain in Step 4. |
| `--eb-workspace` | no | Resolve from entity per the map in Step 4. |
| `--theme` | conditional | Required if `--entity=cross-entity`. Otherwise ignored. |
| `--situation-mining` | no | Enable optional sub-issue #9 (Labs-only — Step 10 enforces). |
| `--creative-angles` | no | Enable optional sub-issue #10. |
| `--dry-run` | no | Print the full preview at Step 5 and exit without writing anything. |

### Interactive prompt example

When `--persona` is missing and the operator picked `municipalities`:

> AskUserQuestion: "Which persona for municipalities?"
> Options: `parks-rec-director` / `city-manager` / `downtown-events-manager` / `Other`

Read the canonical persona slugs DIRECTLY from `plugins/marketing/data/canonicals/municipalities.yaml` `personas[].slug` — do NOT guess from training data. The `Other` option (per `AskUserQuestion` UX) hands control to free-text input; if the operator picks `Other`, validate the typed slug against the canonicals or HARD-FAIL with the `/marketing:new-persona` pointer.

Same pattern for `--offer` (filter by `target_personas` containing the chosen persona).

### Non-interactive mode

If all required flags are provided, skip prompts and proceed directly to Step 1b (parse-time validation).

### Step 1b — Parse-time input validation (HARD-FAIL invariants)

Before any downstream step, validate every operator-controlled flag value. These are mechanical safety invariants — non-interactive invocations skip the Step 1 prompts entirely, so these checks are the only barrier between operator input and shell/MCP/path interpolation. HARD-FAIL on any violation; do NOT auto-sanitize.

| Flag | Validator | HARD-FAIL message on miss |
|---|---|---|
| `--entity` | Must be one of `nites` / `supply` / `labs` / `cross-entity` (closed set; case-sensitive) | `ERROR: --entity must be one of [nites, supply, labs, cross-entity]; got '<value>'. Path-traversal guard.` |
| `--theme` | If `--entity=cross-entity` AND `--theme` is provided, must match `^[a-z0-9]+(-[a-z0-9]+)*$` (strict kebab-case, no leading/trailing/doubled hyphens). Applied here at parse time so the theme value is safe before it flows into slug compute (Step 3.1) and from there into `mkdir`/`Write`/`Skill args`. | `ERROR: --theme must be strict kebab-case (^[a-z0-9]+(-[a-z0-9]+)*$); got '<value>'. Theme flows into slug, filesystem paths, and SF Campaign Name — must be safe for all three surfaces.` |
| `--month` | Integer 1-12 | `ERROR: --month must be 1-12; got '<value>'` |
| `--year` | 4-digit integer 2020-2099 (cap is arbitrary; widen via PR as needed) | `ERROR: --year must be 4-digit 2020-2099; got '<value>'` |
| `--launch-date` | Matches `^\d{4}-\d{2}-\d{2}$` (ISO YYYY-MM-DD format) | `ERROR: --launch-date must be ISO YYYY-MM-DD; got '<value>'` |
| `--owner-email` | If provided, matches `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` | `ERROR: --owner-email failed regex; got '<value>'` |
| `--vertical` / `--persona` / `--offer` | Strict kebab-case `^[a-z0-9]+(-[a-z0-9]+)*$` (canonicality membership checked in Step 2; this is the SHAPE check) | `ERROR: --<flag> must be strict kebab-case; got '<value>'` |
| `--eb-workspace` | If provided, must be one of `emailbison-personal` / `emailbison-b2b` | `ERROR: --eb-workspace must be emailbison-personal or emailbison-b2b; got '<value>'` |

The validator runs unconditionally, regardless of interactive vs non-interactive mode. Interactive prompts in Step 1 use AskUserQuestion which constrains the operator's input to a closed set + Other; the regex on the Other free-text path is the only place where prompt output could otherwise leak into downstream interpolation.

---

## Step 2 — Canonicality validation

Read the canonicals data layer in order; HARD-FAIL on the first miss with a pointer to the appropriate `/marketing:new-*` command.

### 2.1 — Vertical existence

`Read` `plugins/marketing/data/canonicals/_manifest.yaml`. Assert `--vertical` ∈ `verticals[]` (string-equality, kebab-case).

On miss, HARD-FAIL:

```
ERROR: Vertical '<--vertical>' is not in canonicals (plugins/marketing/data/canonicals/_manifest.yaml).
Either correct the slug, OR add it via /marketing:new-vertical (BC-8725).
Current canonical verticals: <comma-separated verticals[]>
```

### 2.2 — Persona existence within vertical

`Read` `plugins/marketing/data/canonicals/{vertical}.yaml` ONCE and cache the parsed content as `<vertical-doc>` for reuse across Steps 2.3, 2.4, and 8a.3 — every downstream slot-substitution + membership-check needs this file, so a single Read tool invocation per plan-campaign run is the budget.

Assert `--persona` ∈ `personas[].slug`.

On miss, HARD-FAIL. When `personas[]` is empty, render `<empty>` for the list (do NOT emit a trailing empty string):

```
ERROR: Persona '<--persona>' is not defined for vertical '<--vertical>' in {vertical}.yaml.
Either correct the slug, OR add it via /marketing:new-persona (BC-8725).
If BC-8725 is not yet shipped, hand-edit plugins/marketing/data/canonicals/{vertical}.yaml per the schema
(append to personas[] with slug + display + titles[]) and run `python3 plugins/marketing/scripts/lint_canonicals.py`
to verify before re-invoking. See BC-8727 friction-log F1.
Current canonical personas: <comma-separated personas[].slug, OR "<empty — vertical has no personas; Path A required>">
```

### 2.3 — Offer existence within vertical

In the same `{vertical}.yaml` content from 2.2, assert `--offer` ∈ `offers[].slug`.

On miss, HARD-FAIL. When `offers[]` is empty, render `<empty>` for the list (do NOT emit a trailing empty string):

```
ERROR: Offer '<--offer>' is not defined for vertical '<--vertical>' in {vertical}.yaml.
Either correct the slug, OR add it via /marketing:new-offer (BC-8725).
If BC-8725 is not yet shipped, hand-edit plugins/marketing/data/canonicals/{vertical}.yaml per the schema
(append to offers[] with slug + display + posture + status + target_personas) and re-run lint_canonicals.py.
Current canonical offers: <comma-separated offers[].slug, OR "<empty — vertical has no offers; Path A required>">
```

### 2.4 — Persona ↔ offer compatibility (runtime target_personas check)

For the matched offer, inspect `offer.target_personas[]`. If non-empty, assert `--persona` ∈ `target_personas`.

On miss, HARD-FAIL:

```
ERROR: Offer '<--offer>' targets personas [<target_personas>] — '<--persona>' is not in this list.
Either pick a valid persona for this offer (options above), OR update {vertical}.yaml's
offers[<--offer>].target_personas via PR.
```

The schema's `additionalProperties:false` (enforced by `scripts/lint_canonicals.py`) guarantees the file shape is well-formed; this runtime check covers the SEMANTIC constraint that a campaign's persona-offer pairing match the canonical's targeting model.

Empty or absent `target_personas` = "all personas in this vertical are valid for this offer" — skip the membership check.

---

## Step 3 — Slug compute + collision check

### 3.1 — Compute slug

**Standard slug**:

```
{vertical}-{persona}-{offer}-fy{YY}-m{MM}
```

Where `YY = year % 100` (zero-padded if needed) and `MM = month` zero-padded to 2 digits. Example: `municipalities-parks-rec-director-parks-bond-fy26-m05`.

**Cross-entity exception**: when `--entity=cross-entity`, slug is:

```
cross-entity-{theme}-fy{YY}-m{MM}
```

Where `--theme` is required. The strict kebab-case shape was already validated at Step 1b; here we only check presence:

```
ERROR: --entity=cross-entity requires --theme (e.g. --theme=america-250).
Cross-entity campaigns omit the (vertical, persona, offer) triple in favor of a campaign-defining
theme slug. See docs/gtm-campaign-orchestration-README.md § 3.5 (cross-entity convention) +
docs/decisions/012-gtm-campaign-unit.md.
```

### 3.2 — Validate slug regex

Assert slug matches `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` (same regex as `/revops:create-sf-campaign`'s Phase 1). On mismatch, HARD-FAIL — a non-matching slug means one of the input slugs contains an illegal character that the canonicals lint should have caught upstream; surface as a bug, not an operator error:

```
ERROR: Computed slug '<slug>' does not match canonical regex ^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$.
This is upstream-canonicals-lint territory — file an issue against plugins/marketing/data/canonicals/.
```

### 3.3 — Collision check via Linear

Look up the "Brite GTM" project (cached for re-use in Steps 8a + 9.0):

```
mcp__plugin_workflows_linear-server__list_projects(query="Brite GTM")
```

From the response, capture three values (the response shape includes `id`, `url`, and `teams[]`):

- `<gtm-project-id>` ← `projects[0].id`
- `<project-url>` ← `projects[0].url` (used as the milestone-pointer URL — see Step 8a.5 F8 hot-patch)
- `<brite-company-team-id>` ← `projects[0].teams[]` filtered to `name === "Brite Company"`, then `.id` (used in Step 8a.6 for the `teamId` arg on `create_issue_label`, which requires a UUID. § 9.0's container-issue + Step 9.1's sub-issue creates use `team: "Brite Company"` by-name on `save_issue` and do NOT need the captured UUID.)

If `list_projects` returns 0 matches, HARD-FAIL — the "Brite GTM" project is a Phase 0 dependency (BC-8712 Task 0) and is meant to exist before plan-campaign ships. If `Brite Company` is absent from `teams[]`, HARD-FAIL — the project must be cross-team-shared with Brite Company (the team that owns all GTM sub-issues).

Then check for slug collision. Note the MCP-tool shape uses `project` (not `projectId`) and accepts NO `query` filter as of 2026-05-19 (BC-8727 friction-log F5/F6 — verified shape):

```
mcp__plugin_workflows_linear-server__list_milestones(project=<gtm-project-id>)
```

If the response exceeds the tool-response token limit (~69KB / 200+ milestones), the wrapper writes the full response to a temp file and returns the path. In that case, grep the temp file for `"name":"<slug>"` to detect collision. Otherwise iterate the returned `milestones[]` array and compare `name === <slug>`.

If any returned milestone's `name === <slug>`, enter the collision-resolution loop:

```
loop attempt = 2, 3, 4, ..., 9:
  candidate = <base-slug>-v<attempt>
  re-call list_milestones(project=<gtm-project-id>)  # same shape as above — no query filter; re-grep the response (or temp file) for "name":"<candidate>"
  if no collision:
    prompt operator with AskUserQuestion:
      Question: "Slug collision detected. Use candidate '<candidate>' instead?"
      Options: ["Use <candidate>", "Cancel scaffold"]
    if operator picks "Use <candidate>": <slug> := <candidate>; exit loop
    if operator picks "Cancel scaffold": halt with exit 0 and no writes
  if collision: continue to next attempt
end loop

if loop exhausted without resolution (attempt > 9):
  HARD-FAIL:
    ERROR: Slug '<base-slug>' has 9+ same-month variants (v2..v9 all taken).
    This indicates a slug-naming or month-targeting bug in upstream invocation.
    Either pass an explicit --slug override, OR re-scope to a different month/persona.
```

Per [ADR-016] + the design doc O5: collision auto-suffixing is operator-explicit (NOT silent auto-increment) — every candidate requires the prompt. The loop prompts ONCE per non-colliding candidate (not at every attempt), keeping operator UX bounded.

The `-v9` cap is a sanity bound; a campaign with 10+ same-month variants almost certainly indicates an upstream slug-generation bug, not a legitimate scheduling pattern.

---

## Step 4 — Resolve entity ↔ Email Bison workspace + owner email

### 4.1 — Entity → EB workspace map

| `--entity` | EB workspace |
|---|---|
| `nites` | `emailbison-personal` |
| `supply` | `emailbison-b2b` |
| `labs` | `emailbison-b2b` |
| `cross-entity` | (operator picks via `--eb-workspace` flag OR prompt) |

If `--eb-workspace` was passed explicitly, use it (the operator override path — useful for dogfood + staging runs that intentionally cross-map). If `--entity=cross-entity` and `--eb-workspace` is missing, prompt:

> AskUserQuestion: "Cross-entity campaign — which EB workspace?"
> Options: `emailbison-b2b` / `emailbison-personal`

Store the resolved workspace as `<eb-workspace>` for Step 7 (manifest write).

### 4.2 — Owner email resolution chain

Resolve `<owner-email>` in order; first success wins. The explicit-flag path is checked FIRST because operators who pass `--owner-email` know what they want, and the SF probe is a network round-trip we should skip when the answer is already provided.

Define the email regex once for reuse below: `EMAIL_REGEX = ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`. EVERY path that yields a candidate `<owner-email>` MUST re-apply EMAIL_REGEX before accepting the value — defense-in-depth against an upstream resolution returning a malformed string that then flows into the Step 8b `Skill` args.

1. **Explicit `--owner-email` flag**: if provided AND matches EMAIL_REGEX, use it. Skip the rest of the chain. (Step 1b already validated this regex; the re-check here is the single-point-of-trust for downstream Steps.)
2. **SF authed username probe** (only when `--owner-email` was NOT provided): call `mcp__plugin_revops_salesforce__get_username` (returns `{username, version, ...}`). If the returned `username` matches EMAIL_REGEX (most SF usernames are emails), use it. If the username is set but does NOT match the regex, skip silently to (3) — do NOT pass a non-email string downstream.
3. **AskUserQuestion fallback**:
   > "Resolve SF Campaign owner email."
   > Options: `marketingadmin@britenites.com (GTM service account)` / `<the resolved authed SF user from step 2 if available, else skip this option>` / `Other`

   If the operator selects the GTM service-account option, that literal value already matches EMAIL_REGEX (verified at spec-write time). If the operator selects `Other`, validate the typed value against EMAIL_REGEX BEFORE accepting it — on regex miss, re-prompt with: "That value isn't a valid email format. Try again or cancel." The `Other` free-text path is the highest-risk surface in this chain (per [`memory/gotcha_askuserquestion_no_free_text.md`](../../../memory/gotcha_askuserquestion_no_free_text.md) — `Other` IS the free-text escape hatch).

4. **Final pre-Step-8b guard**: regardless of which path produced `<owner-email>`, re-apply EMAIL_REGEX one more time at the boundary into the `Skill` invocation. On miss, HARD-FAIL with: `ERROR: <owner-email> failed final email-format guard before /revops:create-sf-campaign invocation. Internal bug — please file an issue.` This guard should never fire if paths 1-3 are correct; it exists as a tripwire for future regressions.

The default option `marketingadmin@britenites.com` is the GTM service account that owns all SF Campaigns by convention (per `docs/gtm-campaign-orchestration-README.md` § 3.6.7). The `Other` AskUserQuestion fallback gives operators a free-text override for one-off cases.

Store the resolved value as `<owner-email>` for Step 8b's `/revops:create-sf-campaign --owner-email=<owner-email>` invocation.

---

## Step 5 — Dry-run preview

Print the operator-readable plan. Use this format (or a close variant — readability matters):

```
=================================================================
/marketing:plan-campaign — Dry-run preview
=================================================================

  Slug:           <slug>
  Entity:         <entity>
  Vertical:       <vertical>           (canonical)
  Persona:        <persona>            (canonical)
  Offer:          <offer>              (canonical, posture=<offer.posture>, status=<offer.status>)
  Year / Month:   <year> / <month:02d>
  Launch date:    <launch-date>        (default = first day of month if not provided)
  EB workspace:   <eb-workspace>       (entity-mapped)
  Owner email:    <owner-email>        (resolved via <method>: get_username | --owner-email | AskUserQuestion)

  Plugin manifest:
    Path:         docs/campaigns/<entity>/<slug>/manifest.json
    Schema:       v1 (12 top-level keys per Step 7)

  Linear milestone:
    Project:      "Brite GTM" (<gtm-project-id>)
    Name:         <slug>
    Description:  Filled brief template (8 sections per D5; see Step 8a)
    Labels:       slug:<slug>, entity:<entity>, vertical:<vertical>, persona:<persona>,
                  offer:<offer>, year:<year>, month:<month:02d>, status:planning
                  (applied to each sub-issue, not the milestone — see Step 8a notes)

  Salesforce auto-create (via /revops:create-sf-campaign --dry-run):
    <output of /revops:create-sf-campaign --dry-run with the same args>

  Sub-issues to create (8 standard + N optional):
    #1  Brief approved                              [gate, blocks #2-#8]
    #2  Target list built                           [blocks #3; expects /marketing:list-building]
    #3  Copy written + approved                     [blocks #4; expects /marketing:email-copywriting]
    #4  Salesforce setup                            [blocks #5; post-σ3 reconciliation]
    #5  Pre-launch QA                               [blocks #6]
    #6  Launch executed                             [blocks #7; expects /marketing:launch-campaign]
    #7  Active management — weekly reviews          [blocks #8]
    #8  Campaign closed + debrief                   [terminal; expects /marketing:campaign-debrief]
    #9  Situation Mining            <-- ONLY IF --situation-mining flag set AND entity=labs
    #10 Creative Angles             <-- ONLY IF --creative-angles flag set

=================================================================
```

To produce the SF Campaign payload preview, invoke the sibling `/revops:create-sf-campaign --dry-run` via the `Skill` tool with the same flag values that the real Step 8b invocation will use; capture the single-line JSON it emits and pretty-print it under "Salesforce auto-create" above.

**If `--dry-run` was passed to plan-campaign, exit here.** Do not proceed to Step 6. Print one final line: `Dry-run complete. No writes performed.`

---

## Step 6 — Two-call confirm gate (per BC-2707)

This is the load-bearing safety gate before any writes. Per `docs/precedents/BC-2707.md`: the gate enforces **turn structure** (operator must respond between any two consequential writes), NOT vocabulary (any clear affirmative — "yes" / "approved" / "go ahead" / "proceed" / "do it" — counts).

Issue the gate via `AskUserQuestion`:

> "Proceed with campaign scaffold?"
> Options: `Proceed — write all 4 layers` / `Cancel`

Treat clear affirmatives as proceed. Ambiguous responses ("maybe", silence, off-topic) → re-prompt with the same question and a tightened "Yes or No?" framing. The anti-pattern this gate blocks is the orchestrator issuing the Linear + SF + manifest writes in the same turn without a real operator turn between this question and the Step 7 write.

On `Cancel`, halt cleanly with no writes and re-print the Step 5 dry-run preview block (without the leading "Dry-run preview" header — adapt to "Cancelled — would have created:"). This gives the operator the full plan they declined, in case they want to copy-paste flags for a corrected re-run.

---

## Step 7 — Write plugin dir + manifest.json

After confirm, create the campaign directory:

```bash
mkdir -p "docs/campaigns/<entity>/<slug>"
```

Then `Write` `docs/campaigns/<entity>/<slug>/manifest.json` with the FULL schema:

```json
{
  "schema_version": 1,
  "slug": "<slug>",
  "entity": "<entity>",
  "vertical": "<vertical>",
  "persona": "<persona>",
  "offer": "<offer>",
  "year": <year>,
  "month": <month>,
  "linear": {
    "milestone_id": null,
    "milestone_url": null,
    "project": "Brite GTM"
  },
  "salesforce": {
    "campaign_id": null,
    "campaign_name": "<slug>"
  },
  "email_bison": {
    "workspace": "<eb-workspace>",
    "campaign_id": null,
    "campaign_name": "<slug>",
    "launched_at": null
  },
  "created_at": "<ISO 8601 UTC timestamp from `date -u +%Y-%m-%dT%H:%M:%SZ`>",
  "scaffolded_by": "/marketing:plan-campaign"
}
```

Initial state: `linear.milestone_id` and `salesforce.campaign_id` are `null`. These get backfilled in Step 8a + Step 8b respectively via `Read` → mutate JSON → `Write`.

For cross-entity campaigns, `vertical` / `persona` / `offer` are still recorded for the (vertical, persona, offer) triple if provided (cross-entity campaigns may still have them); otherwise set to `null` (NOT empty string — empty string would break downstream parsers that distinguish "absent" from "empty").

### 7.1 — Confirm filesystem state

Run `Bash`:

```bash
ls -la "docs/campaigns/<entity>/<slug>/" && cat "docs/campaigns/<entity>/<slug>/manifest.json" | head -5
```

To prove the write landed. Do NOT `git add` or `git commit` — that's `/workflows:ship`.

---

## Step 8 — Write Linear milestone + Salesforce Campaign

Sub-steps 8a and 8b run in order. 8a (Linear milestone create) is the hard-gate write — it MUST succeed before plan-campaign considers itself successful. 8b (SF Campaign auto-create) is the soft-fail write per the philosophy section above.

### Step 8a — Linear milestone create + brief template

#### 8a.1 — Reuse Brite GTM project ID

Use the `<gtm-project-id>` cached from Step 3.3. If somehow not cached, re-look-up via `list_projects(query="Brite GTM")`.

#### 8a.2 — Fetch the brief template

The brief template lives in the handbook at `marketing/go-to-market/templates/campaign-brief-template.md`. Fetch it at scaffold time:

```bash
gh api repos/brite-nites/handbook/contents/marketing/go-to-market/templates/campaign-brief-template.md \
  -H "Accept: application/vnd.github.v3.raw" 2>/dev/null
```

If `gh api` fails (missing auth, file not found, network error), fall back to the inline template in Step 8a.4 below.

**Slot-availability check** ([BC-10654](https://linear.app/brite-nites/issue/BC-10654), 2026-05-22): the canonical handbook template carries the 14 `{{slot}}` tokens enumerated in Step 8a.3. The detection probe below remains a backward-compat shim for older handbook checkouts pinned pre-BC-10654 — substituting against an un-slotted template silently no-ops every slot.

Detection: `grep -c '{{slug}}' <(echo "$brief_template")` returns 0 → use inline fallback at Step 8a.4. ≥1 → use handbook template + substitution map at Step 8a.3.

Capture the template body as `<brief-template>`.

#### 8a.3 — Slot-substitute the template

In `<brief-template>`, replace these slots (literal string-replace, in order):

| Slot | Value |
|---|---|
| `{{slug}}` | `<slug>` |
| `{{entity}}` | `<entity>` |
| `{{vertical}}` | `<vertical>` (canonical slug, kebab-case) |
| `{{vertical_display}}` | `<vertical>.display` from `{vertical}.yaml` |
| `{{persona}}` | `<persona>` (canonical slug) |
| `{{persona_display}}` | the matched persona's `display` from `{vertical}.yaml` |
| `{{persona_titles}}` | comma-joined `personas[<persona>].titles[]` from `{vertical}.yaml` |
| `{{offer}}` | `<offer>` (canonical slug) |
| `{{offer_display}}` | the matched offer's `display` from `{vertical}.yaml` |
| `{{offer_posture}}` | `offer.posture` from `{vertical}.yaml` (one of knowledge/free-asset/pilot/risk-reversal) |
| `{{launch_date}}` | `<launch-date>` |
| `{{owner_email}}` | `<owner-email>` |
| `{{year}}` | `<year>` |
| `{{month_display}}` | `<month>` formatted as the full month name + year (e.g. "May 2026"). One-shot derivation via Python (portable across macOS/Linux; sidesteps BSD-vs-GNU `date` divergence + locale dependence): `python3 -c "import datetime; print(datetime.date(<year>, <month>, 1).strftime('%B %Y'))"`. `<year>` and `<month>` are pre-validated integers per Step 1b — safe to interpolate. |
| `{{eb_workspace}}` | `<eb-workspace>` resolved at Step 4.1 (`emailbison-personal` for nites, `emailbison-b2b` for supply/labs, operator-picked for cross-entity) |

Unsubstituted slots (slot present in template but no value in this table) remain literally `{{slot_name}}` for the brief author to fill at sub-issue #1.

The handbook template at `marketing/go-to-market/templates/campaign-brief-template.md` references 14 of the 15 slots above (`{{year}}` is unused — redundant with `{{month_display}}`'s "Month Year" rendering). Slot names are load-bearing: the handbook side and this substitution map MUST stay in lockstep. Any addition or rename here requires a paired handbook PR landing first.

#### 8a.4 — Inline fallback brief template

When `gh api` fails, use this 8-section skeleton in place of the handbook template. Marker `<!-- OPERATOR-FILL -->` flags content the marketing brief author authors at sub-issue #1.

```markdown
# Campaign brief — {{slug}}

> Generated by `/marketing:plan-campaign` from the inline fallback template (handbook fetch failed OR pre-BC-10654 handbook pin lacking slot placeholders).
> Backfill from `handbook@main:marketing/go-to-market/templates/campaign-brief-template.md` if needed.

## 1. Overview

- **Entity**: {{entity}}
- **Vertical**: {{vertical_display}} ({{vertical}})
- **Persona**: {{persona_display}} — title cascade: {{persona_titles}}
- **Offer**: {{offer_display}} ({{offer}}) — posture: {{offer_posture}}
- **Launch date**: {{launch_date}}
- **Owner**: {{owner_email}}
- **Month**: {{month_display}}

## 2. Goals

<!-- OPERATOR-FILL: what does this campaign aim to achieve? Reference offer page goals + handbook ICP success metrics. -->

## 3. Audience

- **Canonical persona**: {{persona}} (display: {{persona_display}})
- **Title cascade**: {{persona_titles}}
- **Vertical ICP**: <!-- OPERATOR-FILL: paste/summarize from handbook/{{vertical}}/README.md ICP section -->

## 4. Messaging

<!-- OPERATOR-FILL: 1-2 angle hypotheses from /marketing:creative-angles (sub-issue #10 if --creative-angles enabled) + offer page value props -->

## 5. Channels

- **Primary**: cold email (Email Bison workspace `{{eb_workspace}}`)
- **Secondary**: <!-- OPERATOR-FILL: e.g. LinkedIn, paid retargeting -->

## 6. Assets

<!-- OPERATOR-FILL: deliverable spec, sample brief PDF, landing-page link, etc. -->

## 7. Budget

<!-- OPERATOR-FILL: $-spend + FTE-time estimates -->

## 8. Success metrics

<!-- OPERATOR-FILL: open rate / reply rate / acceptance rate / conversion-to-next-stage targets -->

---

**Sub-issue chain** (created at scaffold; tracked in Linear):

1. Brief approved (this doc; gate)
2. Target list built
3. Copy written + approved
4. Salesforce setup
5. Pre-launch QA
6. Launch executed
7. Active management — weekly reviews
8. Campaign closed + debrief
```

The fallback is intentionally minimal — the goal is to ensure the milestone always has a usable description, not to replicate the full handbook template.

#### 8a.5 — Create the milestone

Call:

```
mcp__plugin_workflows_linear-server__save_milestone(
  projectId=<gtm-project-id>,
  name=<slug>,
  description=<substituted-brief-body>
)
```

Capture the returned `id` into `<milestone-id>`. The MCP response shape does NOT include a `url` field (BC-8727 friction-log F8 — verified 2026-05-19). Use the `<project-url>` already captured at Step 3.3 as the milestone pointer (the operator clicks through to the milestone from the project view), and bind it as an alias so downstream sub-steps (§ 9.0 container description, § 9.0 rollback, Step 11 summary, Step 11.3 hand-off) read naturally:

```
<milestone-url> := <project-url>  # alias — same string; "milestone-url" framing kept for operator semantic clarity downstream
```

A more specific deep-link format (e.g. with `?selectedMilestone=<id>` or fragment) MAY work but is unverified across Linear UI versions — defer to the project URL as the safe canonical pointer.

Update `manifest.json`:

- `linear.milestone_id` ← `<milestone-id>`
- `linear.milestone_url` ← `<project-url>` (until Linear MCP exposes a per-milestone URL)

via `Read` → JSON-mutate → `Write` (atomic per-file rewrite — Edit's not available for JSON nesting at the depth we need without risk).

#### 8a.6 — Label-existence pre-check + create-on-miss

Linear's project-milestone API does NOT accept labels (verified BC-8718 era + observed in `mcp__plugin_workflows_linear-server__save_milestone` shape). The 8-label set (`slug:<slug>`, `entity:<entity>`, `vertical:<vertical>`, `persona:<persona>`, `offer:<offer>`, `year:<year>`, `month:<month:02d>`, `status:planning`) gets applied to each child sub-issue in Step 9 (sub-issues DO take labels via `save_issue`).

**The same 8-label set is the canonical CONSTANT for this orchestrator.** Whenever you see "the 8 labels", "the label set", or label-applying logic referenced from Step 9 / Step 10 / dry-run preview, the membership IS exactly these 8: `slug:<slug>`, `entity:<entity>`, `vertical:<vertical>`, `persona:<persona>`, `offer:<offer>`, `year:<year>`, `month:<month:02d>`, `status:planning`. Drift between this enumeration and Step 9's `labels:` field is a defect — the contract test at `plugins/marketing/tests/test_plan_campaign_contracts.py` verifies the two stay in lockstep.

Before Step 9, ensure all 8 label values exist as `IssueLabel` records in the Brite Company team.

**Filtered lookup (BC-8727 dogfood-verified, 2026-05-19, friction-log F10)**: the Linear MCP `list_issue_labels` accepts a `name:` filter param. Use it per-label to cap each call's response size. Use the `<brite-company-team-id>` captured at Step 3.3 from the project's `teams[]` array:

```
for label_name in [slug:<slug>, entity:<entity>, vertical:<vertical>, persona:<persona>,
                    offer:<offer>, year:<year>, month:<month:02d>, status:planning]:
  result = mcp__plugin_workflows_linear-server__list_issue_labels(team="Brite Company", name=label_name)
  if result.labels is empty:
    mcp__plugin_workflows_linear-server__create_issue_label(name=label_name,
                                                             teamId=<brite-company-team-id>)
```

This issues at most 8 list calls + up to 8 create calls = 16 MCP round-trips worst-case (every label missing — i.e. first-ever campaign). Subsequent campaigns hit fewer create branches as the workspace's fixed-prefix label set accumulates.

**Tradeoff note** (per perf-reviewer 2026-05-19): although call count rises vs an unfiltered dump (16 vs 9 worst-case), each filtered call returns O(1) payload — the unfiltered alternative grows O(workspace_labels) and at ~1,600 labels hits the tool-response token cap, triggering the temp-file fallback path. Filtered lookup wins on both context budget + tail latency.

**Pre-filtered alternative** (deferred): when most labels are static across campaigns (`entity:`, `vertical:`, `persona:`, `offer:`, `year:`, `month:`, `status:`), a cached canonical-label set per Brite Company team — refreshed weekly — could collapse 8 list calls to 0. Out of v1 scope; track if profiling shows label pre-check is a measurable hot spot.

Both `list_issue_labels` and `create_issue_label` are in `allowed-tools` per the frontmatter; no operator prompt is required. The step is idempotent (no-op if all 8 already exist).

---

### Step 8b — Salesforce Campaign auto-create (σ3) via `/revops:create-sf-campaign`

Invoke the sibling slash command via the `Skill` tool. This is the BC-8717 respec composition pattern — `/marketing:plan-campaign` does NOT directly call any `mcp__plugin_revops_salesforce__*` write tool (no such write tools exist for Campaign).

```
Skill(
  skill: "revops:create-sf-campaign",
  args: "--slug=<slug> --entity=<entity> --vertical=<vertical> --persona=<persona> --offer=<offer> --year=<year> --month=<month> --owner-email=<owner-email> --launch-date=<launch-date>"
)
```

**Target-org behavior** (BC-8727 friction-log F11, 2026-05-19): the Skill invocation does NOT pass `--target-org` — it relies on the sibling's default of `brite-prod`. In dev environments where `~/.sf/config.json`'s default differs (e.g. `marketing-claude-prod`), the sibling's SOQL calls will hit the operator's session default instead of `brite-prod`, surfacing as `sf_cli_error` per Phase 2/3 (which the soft-fail philosophy handles cleanly). Operators in mixed-org envs should either (a) run `sf config set target-org brite-prod` before invoking, OR (b) pass `--target-org=brite-prod` explicitly by modifying this Skill args string at invocation time. Future v2 of this orchestrator may auto-resolve via `get_username` and propagate; out of v1 scope.

The skill emits a single-line JSON object on stdout per its `Phase 7` / `Phase 6` contracts (success or error).

#### 8b.1 — Parse the response

Extract the JSON from the skill's output. Branch on the presence of `error` / `warning`:

**Success shape** (no `error` key):

```json
{"campaign_id":"701Xx00000ABCDE","campaign_url":"https://britenites.lightning.force.com/lightning/r/Campaign/701Xx00000ABCDE/view","campaign_name":"<slug>"}
```

→ Update manifest:
- `salesforce.campaign_id` ← `campaign_id`
- `salesforce.campaign_name` is already set to `<slug>` — no change.

Continue to Step 9.

**Soft-fail error shapes** (`{"error":"<kind>", ...}`):

| Error kind | Manifest action | Step 11 reminder | Notes |
|---|---|---|---|
| `duplicate_slug` | `salesforce.campaign_id` ← `existing_id` from error payload | INFO line: "SF Campaign for `<slug>` already exists (idempotent re-run); reusing existing_id." | Treat as success. The slug-collision check in Step 3 caught new ones; this is for the case where the SF record was created in a prior partial run that didn't update the manifest. |
| `missing_owner` | `salesforce.campaign_id` ← `null` | WARN: "SF auto-create failed: `<owner-email>` is not an active SF user. Reconcile via `/revops:create-sf-campaign --slug=<slug> --owner-email=<corrected-email> ...` once owner is provisioned." | |
| `sf_cli_error` | `salesforce.campaign_id` ← `null` | WARN: "SF auto-create failed: SF CLI error. Detail: `<error.detail>`. Common causes: missing `Substatus__c` field deploy (BC-8713), permset gap, FLS on custom field. Reconcile via `/revops:create-sf-campaign ...` after resolving." | |
| `invalid_slug_format` | `salesforce.campaign_id` ← `null` | WARN: "SF auto-create rejected slug `<slug>` as invalid format. This should have been caught upstream — file an issue against canonicals lint." | Sanity-check; shouldn't happen given Step 3.2's regex pre-check. |
| `missing_required_flag` | `salesforce.campaign_id` ← `null` | WARN: "SF auto-create missing required flag `<flag>`. This is an orchestrator bug — file an issue against plan-campaign." | Internal contract failure; should never fire if Step 4 resolved `<owner-email>` correctly. |
| **`<any other error kind>`** (unknown future kind added by /revops:create-sf-campaign) | `salesforce.campaign_id` ← `null` | WARN: "SF auto-create returned unknown error kind `<error.error>`. Manifest gets null campaign_id; reconcile manually via `/revops:create-sf-campaign` after diagnosing. Update plan-campaign's error catalog to handle this kind explicitly in a follow-up PR." | Default branch — prevents silent no-op when sibling adds new error kinds. The canonical kind list lives at `plugins/revops/commands/create-sf-campaign.md` § "Error path catalog"; this orchestrator's table is downstream-consumer text that may drift. The default branch ensures behavior remains soft-fail even on drift. |

Per the soft-fail philosophy: even on these errors, **continue to Step 9** (sub-issues still get created; the orchestrator's job is to scaffold the Linear surface even when SF is temporarily unhealthy).

#### 8b.2 — Persist the manifest update

Same `Read` → JSON-mutate → `Write` pattern as Step 8a.5.

---

## Step 9 — Create 8 standard sub-issues with blockedBy chain

For each of the 8 sub-issues, call `save_issue` with:

- `team`: "Brite Company"
- `title`: as in the table below
- `description`: per the per-issue spec below
- `parentId`: see § 9.0 below (resolved at impl time)
- `projectId`: `<gtm-project-id>`
- `projectMilestoneId`: `<milestone-id>` from Step 8a
- `labels`: the 8-label set from § Step 8a.6 (`slug:<slug>`, `entity:<entity>`, `vertical:<vertical>`, `persona:<persona>`, `offer:<offer>`, `year:<year>`, `month:<month:02d>`, `status:planning`)
- `assignee`: omit (sub-issues are assigned at sub-issue start time, not scaffold time)
- `dueDate`: per the schedule (back-filled from `<launch-date>` — see per-issue spec)

After all 8 creates succeed, do a second pass to wire `blockedBy` relations. The Linear MCP `save_issue` shape for the second pass is **MINIMAL** — `save_issue(id=<sub-issue-id>, blockedBy=[<id>])` ONLY. The field is `blockedBy` (plural, array of issue IDs/identifiers; append-only per MCP schema), NOT `blockedById`.

**DOGFOOD-VERIFIED 2026-05-19 (BC-8727 friction-log F15)**: the minimal partial update is SAFE — labels, descriptions, parentId, projectMilestone all preserved on the second pass. Spec's earlier worry about merge-vs-replace blanking is unfounded at this MCP version. Keep the two-pass shape for robustness (single-pass would require `blockedBy` to accept forward-references to not-yet-created IDs in the same batch — untested and unlikely).

### 9.0 — `parentId` resolution: container-issue pattern

Linear's project-milestones are project-scoped, NOT issue-scoped — they don't accept child issues directly. The 8 sub-issues need an issue parent. Use the **container-issue pattern** (this orchestrator-level design decision should be cross-referenced from `docs/decisions/013-gtm-three-layer-split.md` or promoted to a dedicated ADR when the second consumer adopts it):

1. Create a "Container" parent issue first via `save_issue`:
   - `team`: "Brite Company"
   - `title`: `<slug>` (matches milestone name)
   - `description`: link to `<milestone-url>` + brief "campaign rollup — see milestone for brief content" pointer
   - `projectId`: `<gtm-project-id>`
   - `projectMilestoneId`: `<milestone-id>`
   - `labels`: the 8-label set (Step 8a.6)
2. Capture the returned issue ID as `<container-issue-id>`.
3. Pass `parentId: <container-issue-id>` on every subsequent sub-issue `save_issue` call in § 9.1.

Rationale: gives the marketing operator a single "campaign" issue to track in their Linear inbox + a clean parent → 8-children tree that aligns with the worked example in README §3.6. If `save_issue` rejects the container-issue + `projectMilestoneId` combo at dogfood (BC-8727):

1. HALT before creating the 8 sub-issues.
2. Surface the partial state to the operator: "Container-issue create failed. Linear milestone `<milestone-url>` was created at Step 8a; manifest.json was written at Step 7. To clean up: delete the milestone via Linear UI, then delete `docs/campaigns/<entity>/<slug>/` and re-invoke plan-campaign once the underlying issue is resolved. Do NOT proceed manually with a flat structure."
3. File a follow-up issue tracking the Linear MCP-shape gap.

Explicit rollback guidance prevents the orchestrator from leaving an orphan milestone + manifest hanging in inconsistent state.

### 9.1 — Sub-issue specs

For each row below, the description ALWAYS includes: (a) the handbook citation, (b) the expected plugin command, (c) the sub-issue role (1-2 sentences).

#### #1 — Brief approved (gate)

- **Title**: `Brief approved`
- **Description**:
  > Marketing brief author finalizes the brief in this milestone's description. GTM lead reviewer approves. Closes when the brief is approved.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/templates/campaign-brief-template.md`
  > **Sub-issue role**: gate — blocks all downstream work. Per [D5](../../docs/decisions/) the brief template is 8 sections; the marketing brief author owns sections 2-8 content.
  > **Expected plugin command**: none directly; brief is edited in Linear milestone description.
- **dueDate**: `<launch-date> - 21 days` (T-21d per README § 3.6.5).
- **blocks**: #2, #3, #4, #5, #6, #7, #8 (and #9, #10 if created)

#### #2 — Target list built

- **Title**: `Target list built`
- **Description**:
  > Outbound operator builds the enriched lead CSV for this campaign — typically via `/marketing:list-building` (which assumes a dbt audience view exists for this canonical persona+offer combo) OR `/marketing:tam-mapping` (if the TAM doesn't exist yet — Phase 1 source discovery → Phase 7 enrichment hand-off).
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/list-building.md`
  > **Sub-issue role**: produces the enriched lead CSV that feeds Phase 1 of `/marketing:launch-campaign` at sub-issue #6.
  > **Expected plugin command**: `/marketing:list-building` or `/marketing:tam-mapping`.
- **dueDate**: `<launch-date> - 14 days`
- **blockedBy**: [#1]
- **blocks**: [#3]

#### #3 — Copy written + approved

- **Title**: `Copy written + approved`
- **Description**:
  > Marketing brief author runs `/marketing:email-copywriting` to produce the BC-5825 JSON copy artifact (step_1 + step_2 + custom_variables). GTM lead reviewer approves the rendered copy before Phase 1 of launch-campaign.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/email-copywriting.md`
  > **Sub-issue role**: produces the copy artifact that feeds Phase 1 of `/marketing:launch-campaign` at sub-issue #6.
  > **Expected plugin command**: `/marketing:email-copywriting`.
- **dueDate**: `<launch-date> - 10 days`
- **blockedBy**: [#1] (NOT #2 — copy and target list can parallel)
- **blocks**: [#4]

#### #4 — Salesforce setup

- **Title**: `Salesforce setup`
- **Description**:
  > Verify the SF Campaign record created at scaffold time (σ3 / `/revops:create-sf-campaign`). Populate audience members (CampaignMember records linked from EB lead suppress export). Wire Opportunity links if the offer is a pilot/risk-reversal posture.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/sf-campaign-setup.md`
  > **Sub-issue role**: SF reconciliation post-σ3 auto-create. If auto-create soft-failed at scaffold, manual `/revops:create-sf-campaign` re-run lands here.
  > **Expected plugin command**: `/revops:create-sf-campaign` (reconciliation) + manual SF UI work.
- **dueDate**: `<launch-date> - 7 days`
- **blockedBy**: [#3]
- **blocks**: [#5]

#### #5 — Pre-launch QA

- **Title**: `Pre-launch QA`
- **Description**:
  > Run the launch-campaign pre-flight checklist: copy renders correctly with sample leads, custom variables resolve, sender warm-up status, EB workspace health, SF Campaign linkage.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/pre-launch-qa.md`
  > **Sub-issue role**: catches launch-blocking issues before sub-issue #6 fires sending.
  > **Expected plugin command**: `/marketing:launch-campaign --preview` (dry-run mode) + manual review.
- **dueDate**: `<launch-date> - 3 days`
- **blockedBy**: [#4]
- **blocks**: [#6]

#### #6 — Launch executed

- **Title**: `Launch executed`
- **Description**:
  > Outbound operator runs `/marketing:launch-campaign` (Phase 11 ACTIVATE) to create + activate the EB campaign. Single EB campaign per [D1] (no sender splits).
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/launch.md`
  > **Sub-issue role**: the moment the campaign goes live. EB campaign_id flows back into manifest.email_bison.campaign_id at this point.
  > **Expected plugin command**: `/marketing:launch-campaign --activate` (consumes copy artifact from #3 + enriched CSV from #2).
- **dueDate**: `<launch-date>`
- **blockedBy**: [#5]
- **blocks**: [#7]

#### #7 — Active management — weekly reviews

- **Title**: `Active management — weekly reviews`
- **Description**:
  > Outbound operator runs `/marketing:campaign-analysis` weekly during the active sending window. GTM lead reviews. Adjustments (pause / unpause / sender swaps) per the analysis.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/active-management.md`
  > **Sub-issue role**: weekly cadence during the ~4-week active window. Pause/kill decisions land here via `/marketing:sync-campaign-status` (T2-FA / BC-8752).
  > **Expected plugin command**: `/marketing:campaign-analysis` weekly; `/marketing:sync-campaign-status` on status transitions.
- **dueDate**: `<launch-date> + 28 days` (T+28d)
- **blockedBy**: [#6]
- **blocks**: [#8]

#### #8 — Campaign closed + debrief

- **Title**: `Campaign closed + debrief`
- **Description**:
  > Run `/marketing:campaign-debrief` to produce the learnings.md artifact and update the MSPA results log. Linear status flips to `completed` (or `killed`) which triggers σ3 status-sync (BC-8752) to update SF Campaign.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/debrief.md`
  > **Sub-issue role**: terminal step. Closes the campaign loop into the compounding MSPA flywheel.
  > **Expected plugin command**: `/marketing:campaign-debrief`.
- **dueDate**: `<launch-date> + 40 days` (T+40d)
- **blockedBy**: [#7]
- **blocks**: none (terminal)

### 9.2 — Capture sub-issue IDs

For each `save_issue` response, capture the returned `id` + `identifier` (e.g., `BC-9001`). Pass to Step 11 for the summary output.

---

## Step 10 — Optional sub-issues

### 10.1 — Situation Mining (Labs-gated)

If `--situation-mining` was passed, enforce Labs entity:

If `<entity> != "labs"`, HARD-FAIL (the operator clearly meant something else):

```
ERROR: --situation-mining is a Brite Labs framework (per docs/gtm-campaign-orchestration-README.md § 3.5).
You passed --situation-mining with --entity=<entity>. Either drop the flag, OR re-run with --entity=labs.
```

If `<entity> == "labs"`, create sub-issue #9:

- **Title**: `Situation Mining`
- **Description**:
  > Run `/marketing:situation-mining` (Labs framework) to surface the latent situations that this campaign's persona is in BUT hasn't articulated yet. Output feeds the brief's Audience section (#1) and the copy artifact's angle hypotheses (#3).
  >
  > **Handbook citation**: `handbook@main:marketing/labs/situation-mining-framework.md`
  > **Sub-issue role**: pre-launch discovery; parallel with #2 and #3.
  > **Expected plugin command**: `/marketing:situation-mining`.
- **dueDate**: `<launch-date> - 12 days`
- **blockedBy**: [#1]
- **blocks**: none directly (informs #2 and #3 informationally)
- **Labels**: same 8-label set as the standard sub-issues.

### 10.2 — Creative Angles (no entity restriction)

If `--creative-angles` was passed, create sub-issue #10:

- **Title**: `Creative Angles`
- **Description**:
  > Run `/marketing:creative-angles` to generate 3-5 angle hypotheses to test in copy. Output feeds the copy artifact at sub-issue #3.
  >
  > **Handbook citation**: `handbook@main:marketing/go-to-market/processes/creative-angles.md`
  > **Sub-issue role**: pre-copy discovery; parallel with #2. Especially important for NEW offers that haven't been tested yet.
  > **Expected plugin command**: `/marketing:creative-angles`.
- **dueDate**: `<launch-date> - 12 days`
- **blockedBy**: [#1]
- **blocks**: none directly (informs #3 informationally)
- **Labels**: same 8-label set as the standard sub-issues.

---

## Step 11 — Summary output

Print the operator-readable summary:

```
=================================================================
Campaign scaffolded — /marketing:plan-campaign
=================================================================

  Slug:           <slug>
  Linear:         <milestone-url>
  SF Campaign:    <campaign-url>  (OR null + reconciliation reminder if soft-failed)
  Manifest:       docs/campaigns/<entity>/<slug>/manifest.json
  Sub-issues:     <count> created
                    #1  Brief approved                  <id>
                    #2  Target list built               <id>
                    #3  Copy written + approved         <id>
                    #4  Salesforce setup                <id>
                    #5  Pre-launch QA                   <id>
                    #6  Launch executed                 <id>
                    #7  Active management — weekly      <id>
                    #8  Campaign closed + debrief       <id>
                    #9  Situation Mining (Labs)         <id>   <-- if --situation-mining
                    #10 Creative Angles                 <id>   <-- if --creative-angles
  EB workspace:   <eb-workspace>  (campaign will be created at sub-issue #6
                                   via /marketing:launch-campaign — NOT now)

=================================================================
```

### 11.1 — Soft-fail reminders (if applicable)

If the σ3 SF auto-create soft-failed (`salesforce.campaign_id` is `null` in manifest), append the WARN line from § 8b.1's error catalog. Always end such reminders with the next-step pointer:

> To reconcile manually:
> `Skill(skill: "revops:create-sf-campaign", args: "--slug=<slug> --entity=<entity> --vertical=<vertical> --persona=<persona> --offer=<offer> --year=<year> --month=<month> --owner-email=<corrected-owner-email> --launch-date=<launch-date>")`

### 11.2 — Status-transition guidance

Append:

> For status transitions:
> - When a sub-issue closes (#6 close → SF Status=`In Progress`; #8 close → SF Status=`Completed`), σ3 trigger automation (BC-8752) WILL fire `/revops:update-sf-campaign-status` automatically.
> - When toggling `status:paused` or `status:killed` labels on the milestone, run `/marketing:sync-campaign-status` (T2-FA) manually — those are NOT auto-triggered.

### 11.3 — Hand-off

End with:

> Next step: marketing brief author opens `<milestone-url>` and finalizes the brief (sub-issue #1).

---

## Idempotency notes

This orchestrator is **partially** idempotent:

- **Step 3.3 collision check** + **Step 8b duplicate_slug handling** ensure repeated invocations with the same slug don't create duplicates in Linear or SF.
- **Step 7 manifest write** is destructive (overwrites any existing manifest.json). If re-running plan-campaign on an existing slug, the prior manifest is lost — copy it aside first if needed for diff comparison.
- **Step 9 sub-issue create** is NOT idempotent — calling `save_issue` with the same title against the same parent creates a NEW sub-issue (Linear doesn't dedupe on title). Re-runs will produce duplicate sub-issue chains.

If re-running plan-campaign is genuinely needed (rare — typically the operator should re-invoke specific sibling skills like `/revops:create-sf-campaign` directly):

1. Delete the Linear milestone + sub-issues manually first.
2. Delete the `docs/campaigns/<entity>/<slug>/` directory.
3. Then re-run plan-campaign.

A future enhancement could add `--reset-slug` that does this cleanup automatically; out of scope for v1.

---

## Gotchas

- **`Skill` tool invocation of `/revops:create-sf-campaign`**: The skill returns its single-line JSON via stdout. Capture it as the skill-invocation result. If the skill emits multi-line output (e.g., diagnostic stderr leaking into stdout), parse the LAST line that starts with `{` as the JSON object — the skill's contract is one-line JSON, but defensive parsing keeps the orchestrator robust.
- **Linear MCP `parentId` is `parentId`, NOT `parent`**: per [`memory/gotcha_linear_save_issue_parent_id.md`](../../../memory/gotcha_linear_save_issue_parent_id.md).
- **Linear MCP `state` is `state`, NOT `status`**: per [`memory/gotcha_linear_save_issue_state_param.md`](../../../memory/gotcha_linear_save_issue_state_param.md). This orchestrator doesn't set state on sub-issues (they default to `Backlog`) — but if a future enhancement adds a default state, use `state:`.
- **Linear MCP `list_issues` `project:` param is unreliable**: per [`memory/gotcha_linear_list_issues_project_filter.md`](../../../memory/gotcha_linear_list_issues_project_filter.md). This orchestrator uses `list_milestones` (Step 3.3) which is RELIABLE for the slug-collision check; it does NOT use `list_issues` with project: filter.
- **SF MCP `usernameOrAlias` must be literal username**: per [`memory/gotcha_sf_mcp_username_not_alias.md`](../../../memory/gotcha_sf_mcp_username_not_alias.md). This orchestrator only calls `get_username` (read-only metadata) at Step 4.2 — actual SF writes are delegated to `/revops:create-sf-campaign` which handles the literal-username resolution itself.
- **Brite GTM project must exist before plan-campaign ships**: Step 3.3 HARD-FAILs if `list_projects(query="Brite GTM")` returns 0. The project is provisioned at BC-8712 Task 0 (Phase 0). If absent, file a follow-up to provision it before running plan-campaign on real campaigns.
- **`AskUserQuestion` has no pure free-text mode**: per [`memory/gotcha_askuserquestion_no_free_text.md`](../../../memory/gotcha_askuserquestion_no_free_text.md) — it's multi-choice + automatic `Other` fallback. The interactive prompts in Step 1 use 3-4 options + `Other` (the auto-added free-text path); never assume the operator's pure free-text input is captured directly by a prompt without `Other`.
- **Plugin version bump**: changes to this file REQUIRE bumping `plugins/marketing/.claude-plugin/plugin.json` AND the matching `.claude-plugin/marketplace.json` entry in the same commit, per CLAUDE.md's plugin-cache gotcha. The pre-commit hook (`scripts/pre-commit.sh`) enforces this.
- **gh CLI must be authed for Step 8a.2**: the brief template fetch via `gh api` requires `gh auth status` to be green. If not, the inline fallback (§ 8a.4) is used silently. Operator can pre-check via `gh auth status` before running.

---

## Future enhancements (out of v1 scope)

- `--reset-slug` flag for safe re-runs (delete prior Linear + manifest, then scaffold fresh).
- `--reference <slug>` flag to clone an existing campaign's brief + copy + targeting metadata.
- Auto-creation of the 8 label categories if missing (currently requires manual Linear UI setup or an out-of-band script).
- `default_entity` key in `{vertical}.yaml` to skip the entity prompt for single-entity verticals.
- Brief-template ICP extraction: parse `handbook/{vertical}/README.md` ICP table and pre-fill the Audience section of the brief automatically. v1 leaves it as `<!-- OPERATOR-FILL -->`.
