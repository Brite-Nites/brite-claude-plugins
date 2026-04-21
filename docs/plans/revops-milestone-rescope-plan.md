# RevOps Plugin Milestone — Scope Rebalancing Plan

**Type:** Meta-planning artifact (no Linear issue — this plan organizes other Linear issues)
**Date:** 2026-04-21
**Author:** Holden Halford
**Scope:** Rescope 8 of the 14 remaining Todo issues in the RevOps Plugin milestone to reduce ceremony overhead and separate cross-repo work from single-repo work.

---

## 1. Context

Recent RevOps sessions (BC-5790, BC-5791) each generated hundreds of lines of session summary and 19+ review findings. The user's felt sense was that remaining Todo work may be over-scoped. A full-description audit of the 14 remaining Todo issues confirmed two distinct over-scoping patterns:

1. **Cross-repo spillage** — BC-5785 bundles a plugins-repo documentation task with a conditional brite-salesforce PR for permset tightening. The two halves have different blast radius (read-only vs destructive-to-org) and different ship cadences.
2. **Template-heavy ceremony on near-identical siblings** — BC-5799 through BC-5805 are seven Phase 3 skill customizations, each following the exact same template (edit ONE `SKILL.md`, add 5–10 Brite-specific bullets, 7–9 grep/validate tests, 1 commit). The actual work per skill is ~20 min; the per-session ceremony (TaskCreate, ≥3 check-in gates, plan approval, verify) is 30–60 min. Seven siblings × solo ceremony = 3.5–7 hours of pure overhead.

This plan rescopes the over-scoped issues, **preserving 100% of the original content in aggregate**, and produces 5 new issues to replace 8 absorbed originals.

---

## 2. Audit findings

### 2.1 The 14 remaining Todo issues

| BC ID | Title | Priority | Verdict |
|-------|-------|----------|---------|
| BC-5784 | Tighten marketing SF MCP config (--no-telemetry + docs) | Medium | Right-sized |
| BC-5785 | Audit Marketing_Claude_MCP service user permission baseline | High | **Over-scoped → split** |
| BC-5786 | Document SF capability adoption decision framework | Low | Right-sized |
| BC-5787 | Watch @salesforce/mcp for 0.31+ / Headless 360 landing | Low | Right-sized |
| BC-5792 | Build /revops:post-deploy-runbook orchestration command | High | Right-sized (template-inheriting, BC-5791-sized by design) |
| BC-5799 | Customize sf-testing | Medium | **Batch into Group A** |
| BC-5800 | Customize sf-debug | Medium | **Batch into Group A** |
| BC-5801 | Customize sf-flow | Medium | **Batch into Group B** |
| BC-5802 | Customize sf-lwc | Low | **Batch into Group B** |
| BC-5803 | Customize sf-data | Low | **Batch into Group C** |
| BC-5804 | Customize sf-docs | Low | **Batch into Group C** |
| BC-5805 | Customize sf-integration | Low | **Batch into Group C** |
| BC-5806 | Build RevOps SessionStart hook | Medium | Right-sized |
| BC-5820 | Evaluate porting 3 KEEP-aligned Jaganpro agents | Low | Right-sized (research only) |

### 2.2 Post-rescope state

- **Unchanged (right-sized):** BC-5784, BC-5786, BC-5787, BC-5792, BC-5806, BC-5820 (6 issues)
- **Absorbed (to be canceled):** BC-5785, BC-5799, BC-5800, BC-5801, BC-5802, BC-5803, BC-5804, BC-5805 (8 issues)
- **New (to be created):** 5 issues (2 from BC-5785 split + 3 grouped Phase 3 issues)
- **Net Todo count:** 14 → 11

---

## 3. Rescope actions

### 3.1 Action 1 — split BC-5785 into two issues

Both parts share the goal: **harden the Marketing_Claude_MCP service user's blast radius before the first SF-consuming skill ships (BC-2717 et al).**

**Part A — "Audit Marketing_Claude_MCP service user permission baseline (plugins-repo doc only)"**
- Priority: High (inherits from BC-5785)
- Content absorbed from BC-5785:
  - §Context (blast-radius rationale)
  - §Phase structure (explore → plan → execute → verify)
  - §TaskCreate entries for exploration + documentation
  - §Explore steps 1–6 (service-user identity SOQL, permset-assignment SOQL, object-permissions SOQL, cross-reference with user-role-matrix, enumerate minimum-required per skill)
  - §Plan deliverable 1 (§Service User Permissions section in `plugins/marketing/tools/integrations/salesforce.md` — 40 lines covering identity, permset assignments, 11-object CRUD matrix, destructive capabilities, 5-skill minimum-required matrix, link to Part B if tightening needed)
  - §Execute steps 1 + 3 (edit salesforce.md + commit)
  - §Verify tests T1–T5 + T8 (plugin-repo-only: grep counts, section lists actual permset names, 11-object CRUD matrix, 5-skill matrix, validate.sh exit 0, cross-repo MCP query returns row)
  - §Out-of-scope items
  - §Related links
- Scope statement: read-only SF org queries + single-repo doc edit. No org mutations.

**Part B — "Tighten Marketing_Claude_MCP service user permissions (brite-salesforce permset PR, conditional on Part A findings)"**
- Priority: High (inherits from BC-5785); blockedBy Part A
- Content absorbed from BC-5785:
  - §Context (conditional rationale — only files if Part A surfaces over-provisioning)
  - §Phase structure (explore → plan → execute → verify)
  - §Explore step: derive specific permset metadata changes from Part A's findings
  - §Plan deliverable 2 (brite-salesforce permset metadata edits — .permissionset-meta.xml + .object-meta.xml changes)
  - §Execute step 2 (brite-salesforce PR: dry-run deploy + Apex test run + user approval gate BEFORE merge)
  - §Verify tests T6 + T7 (post-tightening: PermissionsModifyAllData = false on service-user permsets; service user still runs `SELECT Id FROM User LIMIT 1` via MCP)
  - §Out-of-scope items
  - §Related links
- Scope statement: conditional — may not need to exist if Part A's audit shows no over-provisioning. If so, file issue with "Not applicable — Part A audit found no over-provisioning" as the closure note.

### 3.2 Action 2 — batch BC-5799-5805 into three grouped issues

All three groups share the goal: **Brite-customize retained Phase 3 skills (from Jaganpro/sf-skills subtree) against `brite-salesforce/CLAUDE.md` conventions so SF-adjacent repos get skill auto-activation with Brite-specific discipline.**

Grouping is by technical coupling (shared source material + related gotcha sets), not priority. Priority mix is retained per-skill within each group.

**Group A — "Customize Phase 3 skills — sf-testing + sf-debug (Apex-diagnostic discipline)"**
- Priority: Medium (both absorbed originals were Medium)
- Absorbs: BC-5799 (sf-testing, Medium) + BC-5800 (sf-debug, Medium)
- Coupling: both cite `brite-salesforce/CLAUDE.md §Apex & Automation`, both share the `Test.stopTest()` async-drain gotcha (sf-testing: Queueables re-enter handlers; sf-debug: diagnostic pattern when fixtures leave static flags).
- Aggregate verify count: 9 (sf-testing T1-T9) + 7 (sf-debug T1-T7) = 16 tests

**Group B — "Customize Phase 3 skills — sf-flow + sf-lwc (declarative UI + deploy gotchas)"**
- Priority: Medium (uses the higher of the two absorbed — BC-5801 Medium; BC-5802 Low)
- Absorbs: BC-5801 (sf-flow, Medium) + BC-5802 (sf-lwc, Low)
- Coupling: both declarative-UI, both have deploy-time gotchas (Flow Draft-on-deploy; Flexipage IndexedDB cache). Both cross-reference FLS rules; sf-flow cross-links to `/revops:post-deploy-runbook` (BC-5792).
- Aggregate verify count: 7 (sf-flow T1-T7) + 7 (sf-lwc T1-T7) = 14 tests

**Group C — "Customize Phase 3 skills — sf-data + sf-docs + sf-integration (external systems + reference)"**
- Priority: Low (all three absorbed originals were Low)
- Absorbs: BC-5803 (sf-data, Low) + BC-5804 (sf-docs, Low) + BC-5805 (sf-integration, Low)
- Coupling: sf-data + sf-integration share HubSpot migration + Named Credentials themes; sf-docs is the lightest navigational skill and naturally lands here as the "reference + external" cohort (it points to `brite-salesforce/docs/artifacts/`, `brite-handbook`, `brite-data-platform`).
- Aggregate verify count: 7 (sf-data T1-T7) + 7 (sf-docs T1-T7) + 8 (sf-integration T1-T8) = 22 tests

### 3.3 Action 3 — close originals with cancellation comments

After all 5 new issues are created AND verified:

- Set each absorbed original (BC-5785, BC-5799, BC-5800, BC-5801, BC-5802, BC-5803, BC-5804, BC-5805) to **Canceled** status.
- Add a comment on each original with the template:
  > Absorbed into **BC-NNNN** (successor). See `docs/plans/revops-milestone-rescope-plan.md` for rescope rationale. All original content preserved in the successor's per-item subsections; verify tests preserved verbatim.
- **Do not** use Duplicate status — the content isn't duplicated, it's reorganized.
- **Do not** delete the originals — they remain visible in Linear as audit trail.

---

## 4. New-issue body template (10-item structural contract)

Every new issue body MUST contain these 10 items. The verification agent enforces this.

1. **§Context** — grouping/split rationale + explicit "Absorbs: BC-NNNN, BC-MMMM" statement + plan-file reference.
2. **§Goal** — single-sentence shared goal. Must align with each absorbed original's implicit goal.
3. **§Phase structure** — "Follow **explore → plan → execute → verify**. Each phase has explicit check-in gates."
4. **§Task tracking** — `TaskCreate` directive listing all phase entries + per-sub-item execute entries + check-in gate entries. `TaskUpdate` in_progress/completed immediately, never batch.
5. **§Check-in cadence (GENEROUS)** — explicit gate list. For N-sub-item issues, MINIMUM: after Explore, after Plan, BEFORE each sub-item Execute, AFTER each sub-item Execute (before next), after all Executes, after Verify. For a 2-item issue → 6 gates; 3-item → 7 gates. "One question at a time." directive.
6. **§Explore** — shared explore steps + per-sub-item explore subsections (content preserved verbatim from absorbed originals' Explore sections).
7. **§Plan (check-in gate)** — per-sub-item plan subsections (bullets preserved verbatim from absorbed originals' Plan sections).
8. **§Execute** — per-sub-item execute subsections, each ending with "**CHECKPOINT:** verify with user before proceeding to next sub-item".
9. **§Verify — Objective criteria** — per-sub-item verify tables (every row preserved verbatim from absorbed originals' verify tables). Objective = grep/exit-code/numeric — never "works correctly" or subjective.
10. **§Out of scope + §Related** — union of absorbed originals' out-of-scope items; §Related links to every absorbed original + `docs/plans/revops-milestone-rescope-plan.md` + `docs/plans/revops-plugin-master-plan.md`.

---

## 5. Verification agent spec

### 5.1 When to spawn

After each new issue is created via `save_issue`, BEFORE proceeding to the next new issue. One fresh agent per new-issue verification (no reuse — isolation keeps comparisons focused).

### 5.2 Agent type

`general-purpose` (needs thorough content comparison + can read files if needed). Not `Explore` — this isn't search, it's comparison.

### 5.3 Prompt template

```
You are a content-preservation verification agent. Your job is to confirm that the
content of N original Linear issues has been preserved in aggregate within a new
consolidated Linear issue.

## Inputs

### Original issue(s) — verbatim body
[Paste BC-NNNN full body as fetched from get_issue]
[Paste BC-MMMM full body — if multiple originals absorbed]

### New issue — verbatim body
[Paste new issue full body as fetched from get_issue immediately after save_issue]

### Structural contract
[Paste §4 "New-issue body template" 10-item contract from this plan file]

## Task

### Part 1 — Content preservation check

For each section of each original issue, confirm the content exists in the new issue.
Use verbatim phrase matching where possible. Check:
  - §Context paragraphs
  - §Explore steps (file paths to read, SOQL queries, etc.)
  - §Plan bullets (each Brite-specific pattern/gotcha)
  - §Execute steps (commands to run, files to edit, commit messages)
  - §Verify test criteria — EVERY row of EVERY verify table must appear
  - §Out-of-scope items
  - §Related links

### Part 2 — Structural integrity check

Confirm the new issue body satisfies all 10 items of the structural contract.

### Part 3 — Goal alignment check

Confirm the new issue's §Goal statement covers the intent of each absorbed original.

## Output format

**Part 1 — Content preservation:**
- BC-NNNN §Context → [PRESENT at new issue §Context para N / MISSING]
- BC-NNNN §Explore step 1 → [PRESENT / MISSING]
[continue exhaustively for each item of each original]

**Part 2 — Structural integrity:**
- Item 1 §Context → [PASS / FAIL]
- Item 2 §Goal → [PASS / FAIL]
[etc.]

**Part 3 — Goal alignment:**
- BC-NNNN goal: [one sentence]
- New issue §Goal: [one sentence]
- Alignment: [VERDICT paragraph]

## Final verdict

**FINAL VERDICT: PASS** — if every item is PRESENT/PASS.
**FINAL VERDICT: FAIL** — otherwise, with a bulleted list of the specific
content/structure items missing, each with a pointer to where it should have
landed in the new issue.

Be strict. Prefer FAIL + specifics over PASS + vague reassurance.
```

### 5.4 Failure mode

If the verification agent reports FAIL:
1. Review the agent's specific missing-content list.
2. Edit the new issue via `save_issue` update-path to add the missing content. **Warning:** per memory gotcha, Linear Prosemirror save mangles dense bulleted sections on update. Convert dense bullets → numbered lists before update. Always `get_issue` after save to verify no mangling.
3. Re-run the verification agent fresh (no reuse — stale context may miss the second-pass delta).
4. Do not proceed to the next new-issue creation until verification PASSES.

---

## 6. Session execution workflow

This current session follows the same explore → plan → execute → verify discipline applied to the rescope meta-work.

- **Explore:** COMPLETE. Audited all 14 Todo issues. Identified 2 over-scoping patterns. Classified each issue.
- **Plan:** THIS FILE. Documents actions 1-3, new-issue body template, verification agent spec, originals-handling protocol.
- **CHECKPOINT 1:** Present this plan to the user. Get explicit approval. One question at a time. No Linear mutations before approval.
- **Execute:** On approval, work through Actions 1 → 2 → 3 in order. For each new issue: draft body → user checkpoint on draft → `save_issue` → `get_issue` to confirm no markdown mangling → spawn verification agent → user checkpoint on verification verdict. For Action 3: show user the cancellation-comment template and confirm before bulk-canceling.
- **Verify:** After Action 3 completes, run the final sanity check (§7 below) and report back.

---

## 7. Success criteria

The rescope is complete when ALL of the following are true:

1. ✅ 5 new Linear issues exist in the RevOps Plugin milestone, each satisfying the 10-item structural contract.
2. ✅ The verification agent returned PASS for every new-issue-vs-originals comparison.
3. ✅ 8 absorbed originals (BC-5785, BC-5799-5805) are in Canceled status with successor-linking comments.
4. ✅ Milestone Todo count = 11 (6 unchanged + 5 new).
5. ✅ Every new issue's §Related section links to every absorbed original + this plan file.
6. ✅ This plan file is committed (or at minimum staged for commit).

---

## 8. Rollback

If the rescope goes sideways mid-execution:

- **Mid-Action 1:** If Part A is created but Part B draft is unworkable, leave Part A as an atomic issue (it's self-contained) and re-open BC-5785 as the tightening-only issue (rename/rescope to exclude the audit half).
- **Mid-Action 2:** If a group's verification keeps failing, fall back to the un-grouped siblings — delete the partially-created group issue, reopen the absorbed originals (un-cancel, no harm done since Cancel is reversible). The original content is still intact.
- **Post-Action 3:** If a downstream session discovers missing content that the verification agent missed, amend the relevant new issue via `save_issue` update and `get_issue` to verify. Do not un-cancel originals unless the loss is non-trivial.

---

## 9. Task list pointer

Execution is tracked via the session's TaskCreate list. Task IDs (as of plan-draft time):

1. Draft this plan file — **in_progress**
2. Present plan to user for approval — **CHECKPOINT** (blocks 3)
3. Execute Action 1 (BC-5785 split) — blocked by 2
4. Execute Action 2 (batch BC-5799-5805) — blocked by 3
5. Execute Action 3 (close originals) — blocked by 4
6. Final sanity check + report — blocked by 5

---

## 10. Related

- **Source Linear issues:** BC-5785, BC-5799, BC-5800, BC-5801, BC-5802, BC-5803, BC-5804, BC-5805
- **Milestone:** RevOps Plugin (`42397dd4-680f-4e73-b672-57909add68aa`)
- **Parent plan:** `docs/plans/revops-plugin-master-plan.md`
- **Prior shipped work informing the over-scoping pattern:** BC-5790 (PR #166), BC-5791 (PR #167)
- **Convention memory:** Linear markdown mangling (`memory/gotcha_linear_markdown_mangling.md`), plugin.json strict schema, issue-creator agent pattern
