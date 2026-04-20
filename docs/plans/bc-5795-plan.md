# BC-5795 Plan — Customize sf-connected-apps (Brite ECA discipline)

**Issue:** [BC-5795](https://linear.app/brite-nites/issue/BC-5795)
**Milestone:** RevOps Plugin (Phase 3, sibling #3 of ~11)
**Scope shape:** Layer Brite ECA patterns into `plugins/revops/skills/sf-connected-apps/SKILL.md` without renaming the dir.

## Post-merge revert & re-ship

This is the **v2** of BC-5795. v1 shipped as PR #147 and merged before review. `/workflows:review` ran against the merged commit and surfaced two confirmed P1 factual errors plus several P2/P3s. v2 reverts PR #147 (squash commit `789cd77`) and re-ships the corrected SKILL.md on a new branch.

### Factual corrections applied in v2

- **P1.1 [CI_Deploy]**: v1 described `CI_Deploy` as the live GitHub Actions refresh-token path. Ground truth (`docs/research/salesforce-mcp-findings.md:393, 412`): `CI_Deploy` is committed but **inactive**; GitHub Actions authenticates via `SFDX_AUTH_URL` under Salesforce's built-in `PlatformCLI` Connected App. Fixed in § Brite Context third bullet + Rule #6.
- **P1.2 [Outbound_Sales_Ops]**: v1 classified `Outbound_Sales_Ops` as one of four ECAs. Ground truth (`findings.md:50, 390`): it's a legacy ConnectedApp auto-wrapped with an ECA settings file during the Spring '26 migration — NOT a pure ECA. `Marketing_Claude_MCP` is Brite's first pure ECA. Fixed in § Brite Context second bullet.

### Other corrections applied in v2

- **P2.1 [Frontmatter]**: added `upstream: "Jaganpro/sf-skills@ff1ab74"` and updated `author:` to `"Jag Valaiyapathy (upstream); Brite Company (customization)"` — matches BC-5793 + BC-5794 sibling-zero template.
- **P2.3 [Upstream table contradiction]**: added `> At Brite: always ECA` banner above the upstream First Decision table + adjusted the trailing Spring '26 default-guidance note so the table cannot be followed without seeing the Brite override.
- **P3.B [JWT scope scope]**: tightened Rule #2 headline from "JWT flow requires BOTH..." to "JWT-via-SFDX-CLI flow requires BOTH..." and added the non-CLI-runtime exception.
- **P3.C [Casing]**: `refreshTokenPolicy: ZERO` → `zero` lowercase throughout, matching `assets/connected-app-jwt.xml` + `assets/eca-policies.xml`.
- **P3.D [CDR citation]**: added `**See also:**` line in § Brite Context pointing to `brite-salesforce/CLAUDE.md §External Client Apps` + findings doc + memory gotcha.
- **P3.E [sf-deploy link]**: added inline link to `sf-deploy` in Rule #4.
- **P3.F [Section ordering]**: left Brite sections above the gating section (matches sf-permissions / BC-5794 precedent). Documenting the split with sf-deploy ordering in the BC-5795 precedent trace instead.
- **P3.A (this doc)**: fixed `grep -E` backslash-pipe in the AC matrix.

### Findings NOT applied in v2 (and why)

- **P2.2 [Section placement before gating]**: confidence 7/10, but sf-permissions (the closer sibling precedent) places Brite sections identically. Keeping parity with BC-5794 over a performance micro-optimization.
- **P3 filtered** (3 findings below confidence threshold): CI refresh-token risk framing, attribution comment specificity, Spring '26 wording drift on the line-79 default-guidance note — partially addressed by Rule #1 + banner.

## Scope override (same as v1)

Issue body calls for `git mv sf-connected-apps → brite-connected-apps`. **Override: keep `sf-connected-apps` dir name.** Two load-bearing reasons:

1. **User directive** (2026-04-20): "lets just call it sf-connected-apps i don't need to do the brite thing."
2. **BC-5793/5794 sibling-zero template ratified** this exact override: keep upstream dir name, canonical attribution, no `git mv`. Applied verbatim per the precedent.

**3-location audit trail** (per BC-5758 precedent): this plan file ✓ · commit message · PR body.

## Template (from BC-5793/5794 ratified sibling-zero)

- **Attribution (canonical per UPSTREAM.md:53-58), placed between frontmatter and H1:**
  ```
  <!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->
  ```
- **Version bump:** `1.1.0` → `1.1.0-brite.2` (suffix `.2` reflects v2 after review corrections).
- **Frontmatter includes `upstream:` key and extended `author:` per sibling template.**
- **Two-section layout (mirrors BC-5794):**
  - `## Brite Context` — landscape shape (ECA inventory with accurate pure-ECA vs legacy-CA labeling, credential home, CDR/source pointers). Non-binding narrative.
  - `## Brite ECA Conventions` — 7 enforceable rules. Each rule one sentence + rationale.
- **Brite override banner** above the upstream `## First Decision` table.

## Tasks (v2)

1. **Revert v1**: from `origin/main`, `git revert 789cd77` → creates clean revert commit.
2. **Apply corrected SKILL.md** per content spec above.
3. **Update this plan** with post-merge corrections log (current doc).
4. **Validate**: `./scripts/validate.sh` + AC grep matrix (corrected, see below).
5. **Commit + push + open PR** referencing PR #147 + this review.

## Acceptance test matrix (v2, corrected regex)

| Test | Command | Expected |
|------|---------|----------|
| T1 | `ls plugins/revops/skills/sf-connected-apps` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
| T3 | `grep -E "ExternalClientApplication|Spring .26" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
| T4 | `grep -E "Marketing_Claude_MCP|Outbound_Sales_Ops|CI_Deploy|OutboundSync" plugins/revops/skills/sf-connected-apps/SKILL.md` | All 4 referenced |
| T5 | `grep "forcedotcom/cli" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
| T6 | Manual (cross-repo, deferred) | Skill activates in `brite-salesforce` on CA/ECA question; does not activate in non-SF repo |
| T7 | `grep -E "first pure ECA|legacy ConnectedApp" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match (v2-specific: verifies the P1.2 fix is in place) |
| T8 | `grep -E "SFDX_AUTH_URL|PlatformCLI" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match (v2-specific: verifies the P1.1 fix is in place) |
| T9 | `grep -E "refreshTokenPolicy: zero" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match (v2-specific: verifies lowercase casing) |
| T10 | `./scripts/validate.sh` | Exit 0 |

## Out of scope

- Modifying existing ECAs in `brite-salesforce` repo.
- Touching other Phase 3 skills.
- Filing a handbook CDR for Brite OAuth/secret-storage policy (flagged by CDR-compliance reviewer as a gap — separate follow-up).
- ADR-007 §3.6 attribution-form drift (flagged in BC-5794 session; still a separate one-line ADR fix).

## Related

- `plugins/revops/UPSTREAM.md` (canonical attribution line)
- `plugins/revops/skills/sf-permissions/SKILL.md` (BC-5794 template)
- `plugins/revops/skills/sf-deploy/SKILL.md` (BC-5793 template)
- `docs/research/salesforce-mcp-findings.md` Q3 + Appendix B.1 (ECA decision rationale + live-state ground truth)
- `plugins/marketing/tools/integrations/salesforce.md` § Auth
- Memory: `gotcha_spring26_ca_blocked.md`, `project_salesforce_mcp_adopt.md`
- PR #147 (v1, merged then reverted in v2)
- This PR (v2, revert+re-ship)
