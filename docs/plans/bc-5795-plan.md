# BC-5795 Plan — Customize sf-connected-apps (Brite ECA discipline)

**Issue:** [BC-5795](https://linear.app/brite-nites/issue/BC-5795)
**Milestone:** RevOps Plugin (Phase 3, sibling #3 of ~11)
**Scope shape:** Layer Brite ECA patterns into `plugins/revops/skills/sf-connected-apps/SKILL.md` without renaming the dir.

## Scope override (documented audit trail)

Issue body calls for `git mv sf-connected-apps → brite-connected-apps`. **Override: keep `sf-connected-apps` dir name.** Two load-bearing reasons:

1. **User directive** (2026-04-20): "lets just call it sf-connected-apps i don't need to do the brite thing."
2. **BC-5793/5794 sibling-zero template ratified** this exact override: keep upstream dir name, canonical attribution, no `git mv`. Applied verbatim per the precedent (BC-5794 memory trace).

**3-location audit trail** (per BC-5758 precedent):
- [x] This plan file (§ Scope override).
- [ ] Commit message (will state: "customize sf-connected-apps with Brite ECA patterns (keep upstream dir name per BC-5793/5794 sibling-zero template)").
- [ ] PR body (§ Deviations).

AC tests T1, T3–T5, T6 reference `brite-connected-apps` paths — will be run against `sf-connected-apps` paths instead and result pasted verbatim.

## Template (from BC-5793/5794 ratified sibling-zero)

- **Attribution (canonical per UPSTREAM.md:53–58), placed between frontmatter and H1:**
  ```
  <!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->
  ```
- **Version bump:** `1.1.0` → `1.1.0-brite.1` in frontmatter.
- **Two-section layout (mirrors BC-5794):**
  - `## Brite Context` — landscape shape (4 ECAs, Spring '26 posture, credential home, runtime vs CI auth distinction). Non-binding narrative.
  - `## Brite ECA Conventions` — enforceable rules (Spring '26 gate, JWT scope policy, deploy gotchas, scratch-org workaround, CI vs runtime separation). Each rule one sentence + rationale.

## Content outline (memory-sourced; verified by explore agent)

### § Brite Context (narrative)

- Brite's integration auth landscape is **ECA-based, not classic ConnectedApp**. Classic CA creation is blocked org-wide since Spring '26.
- **4 active ECAs** with distinct patterns:
  - `Marketing_Claude_MCP` — plugin-side MCP access; JWT; scopes `Api` + `RefreshToken`; `refreshTokenPolicy: ZERO`; private key in Engineering Bitwarden.
  - `Outbound_Sales_Ops` — outbound automation runtime.
  - `CI_Deploy` — GH Actions; refresh-token flow (not JWT).
  - `OutboundSync` — webhook relay from Email Bison → SF.
- **Credential storage convention:** JWT private keys live in the Engineering Bitwarden collection; per-user distribution out-of-band.
- **CI ≠ runtime auth.** `CI_Deploy` uses SFDX refresh-token; `Marketing_Claude_MCP` uses JWT. Don't cross-wire.

### § Brite ECA Conventions (enforceable rules)

1. **Spring '26 CA deprecation — always prefer ExternalClientApplication.**
   Classic `ConnectedApp` creation is blocked org-wide since Spring '26. Use `ExternalClientApplication` metadata type for any net-new OAuth app. Reference: `gotcha_spring26_ca_blocked` in project memory.

2. **JWT flow requires BOTH `Api` + `RefreshToken` scopes.**
   The SFDX CLI auth layer needs `RefreshToken` even though pure JWT exchange does not. Don't drop it. Source: `salesforce-mcp-findings.md` Q3; verified in BC-5579.

3. **`refreshTokenPolicy: ZERO` for ECA OAuth policies.**
   Belt-and-suspenders against long-lived tokens. Applied to `Marketing_Claude_MCP`; default for new ECAs unless a specific flow requires persistence.

4. **ECA sandbox deploy — exclude `ExtlClntAppOauthSettings` via `.forceignore`.**
   The file contains an org-specific `oauthLink` (`OrgId:ConsumerRecordId`) that cannot resolve cross-org. Excluded alongside `ExternalClientApplication` type. Temporarily comment out exclusions when deploying to production.

5. **JWT-from-ECA + `sf org create scratch` is broken.**
   Upstream: `forcedotcom/cli#3025`, `#3482`. `sf org create scratch` rejects JWT sessions authenticated against ECAs. Workaround: authenticate via `SFDX_AUTH_URL` through the CLI's built-in PlatformCLI Connected App for scratch-org provisioning.

6. **CI vs runtime auth separation.**
   CI deploys (`CI_Deploy` ECA) use refresh-token flow because GH Actions needs long-lived credentials. Runtime MCP access (`Marketing_Claude_MCP`) uses JWT so tokens are short-lived and cert-gated. Cross-wiring breaks blast-radius isolation.

7. **Credential storage — Engineering Bitwarden.**
   JWT private keys and ECA consumer secrets live in the Engineering Bitwarden collection. Item naming: `<ECAName> — JWT private key` / `<ECAName> — consumer secret`. Per-user distribution out-of-band.

## Tasks (2–5 minutes each)

1. **Worktree + Linear state.** `EnterWorktree` with name `bc-5795-connected-apps`. Move BC-5795 → In Progress in Linear. (2 min)

2. **Frontmatter version bump.** Edit `plugins/revops/skills/sf-connected-apps/SKILL.md`:
   - Change `version: "1.1.0"` → `"1.1.0-brite.1"`. (1 min)

3. **Insert attribution comment.** Add canonical HTML comment between frontmatter `---` and H1 `# sf-connected-apps`:
   ```
   <!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md. -->
   ```
   (1 min)

4. **Insert `## Brite Context` section** — place after H1/intro, before `## When This Skill Owns the Task`. 4 bullets per § above. (3 min)

5. **Insert `## Brite ECA Conventions` section** — place after `## Brite Context`. 7 enforceable rules per § above. (5 min)

6. **Validate.** Run `./scripts/validate.sh` — expect exit 0. (1 min)

7. **Acceptance test fixture** — run adjusted AC grep matrix:
   | Test | Command (sf-connected-apps, not brite-) | Expected |
   |------|----------------------------------------|----------|
   | T1 | `ls plugins/revops/skills/sf-connected-apps` | Exists |
   | T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
   | T3 | `grep -E "ExternalClientApplication\|Spring .26" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
   | T4 | `grep -E "Marketing_Claude_MCP\|Outbound_Sales_Ops\|CI_Deploy\|OutboundSync" plugins/revops/skills/sf-connected-apps/SKILL.md` | All 4 referenced |
   | T5 | `grep "forcedotcom/cli" plugins/revops/skills/sf-connected-apps/SKILL.md` | Match |
   | T6 | Manual (deferred to review) — skill activation check in SF repo | PR reviewer verifies |
   | T7 | Manual (deferred to review) — non-activation in non-SF repo | PR reviewer verifies |
   | T8 | `./scripts/validate.sh` | Exit 0 |
   (2 min)

8. **Commit + push + PR.** Commit message: `customize sf-connected-apps with Brite ECA patterns (BC-5795)`. PR body includes § Deviations noting scope override. Move Linear → In Review. (3 min)

## Out of scope

- Modifying existing ECAs in `brite-salesforce` repo.
- Touching other Phase 3 skills.
- Running T6/T7 in-session (requires cross-repo context; deferred to PR review).

## Validation gate (enters /workflows:review)

After Task 8, trigger `/workflows:review` per the RevOps Phase 3 pattern. Expect NON-TRIVIAL review verdict (markdown-heavy diff, ≥1 load-bearing convention rule per section). Budget ≥1 fix-review loop.

## Related

- `plugins/revops/UPSTREAM.md` (canonical attribution line)
- `plugins/revops/skills/sf-permissions/SKILL.md` (BC-5794 template)
- `plugins/revops/skills/sf-deploy/SKILL.md` (BC-5793 template)
- `docs/research/salesforce-mcp-findings.md` Q3 (ECA decision rationale)
- `plugins/marketing/tools/integrations/salesforce.md` § Auth (JWT+ECA+Bitwarden pattern)
- Memory: `gotcha_spring26_ca_blocked.md`, `project_salesforce_mcp_adopt.md`
