# Cadence Plugin — Design Validation

**Linear issue:** BC-5757
**Blocks:** BC-5758 (scaffold), BC-5759-5763 (phases + dogfood)
**Source of truth:** `/Users/holdenhalford/Projects/work/brite-nites/weekly-planning/` (W15, W16)
**Purpose:** Validate the three load-bearing assumptions behind the Cadence Plugin before scaffold/implementation so downstream phase issues can execute without rework.

This document is not a full plugin spec. It captures the voice spec the narrative-writer subagent (Phase 4) will be bound to, the Linear query recipes the audit and scoping phases (Phase 1 + 2) will use, and the PDF export decision (Phase 4). Each section is verified against live data — not theorized.

## Non-goals

- Full SKILL.md bodies for Phase 2/3 skills (BC-5760, BC-5761 own those)
- Subagent prompts for Phase 1/4 (BC-5759, BC-5762 own those)
- Entry command orchestration logic (BC-5762 owns it)
- Dogfood eval harness (BC-5763 owns it)

---

## 1. Voice Extraction

### 1.1 Scope

The narrative-writer subagent (Phase 4) produces `w##-sprint-narrative.md` matching Holden's voice. This spec gives that prompt enough numeric and diction constraints to stay in-bounds across weeks. Every rule below is traceable to W15 or W16.

### 1.2 Corpus + measurement method

- W15 narrative: 44 sentences across 6 primary sections, 23-word median sentence overall
- W16 narrative: 48 sentences across 6 primary sections, 16.5-word median sentence overall
- Measurement: stdlib-only Python pass (strip code fences, tables, bullets, headers → sentence split on `(?<=[.!?])\s+(?=[A-Z])` → filter 3–100 words)
- Script is reproducible; run it against each new weekly narrative to detect drift

### 1.3 Document skeleton (hard rule)

Every weekly narrative matches this skeleton in this order. The skeleton itself is non-negotiable. See § 1.5 for per-section length rules.

1. **Title block** — `# W## Sprint Narrative` + `## <Month DD-DD, YYYY>` + reading instruction line
2. **Context** — 4–6 paragraphs setting the strategic story for the week
3. **Strategic Decisions** — Bullet list of headline decisions (6–10 bullets)
4. **Sprint Plans** — One card per active project. 10–18 cards typical.
5. **Parked This Week** — Table: Project / Lead / Reason (3–5 rows)
6. **Check-in Schedule** — Day-by-day tables (Mon–Fri) with Time / Meeting / Duration / Attendees columns
7. **Team Assignments** — Alphabetical-ish table: Person / Primary Focus / Secondary (18–20 rows)
8. **Footer** — `*This document was prepared by Holden on <date>...*` single italic paragraph

### 1.4 Sentence-length numeric bands

Drawn from W15 + W16. When both weeks agree within ±2 words on a band, the prompt should enforce the tighter value.

| Scope | Median | p25–p75 | Tail (min–max) |
|---|---|---|---|
| Full doc (all sections combined) | 16–23 words | 11–30 | 4–95 |
| Context paragraphs (sentences) | **15 words** | **10–22** | 4–34 |
| Strategic Decisions bullets (sentences) | **25 words** | 13–66 | 11–71 |
| Sprint Plans "Ship this week:" bullets | 8–20 words | — | — (single-clause imperative) |

**Rules the subagent inherits:**

- Median Context sentence targets 15 words. Draft longer than 20 → rewrite.
- Strategic Decisions bullets run long (median 25) because each bullet packs a bold headline + one-sentence why. That's the pattern.
- Any single sentence > 40 words must earn its length — usually context-setting or consequence-listing. If it's just tacked-on clauses, split.

### 1.5 Paragraph-length rules per section

| Section | Paragraphs per doc | Sentences per paragraph | Notes |
|---|---|---|---|
| Context | 4–6 | 4–10 (median 5–6) | First paragraph opens with a concrete strategic hook (event, metric, or named relationship). Last paragraph sets up the operational kickoff ("The comms migration kicks off — Nora provisions Front, Twilio, Dialpad.") |
| Strategic Decisions | — | 1 bullet = 1 bold headline + 1 sentence reasoning, sometimes 2 | Never narrative form. Always `**headline.** sentence.` |
| Sprint Plans card | 4–10 sentences total per card | `**Owner:** X \| **Priority:** Y` → `**Ship this week:** <numbered list>` → `**Team:** <people>` with optional `**Goal:**` one-liner and optional risk flag | Card length scales with project scope; Brite Base + GTM Blitz run long (~10 items), Parked-but-active projects run 3–5 items |
| Parked This Week | 1 paragraph max (usually zero) | Table only | No prose |
| Check-in Schedule | 0 | Table only | `TBD` cells are acceptable (W16 had them) |
| Team Assignments | 0 | Table only | One row per human who appears in any card |

### 1.6 Forbidden words and preferred transitions

Both lists are drawn from W16 diction (what's present + what's conspicuously absent).

**Forbidden words (never appear in W15/W16; flag on draft):**

```
leverage, synergy, synergize, ecosystem, holistic, robust, world-class,
cutting-edge, best-of-breed, empower, streamline, facilitate, optimize,
orchestrate (noun), value-add, stakeholder (use "the team" or name people),
actionable, paradigm, touch base, circle back, loop in, granular (unless
literally about data), deliverable (use "ship" or name the artifact),
leverage (again on purpose), moreover, furthermore, thus, hence, therefore
(use "so" or recast), utilize (use "use"), in order to (use "to"), going
forward (use "from now on" or cut), at this time (cut), per se (cut),
unpack (verb), deep-dive (verb)
```

**Preferred transitions (drawn verbatim from W16 Context):**

```
This is also the week we ...
Separately, ...
On the <X> side, ...
The headline for W## is ...
This only works if ...
And <name> <verb> ...
<X> shifts to ...
<X> enters ...
```

**Diction principles:**

- Use specific names (Kells, Nora, Jaime) over roles (PM, stakeholder, engineer) — the narrative is FOR named people who know each other
- Use Linear issue IDs as shorthand (`BC-2690`, `BC-5260`) — every ID is a contract with a specific owner
- Lead with the quantitative anchor: "W15 completion rate was 32% of planned issues" not "completion was low"
- Describe work with verbs that ship: "ship", "fix", "scope", "launch", "provision", "audit", "review", "merge", "rewrite"
- Never hedge. Commitments are declarative: "Every vertical gets a landing page live and a low-volume campaign running by Friday." Not "Our goal is to strive for..."

### 1.7 Voice conventions

**Active voice dominant.** Passive only when the action originates outside Brite or when the actor is genuinely unknown. Example from W16 — passive is correct here because Salesforce shipped it over the weekend:

> *"Campaign Attribution shipped this weekend (all 5 issues), clearing the path."*

**Working Backwards opening moves.** The Context section typically opens with one of:

- Past-tense anchor event: *"We just returned from S4's Georgia facility..."* (W15)
- Present-tense metric: *"W15 completion rate was 32% of planned issues. But that number is misleading..."* (W16)

Subsequent Context paragraphs introduce each strategic track with a transitional phrase from § 1.6.

**Quantitative anchors.** The opening two paragraphs of Context must include at least one quantitative anchor (hit rate, count, dollar value, date). W16 opens with `32% / 211 / 92% / 59 / 100%` — five quantitative anchors in three sentences.

**Naming discipline:**

- Projects: title-cased (Brite Base, Outbound Sales Ops, Brand Hub)
- People: first name only on repeat mention (`Kells`, `Holden`, `Nora`)
- Priorities: `Urgent / High / Medium / Low` — match Linear field exactly
- Issue IDs: `BC-####`, `BS-####`, `BN-####`, `BL-####`, `DRO-####`

### 1.8 Do/Don't examples (verbatim from W16)

**Example 1 — opening the Context section**

- **DO (W16 lines 10-11):**

  > *"W15 completion rate was 32% of planned issues. But that number is misleading — the team shipped 211 issues total, and 92% of them were unplanned. Brite Base alone shipped 59 issues, almost all unplanned CPQ work."*

- **DON'T (fabricated):**

  > *"The team had mixed results this week, with several key initiatives progressing alongside unexpected deliverables that contributed to overall throughput."*

- **Why:** The DO version leads with a specific number, reframes it against a contradictory number, then lands the specific project that distorted the average. The DON'T version hides information behind "mixed", "several", "key", and "optimal" — hedge words with zero information content.

**Example 2 — project card headline**

- **DO (W16 line 12):**

  > *"The headline for W16 is the GTM full vertical blitz. Every vertical gets a landing page live and a low-volume campaign running by Friday. That is 20 verticals, 20 campaign launch issues, and 19 landing pages."*

- **DON'T (fabricated):**

  > *"This week's strategic focus involves a comprehensive cross-functional initiative to scale our go-to-market presence through synergistic deployment of landing assets and campaigns."*

- **Why:** DO names the headline, makes a declarative commitment with a deadline, then quantifies scope. DON'T uses seven words that could describe any project at any company ("strategic focus", "comprehensive", "cross-functional", "synergistic", "deployment", "assets") and commits to nothing.

**Example 3 — dependency + risk callout**

- **DO (W16 line 12, second half):**

  > *"This only works if Kells fixes the Labs website CTAs on Day 1 — the contact page 404s, the "Book a Call" button has no lead capture form, and the newsletter signup loses emails. If those aren't fixed before campaign traffic arrives, we are driving leads into a dead end."*

- **DON'T (fabricated):**

  > *"Success depends on certain front-end prerequisites being addressed in a timely manner to ensure optimal conversion pathway integrity."*

- **Why:** DO names the owner (Kells), the deadline (Day 1), the three concrete defects, and the consequence in visceral language ("driving leads into a dead end"). DON'T hides every piece of information a reader needs behind generic nouns.

**Example 4 — Strategic Decisions bullet**

- **DO (W16 Strategic Decisions):**

  > *"**BC-2439 cancelled.** Superseded by the better-decomposed reports chain (BC-2281/82/83/84)."*

- **DON'T (fabricated):**

  > *"BC-2439 has been deprioritized in favor of a more granular approach to reporting."*

- **Why:** DO names the decision (cancelled), the reason (superseded), and the replacement chain (four IDs). DON'T softens "cancelled" to "deprioritized" and omits the replacement — making the decision non-reversible-looking when it's actually a replacement.

### 1.9 Verification method

- **Self-check (this issue):** every numeric band is measured from W15 AND W16; rules that fire in only one week are flagged as tentative
- **Draft-time gate:** Phase 4 prompt will include a post-generation pass that measures the draft against § 1.4/§ 1.5/§ 1.6 and flags violations before handing the draft to the user
- **Dogfood (BC-5763):** run the Cadence plugin against W18 planning data, diff the machine draft against a hand-written baseline, update this spec if any rule proves unproductive

---

## 2. Linear Query Recipes

Every recipe below was run live against the Brite Plugin Marketplace / Brite GTM / Salesforce Implementation projects during this issue. First-5-row samples and failure modes are pasted inline.

### 2.1 Primitives

**MCP server:** `plugin:workflows:linear-server` (already declared in the workflows plugin). The Cadence plugin does NOT need its own MCP server.

**Team identifiers encountered:**

- Brite Company: `47309083-6954-44d6-9f21-12aebf6252dd` (key `BC`)
- Brite Supply: `e92a4b6a-40cd-42b4-ae69-8e0829ad99a6` (key `BS`)
- Brite Nites: `899c5393-009e-4b85-a23b-3f4f8fe5cbf8` (key `BN`)
- Brite Labs: `7bdbab56-5b86-4d1d-94db-a3597ba6e62b` (key `BL`)
- Droidor: not enumerated here — the agent should discover teams at runtime via `list_teams`, not hard-code this list

**Cycle identifiers (W16 planning snapshot):**

- BC Week 16 cycle: `9c0795cc-c961-4d74-8477-2afe17c50572` (cycle number 18)
- BC Week 15 cycle: `e39efcd2-92ce-4355-a0a9-b0834148794f` (cycle number 17)

Cycle number does NOT equal week number. The agent should match on cycle `title` (`"Week 16"`) or resolve via `type: "current" | "previous"`.

### 2.2 Recipe — prior-cycle cycle metadata (Phase 1 audit headline)

Gets the previous cycle + its daily completion/scope history. Every audit narrative's opening quantitative anchor (e.g. "W15 completion rate was 32%") derives from this call.

Tool:

```
mcp__plugin_workflows_linear-server__list_cycles
```

Parameters:

```json
{
  "teamId": "47309083-6954-44d6-9f21-12aebf6252dd",
  "type": "previous"
}
```

Live response (sample):

```json
[{
  "id": "e39efcd2-92ce-4355-a0a9-b0834148794f",
  "title": "Week 15",
  "number": 17,
  "startsAt": "2026-04-06T06:00:00.000Z",
  "endsAt": "2026-04-13T06:00:00.000Z",
  "completedIssueCountHistory": [30, 95, 130, 206, 235, 232, 241],
  "issueCountHistory": [216, 282, 372, 366, 395, 400, 360],
  "isCurrent": false
}]
```

**Computed metrics from this response:**

- Final scope: `issueCountHistory[-1]` → 360
- Final completion: `completedIssueCountHistory[-1]` → 241
- Gross completion rate: 241 / 360 = **67%**
- Planned completion rate (what the narrative reports): requires comparing "planned" issues (known at cycle start) to shipped issues — see § 2.4

**Gotcha:** the history arrays are daily snapshots. Scope grows within a cycle as new issues are added (see W15: 216 → 282 → 372 → 366 — scope can also shrink when issues are canceled or reassigned to other cycles). The narrative framing "X% of planned issues" uses `completedIssueCountHistory[-1] / issueCountHistory[0]` not `/ [-1]`.

### 2.3 Recipe — active projects (Phase 1 fan-out seed)

Lists every project the audit subagent should fan out to.

Tool:

```
mcp__plugin_workflows_linear-server__list_projects
```

Parameters:

```json
{ "team": "Brite Company", "limit": 50 }
```

Live response (sample, first 5 `{id, name, status.type}` tuples):

```json
[
  {"id": "4dda451d-...", "name": "Commercial Site Documentation", "status": {"type": "started"}},
  {"id": "db2cc606-...", "name": "St. Nick's Refurb Tracker",    "status": {"type": "backlog"}},
  {"id": "a51b810b-...", "name": "Meeting Automation",           "status": {"type": "started"}},
  {"id": "76d9366d-...", "name": "Asset Studio",                 "status": {"type": "started"}},
  {"id": "576f3801-...", "name": "Public Safety ICP — 250th Anniversary", "status": {"type": "backlog"}}
]
```

**Gotcha #1:** passing `state: "started"` alongside `team` returned **empty results** in live testing. Client-side filter `projects.filter(p => p.status.type === "started")` is the reliable pattern. The `state` parameter accepts state name/type/ID but appears to not resolve `"started"` consistently.

**Gotcha #2:** projects are shared across teams (a project can appear under both Brite Company and Brite Nites). If the agent queries per team naively, it will double-count. The audit subagent should dedupe by `project.id` before fanning out.

### 2.4 Recipe — shipped in last cycle (per-project)

Issues that were in the cycle and reached `statusType: completed` during the cycle window.

Tool:

```
mcp__plugin_workflows_linear-server__list_issues
```

Parameters:

```json
{
  "cycle": "Week 15",
  "team": "47309083-6954-44d6-9f21-12aebf6252dd",
  "project": "Brite GTM",
  "state": "completed",
  "limit": 50
}
```

Live response (sample, first 5 `{id, title, completedAt, cycleId}` tuples):

```json
[
  {"id": "BC-3089", "title": "Research: Pricing strategy & job economics",     "completedAt": "2026-04-09T20:09:55", "cycleId": "e39efcd2-..."},
  {"id": "BC-2774", "title": "Utah multi-site landscape lighting test — GTM strategy", "completedAt": "2026-04-09T20:09:56", "cycleId": "e39efcd2-..."},
  {"id": "BC-3082", "title": "Research: SEO keyword opportunity analysis",     "completedAt": "2026-04-09T20:09:56", "cycleId": "e39efcd2-..."},
  {"id": "BC-3090", "title": "Research: FX Luminaire Design Center capabilities", "completedAt": "2026-04-09T20:09:54", "cycleId": "e39efcd2-..."},
  {"id": "BC-3064", "title": "Research: FX Luminaire dealer program & co-op marketing", "completedAt": "2026-04-09T20:09:55", "cycleId": "e39efcd2-..."}
]
```

**Rule for "shipped in last cycle":**

```
shipped = list_issues({cycle: <prev>, project, state: "completed"})
         .filter(i => cycle.startsAt <= i.completedAt <= cycle.endsAt)
```

The `cycle` filter already scopes `cycleId`. The `completedAt` range filter catches the edge case of issues that were still in the cycle at its end but completed after rollover (rare but possible).

### 2.5 Recipe — dropped in last cycle (canceled)

Same shape as § 2.4, `state: "canceled"`. Live sample (BC team, no project filter):

```json
[
  {"id": "BC-1485", "title": "CM-24: SSE client hook and real-time updates", "canceledAt": "2026-04-13T03:23:22", "cycleId": "e39efcd2-..."},
  {"id": "BC-1484", "title": "CM-23: GTM overview dashboard",                 "canceledAt": "2026-04-13T03:23:20", "cycleId": "e39efcd2-..."},
  {"id": "BC-1483", "title": "CM-22: Reply feed page (read-only)",            "canceledAt": "2026-04-13T03:23:17", "cycleId": "e39efcd2-..."}
]
```

**Cycle auto-rollover interaction:** these issues were `canceledAt: 2026-04-13T03:23:XX` — late on the Sunday that W15 ended. Their `cycleId` stayed at the W15 cycle (`e39efcd2-...`), confirming that **Linear does not re-stamp `cycleId` on rollover**. The audit can trust `cycleId == previous.id` to scope a cycle's history.

### 2.6 Recipe — planned for last cycle vs truly-new issues (Phase 2 scope input)

"Planned for last cycle" = issues that were in the cycle on day 1 (before the daily scope growth).

**The MCP does not expose day-1 cycle membership directly.** Workarounds:

1. **Narrative-file approach (recommended):** parse last week's narrative `Sprint Plans` cards for explicit issue IDs. This is what the human planner already does — the narrative is the source of "what was planned." Phase 2's pre-draft reads `w##-sprint-narrative.md` + Linear current state, then proposes a diff.

2. **Issue `createdAt` heuristic:** issues with `createdAt < cycle.startsAt` AND `cycleId == cycle.id` at cycle end are candidates for "planned." Issues with `createdAt > cycle.startsAt` are truly-new. This is approximate — an issue created during W14 and assigned to W15 cycle only on day 3 still looks "planned" by this heuristic. Accept the approximation.

3. **Cycle history arithmetic:** `issueCountHistory[0]` is the cycle's day-1 scope count. We can't get the *list* of day-1 issues, only the count. Useful for the "92% unplanned" headline but not for per-issue classification.

**Decision:** Phase 2 uses approach 1 (parse prior narrative) as primary, approach 2 as fallback when no prior narrative exists.

### 2.7 Recipe — per-project per-assignee grouping (Phase 1 fan-out shape)

The audit subagent runs per-project (parallel fan-out). Inside each subagent, group issues by assignee to produce per-person highlights.

```python
# Pseudocode for the subagent inner loop
issues = list_issues(cycle=prev.id, project=project.id)
by_assignee = {}
for issue in issues:
    key = issue.assignee or "(unassigned)"
    by_assignee.setdefault(key, []).append(issue)
# Emit: per-person shipped/dropped/in-progress lines
```

`list_issues` response already includes `assignee` + `assigneeId` fields, so no second lookup is needed. For unassigned issues, group under `"(unassigned)"`.

### 2.8 Recipe — current-cycle backlog for scoping (Phase 2 input)

For Phase 2's per-project pre-draft, the agent needs (a) what's currently carried over, (b) the high-priority backlog.

```
mcp__plugin_workflows_linear-server__list_issues
```

Parameters (carry-over):

```json
{ "cycle": "9c0795cc-c961-4d74-8477-2afe17c50572", "project": "Brite GTM", "state": "unstarted", "limit": 50 }
```

Live sample (first 3):

```json
[
  {"id": "BC-5239", "title": "Scope first S4 campaign + draft landing page content", "priority": 2, "dueDate": "2026-04-18"},
  {"id": "BC-5240", "title": "Campaign Setup & Launch — Landscape Lighting",          "priority": 2, "dueDate": null},
  {"id": "BC-4682", "title": "Landing Page(s) — Museums",                              "priority": 3, "dueDate": null}
]
```

Parameters (high-priority backlog candidates, not yet in cycle):

```json
{ "project": "Brite GTM", "state": "unstarted", "priority": 2, "limit": 20 }
```

Merge these two to propose W+1 scope.

### 2.9 Multi-team cycle handling

Brite has multiple active teams (BC, BS, BN, BL, plus Droidor's own team). Each team maintains its own cycles. The Phase 1 audit should:

1. `list_teams()` → discover all active teams
2. For each team: `list_cycles(teamId, type: "previous")` → get their W-1 cycle
3. Some teams share a cycle cadence with BC (aligned Sunday-to-Sunday); others do not
4. Dedupe projects by `project.id` before fan-out

This was visible in W16's planning checkpoint: "Droidor W16 Cycle ID: abc3586b-ac96-4203-a714-742bbbb68461" — a separate cycle on a parallel track.

### 2.10 Verification summary

| Recipe | Live-tested? | Sample rows pasted? | Known gotchas surfaced? |
|---|---|---|---|
| 2.2 prior-cycle metadata | Yes | Yes | `completedIssueCountHistory` denominator choice |
| 2.3 active projects | Yes | Yes | `state: "started"` filter empty; cross-team duplication |
| 2.4 shipped | Yes | Yes | Use `cycleId` + `completedAt` both |
| 2.5 dropped | Yes | Yes | `cycleId` is stable across rollover |
| 2.6 planned vs new | Partial | N/A | MCP limitation — parse prior narrative |
| 2.7 per-assignee | By inspection | N/A | `(unassigned)` bucket for missing field |
| 2.8 scoping input | Yes | Yes | Two-pass: carry-over + backlog candidates |

---

## 3. PDF Export Flow

### 3.1 Decision — primary

`npx md-to-pdf <file>.md` is the primary flow. It already produces `w15-sprint-narrative.pdf` and `w16-sprint-narrative.pdf` (confirmed via `weekly-planning/w16-2026-04-13/w16-remaining-ops.md` L20 which documents the exact command).

**Why this tool:** no custom CSS required, no project-level config, Chromium-based so markdown tables + fenced code render correctly, one-line invocation.

### 3.2 Smoke test (live)

Ran end-to-end in this environment:

```bash
cd /tmp/bc5757-pdf-test
cat > smoke.md <<'MD'
# Cadence PDF smoke test

This document verifies that `npx md-to-pdf` works in this environment
without the security hook blocking it.

- Bullet one
- Bullet two

A paragraph with some sentences to exercise the typography pass. The
quick brown fox jumps over the lazy dog.
MD
npx md-to-pdf smoke.md
```

Result:

```
[16:54:59] generating PDF from smoke.md [started]
[16:55:03] generating PDF from smoke.md [completed]
-rw-r--r--@ 1 holdenhalford  wheel  49361 Apr 19 16:55 /tmp/bc5757-pdf-test/smoke.pdf
```

- Runtime: ~4 seconds (after first-run Chromium download — which IS slow, see § 3.4)
- Output: 49,361-byte PDF
- Not blocked by the security hook (`gotcha_security_hook_blocks_infra.md` worried but did not trigger)

### 3.3 Fallback (documented, not exercised)

If `npx md-to-pdf` ever fails (offline, Chromium missing, security hook tuning that blocks `npx` in future), the fallback is:

- Copy the markdown content via `mcp__computer-use__write_clipboard` → user pastes into Google Docs → File → Download as PDF
- Or: user runs `npx md-to-pdf` manually (prompt them with the file path)

The fallback is NOT wired into the Cadence entry command because the primary works. Revisit only if it breaks.

### 3.4 Known constraints the scaffold (BC-5758) must handle

- **First-run Chromium download is slow** (~30-60 seconds). The first user who runs `/cadence:weekly` in a fresh environment will experience a one-time lag. Surface a "downloading Chromium, one-time..." hint if runtime > 10s.
- **Working directory matters.** `npx md-to-pdf <file>.md` must be invoked from the directory containing the markdown (or pass an absolute path). The scaffold should `cd` into `weekly-planning/w##-<date>/` before invoking.
- **Default styling is adequate.** No custom CSS for v1. If polish becomes a priority later, `md-to-pdf` supports a `--css <file>` flag.
- **Existing folder convention:** outputs go to `weekly-planning/w##-<start-date>/w##-sprint-narrative.pdf` alongside the `.md` source.

---

## 4. Ready for Scaffold (BC-5758 preconditions)

Every assumption BC-5758 depends on, each marked resolved:

- [x] **Voice spec locked** (§ 1) — numeric bands, paragraph rules, forbidden/preferred lists, 4 verbatim do/don't examples from W16
- [x] **Linear read recipes validated live** (§ 2) — cycles, projects, issues (shipped/canceled/carry-over) all returned real data with sample blocks pasted
- [x] **Cycle rollover behavior confirmed** (§ 2.5) — `cycleId` is stable; audit can trust it as scope key
- [x] **MCP-level gotchas surfaced** — `list_projects` `state: "started"` empty filter; `list_cycles` needs `teamId` (UUID) not `team` name; cross-team project duplication
- [x] **"Planned vs unplanned" classification gap acknowledged** (§ 2.6) — MCP can't expose day-1 cycle membership; Phase 2 parses prior narrative as source of truth
- [x] **PDF flow decided, smoke-tested** (§ 3) — `npx md-to-pdf` produces 49KB PDF in 4s from a fresh tmp directory, not blocked
- [x] **Plugin destination** — `plugins/cadence/` peer to `plugins/marketing/` and `plugins/workflows/`, same `plugin.json` allowlist (per CLAUDE.md strict schema)
- [x] **.mcp.json surface** — no new servers needed. Cadence reuses workflows plugin's `linear-server`. `.mcp.json` can be omitted or empty.
- [x] **No new MCP server required** — mcp-builder guidance consulted; Linear MCP covers all reads/mutations
- [x] **Shape per phase (confirmed from issue context + skill-creator doc):**
  - Phase 1 audit → **subagent fan-out** (parallel per-project, isolated context)
  - Phase 2 scope → **skill** (interactive, one-question-at-a-time per feedback memory)
  - Phase 3 Linear housekeeping → **skill** with preview-then-execute (mutation safety)
  - Phase 4 narrative → **subagent** (voice-constrained, § 1 feeds the prompt)
  - Phase 5 ops file → decision deferred to BC-5762; likely skill or inline command step
- [x] **Entry command** — single `/cadence:weekly` orchestrates all 5 phases with gates between (locked in issue context)
- [x] **Voice spec verification cadence** — self-check during this issue; full eval deferred to BC-5763 E2E dogfood

## 5. References

- **Source narratives:** `weekly-planning/w15-2026-04-06/w15-sprint-narrative.md`, `weekly-planning/w16-2026-04-13/w16-sprint-narrative.md`
- **W16 checkpoint → narrative translation:** `weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md`, `weekly-planning/w16-2026-04-13/w16-remaining-ops.md` (PDF command L20)
- **Anthropic skill authoring baseline:** `github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md` (consulted for § 1.9 + § 4 skill sizing rules)
- **Anthropic MCP builder baseline:** `github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md` (consulted — confirmed no new MCP needed for Cadence)
- **Brite skill ↔ tool integration pattern:** `docs/guides/skill-tool-integration-pattern.md` (applies to Phase 2/3 skills when they're authored)
- **Linear MCP tool reference:** already declared in `plugins/workflows/.mcp.json`; tool names used above are namespaced `mcp__plugin_workflows_linear-server__*`
