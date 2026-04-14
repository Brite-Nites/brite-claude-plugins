# BC-2715 Plan — Map Brite's multi-channel demand gen

**Issue:** [BC-2715](https://linear.app/brite-nites/issue/BC-2715) — Research (Urgent)
**Output:** `docs/research/demand-gen-findings.md`
**Blocks:** BC-2722 outbound-playbook, BC-2723 linkedin-outreach, BC-2724 event-marketing
**Pattern reference:** `docs/research/outbound-pipeline-findings.md`

## Brainstorm decisions

- **Scope**: net-new channels only — LinkedIn, events, partnerships, calling, PLG, YouTube, press/announcements. Cold email stays in outbound findings; cross-link.
- **Entity map**: discover from handbook + repos first, compare Linear issue's assertions at the end (document matches / mismatches).
- **Partnerships**: not in any existing skill scope — flag as a gap and recommend a new `partnerships` skill issue.
- **External depth**: 3+ named sources per channel with quantitative benchmarks.
- **Ground-truth discipline (per BC-2714 precedent)**: every claim tagged `[VERIFIED <date>]`, `[CORRECTED <date>: ...]`, `[DEFERRED: ...]`, or `[UNCERTAIN]`.

## Constraints

- Conservation: don't duplicate outbound-pipeline-findings content — cite and link.
- Handbook access via Context7 (`/brite-nites/handbook` per memory).
- GitHub MCP for cross-repo reads (no local clones per ADR).
- Memory: `feedback_research_beyond_handbook.md`, `feedback_one_question_at_a_time.md`, `feedback_thorough_audits.md`.

## Task breakdown

### Task 1 — Worktree + baseline
- Create worktree on `holden/bc-2715-research-map-brites-multi-channel-demand-gen-for-skill`
- Verify clean `./scripts/validate.sh` or skip (docs-only change — validate runs anyway).
- **Verify**: `git status` clean, branch matches Linear `gitBranchName`.

### Task 2 — Handbook pass (Context7)
- Query Context7 `/brite-nites/handbook` for each of: "demand generation strategy", "LinkedIn outreach", "event marketing", "trade shows", "webinars", "conference strategy", "partnerships", "venue partnerships", "warm calling", "product-led growth", "Brite Base", "Brite Supply", "Brite Labs", "YouTube", "press".
- Capture: what the handbook *says* exists, by entity, by channel.
- **Verify**: each query produces either (a) cited handbook content or (b) an explicit "no handbook content found" note. No quiet omissions.

### Task 3 — Repo scan (GitHub MCP)
- Scan `Brite-Nites/brite-salesforce` for Campaign object, Lead_Source values, event-related custom fields.
- Scan `Brite-Nites/brite-data-platform` for event-source loaders, audience views tagged by channel.
- Scan `Brite-Nites/outbound-sales-ops` for LinkedIn (HeyReach) or event webhook handling — confirm presence/absence.
- Scan for any LinkedIn automation (HeyReach) — config files, cron jobs, Salesforce fields.
- **Verify**: every entity × channel cell in the matrix has repo evidence OR an explicit "no repo evidence" note.

### Task 4 — External best-practices research
- Per channel (LinkedIn / events / partnerships / warm calling / PLG), pull 3+ named sources with quantitative benchmarks.
- Canonical sources to try first (one per channel minimum): Pavilion, GTMnow, Gong Labs, HubSpot State of Marketing, HeyReach/Dripify reports, B2B Marketing Exchange, Mark Roberge / Jason Lemkin, Reforge.
- Capture benchmark, source URL, publish date, and how it compares to Brite's current state.
- **Verify**: each channel has ≥3 sources with dated benchmarks.

### Task 5 — Entity × channel matrix (discovery)
- Build the matrix (rows: Brite Nites / Supply / Base / Labs; columns: active channels / planned channels / not relevant) **purely from handbook + repos**.
- Only after drafting it: compare against the Linear issue's assertions. Mark each cell as one of: `MATCHES_ISSUE`, `CONTRADICTS_ISSUE (evidence: ...)`, `ISSUE_SILENT`, `GAP (not found anywhere)`.
- **Verify**: every cell has evidence or an explicit gap flag.

### Task 6 — Skill boundary recommendations
- For each of BC-2722 / BC-2723 / BC-2724: proposed scope, explicit exclusions, channel ownership.
- Partnerships: gap section — justification for a new `partnerships` skill + proposed Linear issue (don't create yet; user approves at review).
- Warm calling: explicit call-out for where it lives (probably outbound-playbook; confirm).
- **Verify**: each of the 3 downstream skills has a named owner-skill for every channel the findings doc surfaces.

### Task 7 — Checkpoints with user
- At end of Task 2 (handbook pass): 1-question checkpoint on surprising handbook coverage/gaps.
- At end of Task 5 (entity matrix): 1-question checkpoint on any cells where handbook contradicts the issue's assertions.
- At end of Task 6 (skill boundaries): 1-question checkpoint before finalizing the doc.
- **Feedback memory compliance**: one question at a time; don't batch.

### Task 8 — Write `docs/research/demand-gen-findings.md`
- Structure matches the issue's template + mirrors outbound-pipeline-findings.md's layer structure.
- Every claim tagged with verification status.
- Cross-links to outbound-pipeline-findings.md for cold email.
- Close with: open questions, handbook drift list (for handbook-drift-check on ship), next actions (new `partnerships` skill issue).
- **Verify**: `./scripts/check-guardrails.sh --claude-md docs/research/demand-gen-findings.md` passes (docs-only anti-slop). Doc renders cleanly in preview.

### Task 9 — Ship checklist preview
- Not shipping this session — but confirm the findings doc references BC-2715 and sets up the next 3 skill PRs to cite it.
- **Verify**: BC-2722/2723/2724 each have a clear "Read: `docs/research/demand-gen-findings.md`" anchor in the findings doc.

## Acceptance criteria (from Linear)

- [ ] All handbook demand gen content read and summarized
- [ ] Channel-to-entity mapping documented (with verification tags)
- [ ] Clear skill boundary recommendations for BC-2722 / BC-2723 / BC-2724
- [ ] Findings doc written at `docs/research/demand-gen-findings.md`
- [ ] Additional: partnerships gap flagged with proposed follow-up issue scope

## Risks / open questions

- **Handbook availability**: Context7 didn't resolve `/brite-nites/handbook` in prereq check today; may need to fall back to GitHub MCP against the handbook repo. Verify early in Task 2 and escalate if neither route works.
- **Repo evidence sparse for demand gen**: unlike outbound (3 repos), LinkedIn/events/partnerships may have little code. Plan accommodates this via explicit "no repo evidence" notes.
- **External source quality**: 3+ named sources per channel is ambitious for partnerships; may need to lower to 2 and disclose in findings.
