---
description: Backfill an existing GTM campaign into the plugin's manifest layer — read an existing Linear milestone + 1-N Email Bison campaign IDs (split by ESP × audience-tier per ADR-020) + canonical (vertical, persona, offer, month, year, entity) tuple → write a fully populated `docs/campaigns/{entity}/{slug}/manifest.json` (schema v2) + create σ3 Salesforce Campaign (soft-fail) + stub `learnings.md` + `analysis-{YYYY-MM}.md`. Sibling to `/marketing:plan-campaign` (scaffold-from-scratch); this command imports an already-launched campaign that pre-dates the plugin or was created out-of-band. Triggers on "import campaign", "backfill campaign", "import existing campaign", "reconcile campaign manifest", or direct `/marketing:import-campaign` invocation.
argument-hint: --linear-milestone <id> --eb-records <id>:<workspace>[,<id>:<workspace>...] --vertical <slug> --persona <slug> --offer <slug> --entity <nites|supply|labs> --month <1-12> --year <YYYY> [--launch-date <YYYY-MM-DD>] [--owner-email <email>] [--dry-run]
allowed-tools: Read, Write, Bash, AskUserQuestion, Skill, mcp__plugin_workflows_linear-server__get_project, mcp__plugin_workflows_linear-server__get_milestone, mcp__emailbison-b2b__list_campaigns, mcp__emailbison-personal__list_campaigns, mcp__plugin_revops_salesforce__get_username
---

# /marketing:import-campaign

> **How this command runs**: When invoked, the model reads this spec and executes each Step (1, 1b, 2, 3, ...) in order using its tool palette (Read, Write, Bash, Skill, the Linear MCP, the Email Bison MCPs, etc.). There is no separate "runner" or background process — the spec IS the program. To debug a partial run, re-invoke from the failure point with corrected flags; expect a procedural, multi-turn execution. (Same dispatch model as `/marketing:plan-campaign`.)

The campaign-backfill orchestrator. One invocation imports one already-launched campaign into the plugin's manifest layer, paralleling `/marketing:plan-campaign` for greenfield scaffolds:

| Layer | What lands | Where it came from |
|---|---|---|
| Plugin filesystem | `docs/campaigns/{entity}/{slug}/manifest.json` (schema v2) | Composed from operator inputs + Linear + EB metadata |
| Plugin filesystem | `learnings.md` + `analysis-{YYYY-MM}.md` stubs | Templated, with EB stats auto-populated; qualitative sections operator-stubbed |
| Salesforce | 1 Campaign record (Status=Planned) — soft-fail | Created via `/revops:create-sf-campaign` |
| Linear / Email Bison | NOTHING — both already exist | This command READS, doesn't WRITE |

## Why this exists

`/marketing:plan-campaign` (BC-8724) scaffolds from scratch — Linear milestone + sub-issues + manifest + SF Campaign + EB workspace assignment, all in one. It assumes no prior artifacts exist.

`/marketing:import-campaign` (BC-11849) covers the inverse case: a campaign that already has a Linear milestone AND one or more Email Bison records (typically launched out-of-band before the plugin existed, or created in a partial plan-campaign run where σ3 SF auto-create failed and the operator never reconciled). The plugin's manifest layer is the cross-reference index that ties Linear ↔ SF ↔ EB; without a manifest, downstream readers (`portfolio-snapshot`, `campaign-debrief`, `audit-campaigns`) can't see the campaign.

## Inputs / outputs / precedent

**Inputs**: existing Linear milestone UUID + a list of `<eb-campaign-id>:<workspace>` pairs + the canonical (vertical, persona, offer, year, month, entity) tuple that the campaign represents.

**Outputs**:
- `docs/campaigns/{entity}/{slug}/manifest.json` — fully populated schema v2 per § Step 9.
- `docs/campaigns/{entity}/{slug}/learnings.md` — stub per § Step 11; EB-stats table auto-populated, qualitative sections operator-stubbed.
- `docs/campaigns/{entity}/{slug}/analysis-{YYYY-MM}.md` — stub per § Step 11.
- 1 Salesforce Campaign record (if `/revops:create-sf-campaign` succeeded; null `campaign_id` in manifest if it soft-failed).
- Operator-readable summary printed at Step 12.

**Precedent + sources**:
- `plugins/marketing/commands/plan-campaign.md` (BC-8724) — sibling scaffold-from-scratch orchestrator. This command mirrors its skeleton: frontmatter, allowed-tools shape, AskUserQuestion patterns, two-call confirm gate, soft-fail philosophy.
- `plugins/revops/commands/create-sf-campaign.md` (BC-8717) — σ3 SF auto-create composed at Step 10.
- `plugins/marketing/data/canonicals/_manifest.yaml` `audience_tiers[]` block (BC-11852 / ADR-020) — the auto-classifier source for `audience_tier` per EB record.
- `plugins/marketing/data/canonicals/schema.json#/definitions/campaign_manifest` (v2) — the manifest contract.
- `plugins/marketing/scripts/import_campaign.py` — the Python helper that classifies EB names + composes the v2 manifest body (testable via `test_import_campaign.sh`).
- `docs/decisions/020-gtm-campaign-manifest-schema-v2.md` — the v2 schema decision; the auto-classifier rules live in § "Worked examples."
- `docs/reconciliation/master-index.md` / `master-index.json` (BC-11851, PR #391) — the inventory whose rows are the canonical batch-mode inputs for this command (one row → one import invocation).

## Soft-fail philosophy

Per the sibling pattern, **manifest writes always land** — they're the gate that makes the campaign visible to every downstream reader. Halting the manifest write because a non-essential dependency is unhealthy is more costly than the inconsistency itself (which the manifest's `null`-friendly schema absorbs cleanly).

- **SF auto-create unavailable** (`/revops:create-sf-campaign` errors): manifest writes with `salesforce.campaign_id: null`; WARN logged at Step 12 with a reconciliation pointer.
- **EB workspace MCP unreachable** (network / auth error before any record can be fetched): manifest writes with `email_bison.campaigns: []`; WARN logged at Step 12. Operator can re-run after fixing auth.

Hard-fail paths (which DO halt the import):
- Canonicality validation (Step 2) — invalid `--vertical` / `--persona` / `--offer`. Pointer to `/marketing:new-*`.
- Slug regex mismatch (Step 3.2) — upstream canonicals-lint bug.
- Linear milestone not found (Step 4) — operator must create the milestone via Linear UI or `/marketing:plan-campaign` first; this command does NOT auto-create milestones.
- EB campaign ID not found in its declared workspace (Step 6) — operator typo; fix the `--eb-records` mapping.
- Invalid `--entity` / `--month` / `--year` / `--launch-date` / `--owner-email` shape (Step 1b).
- Operator cancels at the Step 8 two-call confirm gate.

## Non-goals (out of scope per BC-11849 brief)

- Do NOT create the Linear milestone — caller's responsibility. Use `/marketing:plan-campaign` for new campaigns.
- Do NOT create the EB campaign — caller's responsibility. Use `/marketing:launch-campaign`.
- Do NOT create sub-issues — this command does NOT mirror plan-campaign's Step 9 / Step 10. Sub-issue scaffolding is plan-campaign's job; an already-launched campaign typically has its work already done or recorded elsewhere.
- Do NOT operationally reconcile the ~36-40 historical campaigns — that's BC-11850 (this command is the TOOL; the worklist is BC-11850).
- Do NOT detect drift between manifest and live EB state — that's BC-11856 (`/marketing:audit-campaigns`).
- Do NOT auto-file a Linear reminder on σ3 soft-fail — that's BC-11855.
- Do NOT backfill the qualitative learnings.md content — stubs only. Full backfill is BC-11859.

---

## Step 1 — Operator invocation + flag parsing + interactive fallback

Parse the invocation arguments. Required flags: `--linear-milestone`, `--eb-records`, `--vertical`, `--persona`, `--offer`, `--entity`, `--month`, `--year`. For everything else, derive defaults or prompt one-at-a-time (per `feedback_one_question_at_a_time.md` + `feedback_interview_chunking.md` — present ONE assumption per question, never batch sub-questions a/b/c).

### Flag table

| Flag | Required | Default / resolution |
|---|---|---|
| `--linear-milestone` | yes | Linear milestone UUID. No prompt fallback — caller must look it up (e.g., from the Linear UI URL or `list_milestones`). |
| `--eb-records` | yes | Comma-separated list of `<eb-campaign-id>:<workspace>` pairs (e.g., `12345:emailbison-b2b,67890:emailbison-personal`). Empty value (`""`) is a valid input — it asserts "no EB records exist yet for this campaign", and the resulting manifest has `email_bison.campaigns: []`. |
| `--vertical` | yes | If missing, prompt: "Which vertical?" with options sourced from `_manifest.yaml`'s `verticals[]`. |
| `--persona` | yes | If missing, prompt: "Which persona?" with options sourced from `{vertical}.yaml`'s `personas[].slug`. |
| `--offer` | yes | If missing, prompt: "Which offer?" with options sourced from `{vertical}.yaml`'s `offers[].slug` filtered to `target_personas` containing the chosen `--persona` (or no `target_personas` constraint). |
| `--entity` | yes | If missing, prompt: "Which entity?" with options `[nites, supply, labs]`. Cross-entity NOT supported in v1 — file a follow-up if needed. |
| `--month` | yes | Integer 1-12. No prompt fallback — the campaign's own month is part of its canonical slug; the operator MUST supply it explicitly. |
| `--year` | yes | 4-digit integer. Same reasoning as `--month`. |
| `--launch-date` | no | Default: derived from the earliest `launched_at` in the fetched EB records, falling back to `{year}-{month:02d}-01` if none of the EB records are launched. Surfaces in dry-run preview. |
| `--owner-email` | no | Resolve via the chain in Step 5 (mirrors plan-campaign Step 4.2). |
| `--dry-run` | no | Print the full preview at Step 7 and exit without writing anything. |

### Interactive prompt example

When `--persona` is missing and the operator picked `bars-restaurants`:

> AskUserQuestion: "Which persona for bars-restaurants?"
> Options: `bar-owner` / `general-manager` / `<other personas from bars-restaurants.yaml>` / `Other`

Read the canonical persona slugs DIRECTLY from `plugins/marketing/data/canonicals/{vertical}.yaml` `personas[].slug` — do NOT guess from training data. The `Other` option hands control to free-text input; if the operator picks `Other`, validate the typed slug against the canonicals or HARD-FAIL with the `/marketing:new-persona` pointer.

### Non-interactive mode

If all required flags are provided, skip prompts and proceed directly to Step 1b (parse-time validation).

### Step 1b — Parse-time input validation (HARD-FAIL invariants)

Before any downstream step, validate every operator-controlled flag value. These are mechanical safety invariants — non-interactive invocations skip the Step 1 prompts entirely, so these checks are the only barrier between operator input and shell/MCP/path interpolation. HARD-FAIL on any violation; do NOT auto-sanitize.

| Flag | Validator | HARD-FAIL message on miss |
|---|---|---|
| `--entity` | Must be one of `nites` / `supply` / `labs` (closed set; case-sensitive). Cross-entity NOT supported in v1. | `ERROR: --entity must be one of [nites, supply, labs]; got '<value>'. Cross-entity import not supported in v1.` |
| `--month` | Integer 1-12 | `ERROR: --month must be 1-12; got '<value>'` |
| `--year` | 4-digit integer 2025-2099 (lower bound matches the v2 schema's `campaign_manifest.year` minimum + the helper's `YEAR_MIN`) | `ERROR: --year must be 4-digit 2025-2099; got '<value>'` |
| `--launch-date` | If provided, matches `^\d{4}-\d{2}-\d{2}$` (ISO YYYY-MM-DD format) | `ERROR: --launch-date must be ISO YYYY-MM-DD; got '<value>'` |
| `--owner-email` | If provided, matches `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$` | `ERROR: --owner-email failed regex; got '<value>'` |
| `--vertical` / `--persona` / `--offer` | Strict kebab-case `^[a-z0-9]+(-[a-z0-9]+)*$` (canonicality membership checked in Step 2; this is the SHAPE check) | `ERROR: --<flag> must be strict kebab-case; got '<value>'` |
| `--linear-milestone` | Non-empty string; trimmed value matches `^[a-zA-Z0-9-]+$` (Linear IDs are UUIDs or short-key strings — restrict to safe identifier shape) | `ERROR: --linear-milestone must be a safe identifier; got '<value>'` |
| `--eb-records` | If non-empty, each token matches `^[0-9]+:(emailbison-b2b\|emailbison-personal)$`; tokens separated by commas. Empty string is allowed (asserts no EB records). | `ERROR: --eb-records token '<token>' failed shape <id>:<workspace>` |

The validator runs unconditionally, regardless of interactive vs non-interactive mode. Interactive prompts in Step 1 use AskUserQuestion which constrains the operator's input to a closed set + Other; the regex on the Other free-text path is the only place where prompt output could otherwise leak into downstream interpolation.

---

## Step 2 — Canonicality validation

Read the canonicals data layer in order; HARD-FAIL on the first miss with a pointer to the appropriate `/marketing:new-*` command. This step mirrors `/marketing:plan-campaign` Step 2 verbatim (same `_manifest.yaml` + `{vertical}.yaml` reads + same HARD-FAIL error shapes) — see plan-campaign Step 2 for the full error text and `target_personas` semantic check.

In summary:

- **2.1** — Assert `--vertical` ∈ `_manifest.yaml verticals[]`. HARD-FAIL with `/marketing:new-vertical` pointer on miss.
- **2.2** — Read `{vertical}.yaml` ONCE; cache as `<vertical-doc>` for Step 2.3 + Step 2.4. Assert `--persona` ∈ `personas[].slug`. HARD-FAIL with `/marketing:new-persona` pointer on miss.
- **2.3** — Assert `--offer` ∈ `offers[].slug`. HARD-FAIL with `/marketing:new-offer` pointer on miss.
- **2.4** — If `offer.target_personas[]` non-empty, assert `--persona` ∈ `target_personas`. HARD-FAIL on miss.

Empty or absent `target_personas` = "all personas in this vertical are valid for this offer" — skip the membership check.

---

## Step 3 — Slug compute + idempotency gate

### 3.1 — Compute slug

```
{vertical}-{persona}-{offer}-fy{YY}-m{MM}
```

Where `YY = year % 100` (zero-padded if needed) and `MM = month` zero-padded to 2 digits. Example: `bars-restaurants-bar-owner-anchor-audit-fy25-m09`.

### 3.2 — Validate slug regex

Assert slug matches `^[a-z][a-z0-9]*(-[a-z0-9]+)*-fy\d{2}-m\d{2}(-v\d+)?$` (kebab-case prefix — first char must be `[a-z]`, no doubled hyphens — plus the canonical `-fy<YY>-m<MM>[-v<N>]` suffix). The helper at `plugins/marketing/scripts/import_campaign.py` enforces this exact regex via `CAMPAIGN_SLUG_RE` and is the authoritative gate; this spec restates it for operator-facing clarity. On mismatch, HARD-FAIL — a non-matching slug means one of the input slugs contains an illegal character that the canonicals lint should have caught upstream; surface as a bug, not an operator error:

```
ERROR: Computed slug '<slug>' does not match canonical campaign-slug regex.
Expected shape: <kebab-prefix>-fy<YY>-m<MM>[-v<N>]
This is upstream-canonicals-lint territory — file an issue against plugins/marketing/data/canonicals/.
```

### 3.3 — Idempotency gate (existing-manifest detection)

```bash
manifest_path="docs/campaigns/<entity>/<slug>/manifest.json"
if [ -f "$manifest_path" ]; then
  echo "INFO: Manifest already exists at $manifest_path. /marketing:import-campaign is a no-op."
  echo "      To re-import (overwrite), delete the directory first:"
  echo "        rm -rf docs/campaigns/<entity>/<slug>/"
  echo "      To detect drift against live EB state, use /marketing:audit-campaigns (BC-11856)."
  exit 0
fi
```

This gate enforces the brief's "Re-running on same slug → detects existing manifest → no double-writes" requirement AND the cohort-1 byte-identicality requirement. The gate fires BEFORE any MCP call, any operator confirm, any SF auto-create — so a re-run is truly a no-op (zero side effects, zero MCP cost).

**Rationale for explicit skip over auto-merge**: the manifest is a cross-layer cross-reference; merging "what the operator passed this time" into an existing manifest invites silent drift. If the operator wants to refresh stats, they delete and re-run; if they want to detect drift, that's `/marketing:audit-campaigns`.

---

## Step 4 — Resolve Linear milestone

Call:

```
mcp__plugin_workflows_linear-server__get_milestone(id=<--linear-milestone>)
```

On a not-found response (the MCP returns an empty / null result OR raises a "milestone not found" error), HARD-FAIL:

```
ERROR: Linear milestone '<--linear-milestone>' not found.
This command does NOT auto-create milestones. Create the milestone first via:
  - Linear UI (manual)
  - /marketing:plan-campaign (greenfield scaffold)
Then re-run /marketing:import-campaign with the new milestone ID.
```

On success, capture:

- `<milestone-id>` ← `<--linear-milestone>` (already validated)
- `<milestone-url>` ← per the F8 pattern from plan-campaign Step 8a.5: the Linear MCP `get_milestone` response shape does NOT reliably include a per-milestone URL. Resolve the project URL via the milestone's `projectId`:

```
mcp__plugin_workflows_linear-server__get_project(id=<milestone.projectId>)
```

Capture `<project-url>` from that response. Bind `<milestone-url> := <project-url>` (alias — same string; "milestone-url" framing kept for operator semantic clarity). If `get_project` itself fails, fall back to a placeholder `https://linear.app/brite-nites/project/<milestone.projectId>` and emit a WARN that the operator should backfill manually.

---

## Step 5 — Owner email resolution

Identical chain to `/marketing:plan-campaign` Step 4.2 — copied verbatim here to keep this spec self-contained:

Define `EMAIL_REGEX = ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`. Every path that yields a candidate `<owner-email>` MUST re-apply `EMAIL_REGEX` before accepting the value.

1. **Explicit `--owner-email` flag** — if provided AND matches EMAIL_REGEX, use it. Skip rest of chain.
2. **SF authed username probe** — call `mcp__plugin_revops_salesforce__get_username`. If the returned `username` matches EMAIL_REGEX, use it.
3. **AskUserQuestion fallback** — options `marketingadmin@britenites.com (GTM service account)` / `<authed SF user from step 2>` / `Other`. Validate Other free-text via EMAIL_REGEX before accepting.
4. **Final pre-Step-10 guard** — re-apply EMAIL_REGEX at the boundary into the `Skill` invocation. On miss, HARD-FAIL.

Store as `<owner-email>` for Step 10.

---

## Step 6 — Fetch EB records

Parse `--eb-records` into a list of `(eb_id, workspace)` pairs. For each unique workspace in the list, call `list_campaigns` once on the matching MCP server, then filter the response for the requested IDs.

### 6.1 — Per-workspace fetch

For `workspace ∈ {emailbison-b2b, emailbison-personal}` that appears in the parsed `--eb-records`:

```
response = mcp__emailbison-<workspace>__list_campaigns(per_page=200)
```

The EB API's `list_campaigns` is paginated; the per-page cap (typically 200) covers nearly every workspace. If the response is paginated and the requested IDs are not on page 1, walk pages until found OR until pages are exhausted. (For the cohort-1 reconciliation worklist BC-11850, all observed IDs are on page 1 of the b2b workspace's listing — pagination is a defensive edge case here.)

**DO NOT use `mcp__emailbison-<workspace>__get_campaign`** — per tracker observation (`docs/reconciliation/tracker-log.md` § Cross-tracker observations), `get_campaign` 404s on live EB IDs as of 2026-05-27; the `list_campaigns` + client-side filter pattern is the verified-working alternative.

### 6.2 — Per-record assembly

For each `(eb_id, workspace)` pair, locate the matching entry in the workspace's `list_campaigns` response by `id`. Extract:

- `workspace` — the queried workspace string (`emailbison-b2b` / `emailbison-personal`)
- `campaign_id` — the EB numeric ID
- `name` — the EB campaign name string (this is what the auto-classifier reads)
- `status` — the EB-side status (`draft` / `launched` / `paused` / `completed` / `archived`)
- `launched_at` — ISO-8601 UTC timestamp; null if `draft`
- `esp` — if EB returns an ESP field, capture it; otherwise omit

If a requested `(eb_id, workspace)` pair is not found in the workspace's `list_campaigns` response after all pages exhausted, HARD-FAIL:

```
ERROR: EB campaign '<eb_id>' not found in workspace '<workspace>'.
Verify the ID + workspace pairing in --eb-records. Common causes:
  - ID typo (transposed digits)
  - Wrong workspace declared (an emailbison-personal ID asserted as emailbison-b2b)
  - Campaign was archived + removed from the listing (rare; check EB UI)
```

### 6.3 — Soft-fail on workspace unreachable

If the MCP call itself errors (network failure, auth missing, HTTP 5xx), DO NOT halt — soft-fail per § Soft-fail philosophy:

- Skip the workspace's records (they'll be absent from `email_bison.campaigns[]` in the composed manifest).
- Emit a stderr WARN: `WARN: EB workspace '<workspace>' unreachable; <N> requested records skipped. Re-run after fixing auth.`
- Continue to Step 7 with the partial record list.

### 6.4 — Derive launch-date default

If `--launch-date` was NOT provided:

- If any EB record has a non-null `launched_at`, default `<launch-date>` to the EARLIEST one (oldest launched_at across all fetched records), truncated to `YYYY-MM-DD`.
- Otherwise default to `{year}-{month:02d}-01`.

Bind as `<launch-date>` for Step 7 + Step 10.

### 6.5 — Derive `created_at` for manifest

The manifest's `created_at` field per BC-11849 brief = "**original launch date from EB** (NOT now)". Bind:

- If any EB record has a non-null `launched_at`, `<created-at>` = EARLIEST `launched_at` (full ISO-8601 UTC timestamp).
- Otherwise `<created-at>` = `<launch-date>T00:00:00Z`.

---

## Step 7 — Dry-run preview

Print the operator-readable plan:

```
=================================================================
/marketing:import-campaign — Dry-run preview
=================================================================

  Slug:           <slug>
  Entity:         <entity>
  Vertical:       <vertical>           (canonical)
  Persona:        <persona>            (canonical)
  Offer:          <offer>              (canonical, posture=<offer.posture>, status=<offer.status>)
  Year / Month:   <year> / <month:02d>
  Launch date:    <launch-date>        (resolved from earliest EB launched_at if --launch-date omitted)
  created_at:     <created-at>         (earliest EB launched_at, or <launch-date>T00:00:00Z)
  Owner email:    <owner-email>        (resolved via <method>: --owner-email | get_username | AskUserQuestion)

  Linear milestone (existing):
    ID:           <milestone-id>
    URL:          <milestone-url>
    Name:         <milestone.name>

  EB records to import (<N>):
    [1] workspace=<ws>  id=<id>  status=<status>  launched_at=<ts>
        name="<name>"
        audience_tier: tier=<tier>  seniority=<seniority|null>  modifiers=[<modifiers>]
    [2] ...

  Plugin manifest (will be written):
    Path:         docs/campaigns/<entity>/<slug>/manifest.json
    Schema:       v2 (BC-11852 / ADR-020)
    scaffolded_by: /marketing:import-campaign

  Salesforce auto-create (via /revops:create-sf-campaign --dry-run):
    <output of /revops:create-sf-campaign --dry-run with the same args>

  Stubs (will be written):
    docs/campaigns/<entity>/<slug>/learnings.md
    docs/campaigns/<entity>/<slug>/analysis-<YYYY-MM>.md

=================================================================
```

To produce the per-record `audience_tier` for the preview, **do NOT run the `classify-name` subcommand on a shell line built by substituting the EB name into the command text** — EB campaign names are free-form and routinely contain shell metacharacters (`|`, `$`, backticks, quotes), so any inline-substitution form (even wrapped in `printf '%s'`) is a command-injection vector the moment a name contains a `"`. Instead, classify the records the SAME safe way Step 9 composes the manifest: build the full record array in the orchestrator's reasoning step, `Write` it to a tempfile via the `Write` tool, and pipe that file to the helper's `compose` stdin (Step 9) — `compose` auto-classifies every record and you read the resulting `audience_tier` objects back from its output. `compose` (file-stdin, no shell interpretation of contents) is the only sanctioned path for EB-name-bearing input; the `classify-name` subcommand exists for orchestrator-internal reasoning only and MUST NOT be invoked with an EB name interpolated into a bash string.

To produce the SF Campaign payload preview, invoke `/revops:create-sf-campaign --dry-run` via the `Skill` tool with the same flag values that the real Step 10 invocation will use; capture the single-line JSON it emits.

> **σ3 dry-run caveat**: `/revops:create-sf-campaign` skips its Phase 0 metadata fetch on `--dry-run`, so when no SF org session is cached its Phase 2/3 SOQL fails first and the command returns `{"error":"sf_cli_error",...}` instead of the payload preview. That is EXPECTED in a session without SF auth and does NOT predict a real-run failure — render it as "SF preview unavailable (no SF session)", not as a blocker. (Inherited σ3 behavior; identical to plan-campaign Step 5.)

**If `--dry-run` was passed to import-campaign, exit here.** Do not proceed to Step 8. Print one final line: `Dry-run complete. No writes performed.`

---

## Step 8 — Two-call confirm gate (per BC-2707)

This is the load-bearing safety gate before any writes. Per `docs/precedents/BC-2707.md`: the gate enforces **turn structure** (operator must respond between any two consequential writes), NOT vocabulary (any clear affirmative counts).

Issue the gate via `AskUserQuestion`:

> "Proceed with campaign import?"
> Options: `Proceed — write manifest + stubs + SF Campaign` / `Cancel`

Treat clear affirmatives as proceed. Ambiguous responses → re-prompt with the same question. On `Cancel`, halt cleanly with no writes and re-print the Step 7 preview block (adapt header to "Cancelled — would have written:").

---

## Step 9 — Write plugin dir + manifest.json

After confirm, create the campaign directory:

```bash
mkdir -p "docs/campaigns/<entity>/<slug>"
```

Compose the manifest by writing the import payload to a tempfile via the `Write` tool, then piping the file to the helper. This is the **canonical pattern** — do NOT inline operator-derived or EB-derived strings into a bash heredoc; EB campaign names are free-form text and routinely contain characters (`$`, backticks, `"`) that would either inject shell commands or break JSON parsing. The `Write` tool serializes values losslessly; the helper consumes the file stdin without any shell interpretation of its contents.

Workflow:

1. Build the payload object as a Python dict in the orchestrator's reasoning step.
2. `Write` the JSON to `/tmp/import-campaign-payload-<slug>.json` via `json.dumps(payload, indent=2)`.
3. Invoke the helper:

```bash
python3 plugins/marketing/scripts/import_campaign.py compose \
  --canonicals-manifest plugins/marketing/data/canonicals/_manifest.yaml \
  < "/tmp/import-campaign-payload-<slug>.json" \
  > "docs/campaigns/<entity>/<slug>/manifest.json"
```

The payload object shape (the JSON the orchestrator writes to the tempfile):

```json
{
  "slug": "<slug>",
  "entity": "<entity>",
  "vertical": "<vertical>",
  "persona": "<persona>",
  "offer": "<offer>",
  "year": <year>,
  "month": <month>,
  "linear": {
    "milestone_id": "<milestone-id>",
    "milestone_url": "<milestone-url>",
    "project": "Brite GTM"
  },
  "salesforce_campaign_id": null,
  "salesforce_campaign_name": "<slug>",
  "eb_workspace": "<primary-eb-workspace>",
  "eb_campaign_name": "<slug>",
  "eb_records": [
    {
      "workspace": "<ws>",
      "campaign_id": <id>,
      "name": "<name>",
      "status": "<status>",
      "launched_at": "<ts>"
    },
    ...
  ],
  "created_at": "<created-at>",
  "scaffolded_by": "/marketing:import-campaign"
}
```

If the orchestrator must use bash directly (e.g., for a one-off ad-hoc invocation), it MUST quote the heredoc terminator (`<<'EOF'`) so the shell treats the body as literal and never performs `$(...)`/backtick/variable expansion. The unquoted form is forbidden because EB campaign-name strings flow into the body unescaped.

The helper auto-classifies each `eb_records[].name` into a structured `audience_tier` object using the `_manifest.yaml audience_tiers[]` block (BC-11852 / ADR-020), then emits the composed schema-v2 manifest to stdout.

### 9.1 — Resolve `<primary-eb-workspace>`

The `email_bison.workspace` field is the PRIMARY-workspace pointer (where the canonical lead list lives). Resolve via this entity-map fallback chain:

1. If `--eb-records` declares any workspace, primary = the workspace that holds the MOST records. Tie-breaker: `emailbison-b2b` wins (most Brite primary-list workspace).
2. If `--eb-records` is empty, primary = the entity-map default:
   - `nites` → `emailbison-personal`
   - `supply` → `emailbison-b2b`
   - `labs` → `emailbison-b2b`

### 9.2 — Confirm filesystem state

Use the `Read` tool on `docs/campaigns/<entity>/<slug>/manifest.json` to verify the write landed (no shell needed — `Read` displays file head natively + sidesteps any `<slug>`-injection risk in shell paths). Then `Bash` `ls -- "docs/campaigns/<entity>/<slug>/"` (note the `--` option-terminator) to confirm the directory contents.

Do NOT `git add` or `git commit` — that's `/workflows:ship`.

### 9.3 — Pending-classification flag (operator-confirmed)

Per the BC-11849 brief: the migration script sets `pending_classification: true` on auto-migrated launched records; this command's import workflow is the path that clears the flag. Because the operator EXPLICITLY confirmed the classification at Step 8's two-call gate (the dry-run preview at Step 7 displays the auto-classified `audience_tier` per record before the gate), the composed manifest OMITS `pending_classification` for every record the classifier could resolve from a non-empty EB name — its absence is the contract for "operator-confirmed at import time." If the operator wanted to flag a record for re-classification, they'd edit the manifest by hand AFTER the import.

**Exception — unclassifiable (blank-name) records**: if EB returns a record with a blank/whitespace-only `name` (EB permits this), the auto-classifier cannot meaningfully classify it. For those records the helper stamps a placeholder `audience_tier` (`{tier: professional, seniority: null, modifiers: []}`) **and** sets `pending_classification: true` so the record surfaces in operator greps for follow-up — the Step 7 dry-run preview would show the placeholder tier, so the operator's Step 8 confirmation was over a guess, not a real classification. This is the one path where an import-written manifest carries `pending_classification`; it is the helper's safety behavior, not a bug.

---

## Step 10 — Salesforce Campaign auto-create (σ3) via `/revops:create-sf-campaign`

Invoke the sibling slash command via the `Skill` tool. This is the BC-8717 respec composition pattern — `/marketing:import-campaign` does NOT directly call any `mcp__plugin_revops_salesforce__*` write tool.

**Boundary guard (do this immediately before composing the args)**: re-apply `EMAIL_REGEX` (defined in Step 5) to `<owner-email>` one more time at this site. On miss, HARD-FAIL with `ERROR: <owner-email> failed final email-format guard before /revops:create-sf-campaign invocation.` This is a tripwire, not redundant: a malformed owner-email interpolated into the args string could smuggle an extra `--`-prefixed token into `/revops:create-sf-campaign` (flag injection) or break its arg parsing, and it lands in a SOQL string literal downstream (Phase 3). Step 5 already guards the resolution chain; this restates the guard at the invocation boundary because the soft-fail reconciliation reminder (Step 12.1) is a distinct re-entry that bypasses Step 5.

```
Skill(
  skill: "revops:create-sf-campaign",
  args: "--slug=<slug> --entity=<entity> --vertical=<vertical> --persona=<persona> --offer=<offer> --year=<year> --month=<month> --owner-email=<owner-email> --launch-date=<launch-date>"
)
```

### 10.1 — Parse the response + persist

The skill emits a single-line JSON object on stdout. Branch on the presence of `error`:

**Success** (no `error` key): update `salesforce.campaign_id` ← `campaign_id` from the response. Use `Read` → JSON-mutate → `Write` on the manifest.

**Soft-fail** (`error` present, any kind): leave `salesforce.campaign_id` as `null`. Capture the error JSON for the Step 12 WARN line. The full error-kind catalog (`duplicate_slug` / `missing_owner` / `sf_cli_error` / `invalid_slug_format` / `missing_required_flag` / unknown) is described in `/marketing:plan-campaign` Step 8b.1 — reuse the same per-kind WARN copy.

**Special case — `duplicate_slug`**: the SF record already exists (typically from a prior partial run). Update `salesforce.campaign_id` ← `error.existing_id`. Log INFO line at Step 12: "SF Campaign for `<slug>` already exists; reusing existing_id."

---

## Step 11 — Write stub `learnings.md` + `analysis-{YYYY-MM}.md`

Both stubs are templated markdown — stats sections auto-populated from EB record stats; qualitative sections marked `<!-- OPERATOR-FILL -->` for the campaign-debrief author to backfill later (per BC-11859).

### 11.1 — `learnings.md` stub

Write to `docs/campaigns/<entity>/<slug>/learnings.md`:

```markdown
# Campaign learnings — <slug>

> Stub authored by `/marketing:import-campaign` at backfill time (BC-11849). Qualitative
> sections are operator-stubbed (`<!-- OPERATOR-FILL -->`). Full backfill follows the
> `/marketing:campaign-debrief` pattern (BC-11859 will sweep historical stubs in batch).

## EB record summary (auto-populated)

| Workspace | Campaign ID | Audience tier | Status | Launched |
|---|---|---|---|---|
<for each EB record:>
| <workspace> | <campaign_id> | <tier> / <seniority|—> / <modifiers or —> | <status> | <launched_at|—> |

## What worked

<!-- OPERATOR-FILL: angles, copy, segment cuts that performed. Cite specific replies / acceptance moments. -->

## What didn't work

<!-- OPERATOR-FILL: what we'd cut, what we'd test differently. -->

## Verdict (per /marketing:campaign-debrief 4-verdict rubric)

<!-- OPERATOR-FILL: SCALE / ITERATE / PAUSE / KILL -->

## Transferable note (optional)

<!-- OPERATOR-FILL: one-sentence learning that should propagate to the MSPA matrix (per docs/gtm-campaign-orchestration-README.md §3.5). -->

---

**Manifest**: [`manifest.json`](manifest.json)
**Linear milestone**: <milestone-url>
**Imported at**: <ISO-8601 UTC of THIS import run>
```

### 11.2 — `analysis-{YYYY-MM}.md` stub

Where `{YYYY-MM}` = the campaign month (e.g., `analysis-2025-09.md` for a September 2025 campaign). Path: `docs/campaigns/<entity>/<slug>/analysis-{YYYY-MM}.md`.

```markdown
# Campaign analysis — <slug> — <YYYY-MM>

> Stub authored by `/marketing:import-campaign` at backfill time (BC-11849).
> `/marketing:campaign-analysis` produces the full 5-verdict ranked artifact;
> this stub captures the import-time snapshot only.

## Snapshot at import (<ISO-8601 UTC>)

| Metric | Value |
|---|---|
| EB records | <N> |
| Workspaces | <comma-separated unique workspaces> |
| Audience tiers | <comma-separated unique audience_tier.tier slugs> |
| Statuses | <comma-separated unique EB statuses> |

## Ranked outcome (per /marketing:campaign-analysis 5-verdict rubric)

<!-- OPERATOR-FILL: TOP PERFORMER / SCALE / TEST MORE / MONITOR / UNDERPERFORM. Rerun /marketing:campaign-analysis to populate. -->

---

**Manifest**: [`manifest.json`](manifest.json)
**Learnings**: [`learnings.md`](learnings.md)
```

Both stubs are atomic single-file writes — no `Read` → mutate → `Write` cycle needed (the dir was created at Step 9; the files don't exist yet because Step 3.3's idempotency gate would have exited if they did).

---

## Step 12 — Summary output

Print the operator-readable summary:

```
=================================================================
Campaign imported — /marketing:import-campaign
=================================================================

  Slug:           <slug>
  Linear:         <milestone-url>  (existing — not modified)
  SF Campaign:    <campaign-url>   (created via σ3, or null + reconciliation reminder)
  Manifest:       docs/campaigns/<entity>/<slug>/manifest.json
  Stubs:          learnings.md + analysis-<YYYY-MM>.md
  EB records:     <N> imported across <K> workspace(s)

=================================================================
```

### 12.1 — Soft-fail reminders (if applicable)

If σ3 SF auto-create soft-failed: append the per-error-kind WARN line (catalog at `/marketing:plan-campaign` Step 8b.1). Always end with:

> To reconcile manually:
> `Skill(skill: "revops:create-sf-campaign", args: "--slug=<slug> --entity=<entity> --vertical=<vertical> --persona=<persona> --offer=<offer> --year=<year> --month=<month> --owner-email=<corrected-owner-email> --launch-date=<launch-date>")`

When the operator supplies a `<corrected-owner-email>` for this reconciliation re-run, re-apply `EMAIL_REGEX` (Step 5) to it before composing the args — this re-entry path does NOT pass back through Step 5's resolution chain, so the boundary guard from Step 10 must be repeated here.

If any EB workspace was unreachable at Step 6.3: append:

> WARN: EB workspace '<ws>' unreachable at import time; <N> requested records absent from manifest.email_bison.campaigns[]. Re-import (delete `docs/campaigns/<entity>/<slug>/` first) once EB auth is restored.

### 12.2 — Hand-off

End with:

> Next step: validate the import via `/marketing:audit-campaigns` (BC-11856) — confirms manifest matches live EB state. For qualitative learnings.md backfill, see BC-11859.

---

## Idempotency notes

This orchestrator is **fully** idempotent: re-running with the same canonical inputs hits the Step 3.3 idempotency gate (existing-manifest detection) and exits with a "no-op" message BEFORE any MCP call or filesystem write. The cohort-1 manifest re-run requirement from the BC-11849 brief is satisfied this way — cohort-1's manifest is byte-identical pre and post re-run because the re-run never reaches Step 9.

If a true re-import is needed (drift, corrupted manifest, etc.):

1. Delete `docs/campaigns/<entity>/<slug>/` entirely.
2. Re-run `/marketing:import-campaign` with the same inputs.

A future `--reset-slug` flag could automate this; out of scope for v1 per the BC-11849 brief's "out of scope" list.

---

## Gotchas

- **`mcp__emailbison-<workspace>__get_campaign` 404s on live IDs** (tracker observation 2026-05-27 / `docs/reconciliation/tracker-log.md` § Cross-tracker observations). Use `list_campaigns` + client-side filter at Step 6.1 — never `get_campaign`.
- **EB MCP namespace has no plugin prefix**: `mcp__emailbison-b2b__list_campaigns` (NOT `mcp__plugin_marketing_emailbison-b2b__list_campaigns`). The EB MCPs register at user level per the BC-5551 HTTP-header limitation; the orchestrator's `allowed-tools` reflects this.
- **`Skill` tool invocation of `/revops:create-sf-campaign`**: the skill returns its single-line JSON via stdout. If the skill emits multi-line output, parse the LAST line that starts with `{` as the JSON object.
- **Linear MCP `get_milestone` response shape**: does NOT include a per-milestone URL — fall back to the project URL via `get_project` (Step 4 F8 pattern from plan-campaign Step 8a.5).
- **Existing-manifest gate fires BEFORE MCP calls** (Step 3.3 sits between Step 3.2 slug-regex and Step 4 Linear fetch). A re-run on cohort-1 is a true no-op — zero MCP cost, zero filesystem mutation, exit 0 with explicit message.
- **`pending_classification` is omitted (not set false)** in import-written manifests for every classifiable record. Per Step 9.3, the operator's Step 8 confirmation IS the classification confirmation — absence of the flag is the contract for "operator-confirmed at import time." The lone exception is a record EB returns with a blank name: it cannot be auto-classified, so the helper stamps a placeholder tier AND `pending_classification: true` so it surfaces for operator review (see Step 9.3 § Exception).
- **Plugin version bump**: changes to this file REQUIRE bumping `plugins/marketing/.claude-plugin/plugin.json` AND the matching `.claude-plugin/marketplace.json` entry in the same commit, per CLAUDE.md's plugin-cache gotcha. The pre-commit hook (`scripts/pre-commit.sh`) enforces this.

---

## Future enhancements (out of v1 scope)

- `--reset-slug` flag for safe re-imports (delete prior dir, then import fresh).
- Auto-detect EB record workspace via dual-probe (drop the explicit `<id>:<workspace>` shape and probe both workspaces for each ID). Defer until BC-11850 batch reconciliation surfaces friction.
- Drift detection between manifest and live EB (already filed as BC-11856).
- Qualitative learnings.md backfill (already filed as BC-11859).
- Batch-mode invocation taking `docs/reconciliation/master-index.json rows[]` array directly (one shell invocation imports all 36-40 historical campaigns). Defer; the row shape is already there — wrap in a loop in the BC-11850 worklist.
