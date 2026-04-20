# BC-5794 — Customize sf-permissions with Brite permset discipline

**Linear:** https://linear.app/brite-nites/issue/BC-5794
**Branch:** `holden/bc-5794-sf-permissions-brite-customization`
**Worktree:** `.claude/worktrees/bc-5794`
**Base:** `origin/main` @ `2fbca66` (BC-5793 merged)
**Date:** 2026-04-20

## Scope

Layer Brite permission-set discipline from `brite-salesforce/CLAUDE.md` §Permissions & Security (lines 164–173) into `plugins/revops/skills/sf-permissions/SKILL.md`. Second Phase 3 customization after BC-5793 (sf-deploy), establishing that the sibling-zero pattern generalizes.

## Issue-body overrides (locked at Plan gate)

Carried forward from BC-5793 precedent; re-applies here because BC-5794 was filed before ADR-007 §3.6:

1. **No directory rename.** Keep `plugins/revops/skills/sf-permissions/`. ADR-007 §3.6 supersedes the issue title and T1/T3 path expectations.
2. **Attribution form:** `Adapted from Jaganpro/sf-skills@ff1ab74 (MIT)` (matches BC-5793 + UPSTREAM.md canonical form).
3. **No `git mv`.** Execute step 1 in the issue body is a no-op.

## Tasks

1. Write this plan file (meta; this file).
2. Edit `plugins/revops/skills/sf-permissions/SKILL.md`:
   - Add attribution HTML comment after frontmatter.
   - Update `description:` to include Brite-specific triggers (`Base_CRM_Access`, 7-permset FLS, `Lifecycle_Stage__c` automation-only).
   - Insert a new `## Brite Permission Conventions` section with 7 subsections mirroring brite-salesforce/CLAUDE.md lines 164–173 verbatim (permset naming, 7-permset FLS sync, Lifecycle automation-only, restricted RT scoping, app visibility, session-based perm set vs Bulk API, CreateAuditFields gotcha).
   - Cross-link `brite-salesforce/docs/artifacts/user-role-matrix.md` and `@import docs/decisions/004-permission-set-strategy.md`.
3. Evaluate `references/permission-model.md` — add a Brite taxonomy pointer ONLY if it earns its keep; otherwise skip.
4. Run verification (T1–T5 + T8 + T9 with overrides).
5. Commit: `BC-5794: customize sf-permissions with Brite permset discipline`.

## Verify — Overrides applied

| Test | Command | Pass criteria | Override |
|---|---|---|---|
| T1 | `ls plugins/revops/skills/sf-permissions` | Exists | Path stays `sf-permissions` (not `brite-permissions`) |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-permissions/SKILL.md` | Match | Canonical form: `@ff1ab74 (MIT)` |
| T3 | `grep -E "Base_CRM_Access\|_Group\|_Management_Group" …/sf-permissions/SKILL.md` | 3 patterns | Path update only |
| T4 | `grep "Lifecycle_Stage__c" …/sf-permissions/SKILL.md` | Match | Path update only |
| T5 | `grep -E "Finance_Read.*Deal_Financial_Read.*Sales_Operations\|7 permset" …/sf-permissions/SKILL.md` | Match | Path update only |
| T6 | brite-salesforce repo: "how do I create a new permission set?" | Skill activates | Manual post-merge |
| T7 | non-SF repo: same question | Skill does NOT activate | Manual post-merge |
| T8 | `./scripts/validate.sh` | Exit 0 | — |
| T9 | `./scripts/check-guardrails.sh` | Pass | — |

## Out of scope

- Other Phase 3 skills (BC-5795, BC-5796, …).
- Modifying brite-salesforce permset source files.
- Directory rename (handled by ADR-007 §3.6).

## Related

- ADR-007 §3.6 — keep upstream names
- BC-5793 PR #141 (sibling-zero, merged 2026-04-20)
- BC-5789 PR #137 (scaffold, merged)
- `brite-salesforce/CLAUDE.md` lines 164–173 — source material
- `brite-salesforce/docs/artifacts/user-role-matrix.md` — canonical permset role map
- `docs/plans/revops-plugin-master-plan.md` §9 Issue 3.2
