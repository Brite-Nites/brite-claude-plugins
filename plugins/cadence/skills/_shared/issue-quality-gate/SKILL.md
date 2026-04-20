---
name: issue-quality-gate
description: Apply 7 quality checks to a single Linear issue object. Returns pass/fail per check. Phase 1 audit and Phase 2 scope both consume this skill.
---

# Issue Quality Gate

Run the 7 checks below against a single Linear issue object passed in by the consumer. Return a list of `{check, status, message}` tuples. The skill itself does NOT block — consumers (Phase 1 audit, Phase 2 scope) decide what to do with failures.

## Input

A single Linear issue object as returned by `mcp__plugin_workflows_linear-server__get_issue` or `list_issues`. Required fields:

- `id`, `title`, `description`, `priority`
- `assignee` (may be null)
- `state` with `type` field (or `statusType` for `list_issues` shape)
- `cycleId` (may be null)
- `completedAt` (set only when state is `completed`)

Optional fields enrich the gate but are not required: `comments`, `attachments` (consumer may pre-fetch these for check #7).

## The 7 Checks

| # | Check | Pass criterion | Fail criterion |
|---|---|---|---|
| 1 | `assignee_present` | `issue.assignee != null` | unassigned |
| 2 | `title_scopes_work` | ≥3 words AND no leading `TBD` / `???` / `[placeholder]` | <3 words OR placeholder lead |
| 3 | `priority_set` | `priority` ∈ {1, 2, 3, 4} (Urgent/High/Medium/Low) | `priority == 0` (No priority) |
| 4 | `state_matches_cycle` | `cycleId` null OR (`cycleId` set AND state ∈ {`unstarted`, `started`, `completed`}) | `cycleId` set AND state == `backlog` |
| 5 | `dependencies_declared` | description contains `## Dependencies` heading with ≥1 issue ID OR literal `none` | header missing OR section empty |
| 6 | `ac_section_non_empty` | description contains `## Acceptance Criteria` header with ≥1 `- [ ]` or `- [x]` line | header missing OR no checkboxes |
| 7 | `done_with_evidence` | state != `completed` (skip) OR (`completedAt` set AND comment / attachment references a PR/commit URL: `github.com/.+/pull/\d+` or `github.com/.+/commit/[0-9a-f]{7,}`) | state == `completed` AND no PR/commit evidence |

## Output

```json
[
  {"check": "assignee_present",      "status": "pass", "message": ""},
  {"check": "title_scopes_work",     "status": "pass", "message": ""},
  {"check": "priority_set",          "status": "pass", "message": ""},
  {"check": "state_matches_cycle",   "status": "pass", "message": ""},
  {"check": "dependencies_declared", "status": "pass", "message": ""},
  {"check": "ac_section_non_empty",  "status": "pass", "message": ""},
  {"check": "done_with_evidence",    "status": "pass", "message": ""}
]
```

Status values: `"pass"`, `"fail"`, or `"skip"`. `"skip"` is valid only on check #7 when the issue is not in `completed` state.

For failures, `message` names the missing thing in one short line — e.g. `"description has no '## Dependencies' header"` or `"completed without PR/commit URL in comments"`. For passes, an empty string is fine.

## Consumer behavior (defined elsewhere)

This skill is the primitive only. Consumers decide what to do with failures:

- **Phase 1 audit (BC-5759).** Runs check #7 inline (cheapest fake-Done detector); defers checks 1–6 to scope time. Failures populate `audit_card.quality_gate_flags`.
- **Phase 2 scope (BC-5760).** Runs all 7 checks on every scope-in candidate. Block-with-override per BC-5810 § 3.3 — three options surfaced via `AskUserQuestion`: fix now, override with reason, drop from scope.

## References

- Spec: `docs/designs/cadence-orchestration.md` § 3 (BC-5810)
- W16 ground-truth example: BC-3270 / BC-3269 marked Done without meeting artifacts (check #7 catches this exact pattern).
