# BC-5551 — Move Email Bison MCP servers to plugin-scoped .mcp.json

**Issue:** [BC-5551](https://linear.app/brite-nites/issue/BC-5551/move-email-bison-mcp-servers-to-plugin-scoped-mcpjson-emailbison-b2b)
**Branch:** `holden/bc-5551-move-email-bison-mcp-servers-to-plugin-scoped-mcpjson`
**Deliverables:**
- `plugins/marketing/.mcp.json` — two new server entries with env-var substitution
- `plugins/marketing/tools/integrations/email-bison.md` — Credentials section + prose consistency fix
- `CONTRIBUTING.md` — "Email Bison MCP Onboarding" subsection (twin of the Salesforce one)
- Repo-root `.mcp.json` — EB entries removed (gitignored; Holden edits locally)
- `memory/reference_outbound_mcp_servers.md` — Registration paragraph corrected
- `plugins/marketing/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — version bump 0.2.0 → 0.3.0
- Bitwarden item **"Email Bison MCP — API tokens"** — Holden creates; the agent never sees or touches the raw credentials
**Gates this unblocks:** BC-2707, BC-2717, BC-2718, BC-2719, BC-2720, BC-2721 (plugin distribution for every EB-consuming skill)

## Credential-handling rules (read first)

The agent **never** reads, copies, pastes, logs, or echoes the raw Email Bison tokens at any point in this plan. Concretely:

- The agent does not `cat` or `Read` the repo-root `.mcp.json` to see the token values.
- The agent never includes a token value in a tool call, file edit, commit message, PR body, or task description.
- Creating the Bitwarden item (T6) is **Holden's action**; the agent only documents that it happened.
- Exporting env vars in a shell profile (pre-T10) is **Holden's action**; the agent only confirms a round-trip result afterwards.
- All file writes the agent performs use `${ENV_VAR}` placeholders only — the placeholders are inert text.

If at any point a tool result would surface a raw token, stop and surface the leak to Holden before continuing.

## Brainstorm outcomes

Three design questions resolved before planning (one at a time, per `feedback_one_question_at_a_time.md`):

1. **Env-var names:** `EMAILBISON_B2B_TOKEN` / `EMAILBISON_PERSONAL_TOKEN`. Research confirmed vendor's canonical term is **"API Token"** (`docs.emailbison.com/get-started/authentication`). ADR 2a + `email-bison.md:43/51` already use `_TOKEN`. Linear issue's `_API_KEY` was a one-off; flag in PR body + flip `email-bison.md:17` prose ("API key" → "API token") for internal consistency.
2. **Credential vault:** **Bitwarden, Engineering collection, single item**, mirroring BC-5535. Handbook rejected (not a secrets store). Two-item split rejected (too many onboarding clicks for marginal blast-radius benefit).
3. **Scope:** Plugin-side migration + a Bitwarden item Holden creates during the session. No BC-5579-equivalent follow-up — the live tokens already work (no admin provisioning), unlike SF where a new ECA had to be spun up. Rotation is **not** part of this migration.

## Execution directives for the AI agent

1. **Use the existing task list** from `/workflows:session-start`. Mark each T-task `in_progress` when starting and `completed` when its Verify block passes.
2. **Respect the six check-in gates** (🛑 markers). Memory feedback: infra/cross-repo issues benefit from extra gates — BC-5535's expansion from 2 → 6 gates caught 3 real issues. This is infra; follow suit.
3. **One question at a time** at every gate. No batching.
4. **Verify by round-trip, not by spec.** The only real test of env-var wiring is loading the plugin and calling `get_active_workspace_info` against both namespaces. The agent triggers the round-trip **after** Holden confirms env vars are set locally.
5. **Never log, read, or echo the raw tokens.** Per the Credential-handling rules above.

## Tasks

### T0 — Framing gate (~3 min) — 🛑 **Check-in gate #1 before any writes**

**Objective:** Surface anything stale between the issue description and the current repo state.

- Re-confirm the 3 discrepancies already identified (captured in Step 4/5 of session-start):
  - Issue says `${EMAILBISON_B2B_API_KEY}`; we ship `${EMAILBISON_B2B_TOKEN}`.
  - Issue asks "1Password vault? Doppler? Handbook section?"; we chose **Bitwarden** per BC-5535 precedent.
  - Issue's scope treats credential storage as an open question — resolved by BC-5535 (Bitwarden).
- Confirm with Holden that he can see the existing entries in the repo-root `.mcp.json` (agent does not need to read this file — the shape is already documented in `email-bison.md:36-57` and ADR 2a credential-pattern snippet).
- Scan `plugins/marketing/.mcp.json` — confirm only `salesforce` present, and the object shape we'll extend matches ADR 2a's snippet.

🛑 **Gate #1:** Surface any surprise (e.g. plugin `.mcp.json` already has an EB key from an earlier attempt). Ask: "Start the worktree and proceed to T2?"

**Verify:** Gate approved. Agent has never read a raw token.

### T1 — Worktree setup (~2 min)

Covered by Step 7 of `/workflows:session-start` — handled by the `git-worktrees` skill. Branch name per frontmatter. Clean baseline via `./scripts/validate.sh` before touching any file.

**Verify:** Worktree at `.claude/worktrees/bc-5551/` exists; `./scripts/validate.sh` green on an unmodified tree.

### T2 — Add Email Bison entries to plugin `.mcp.json` (~3 min)

**Objective:** Extend `plugins/marketing/.mcp.json` with both EB servers, using placeholder env-var substitution.

- File: `plugins/marketing/.mcp.json`
- Add two keys alongside the existing `salesforce` entry — order: `emailbison-b2b` first, then `emailbison-personal`, then `salesforce` (alphabetical-by-vendor). The shape mirrors `email-bison.md:36-57` and ADR 2a credential-pattern snippet — the agent copies that shape verbatim, substituting only the literal env-var placeholder strings (no raw tokens involved).

**Verify:**
- `python3 -m json.tool plugins/marketing/.mcp.json > /dev/null` exits 0.
- `grep -E 'Bearer [A-Za-z0-9]{5,}' plugins/marketing/.mcp.json` returns **no matches** (only `${…}` placeholders). This is the leak guard — any hit means we committed a real token.
- Diff contains exactly two new keys; existing `salesforce` entry byte-identical.

### T3 — Update `email-bison.md` (~5 min) — 🛑 **Check-in gate #2 after this task**

**Objective:** Reflect the landed-plugin state and the credential retrieval flow.

Edits, all in `plugins/marketing/tools/integrations/email-bison.md`:

1. **Line 17 prose fix** (decision #1 follow-through): `Email Bison API key per workspace` → `Email Bison API token per workspace` (plus adjust downstream references in §Auth that say "key" to "token" where the subject is the credential itself — NOT where `Instance-URL` is discussed).
2. **§Credential storage (line 32)** — rewrite from "open question owned by ADR 2a" to the landed state: Bitwarden item name ("Email Bison MCP — API tokens"), env-var names (`EMAILBISON_B2B_TOKEN` / `EMAILBISON_PERSONAL_TOKEN`), principle that no raw tokens live in committed files.
3. **New §One-time per-dev onboarding** — twin the shape in `salesforce.md:37-58`. Steps: retrieve the Bitwarden item, set both env vars in your shell profile (the Bitwarden Notes field has the exact variable assignments ready to copy), `/reload-plugins`, smoke-test with a read-only MCP call against each namespace.
4. **§Registration (line 34)** — delete the "File location. Today: repo-root…" sentence. Replace with: "`plugins/marketing/.mcp.json` — ships with the plugin. `${EMAILBISON_B2B_TOKEN}` / `${EMAILBISON_PERSONAL_TOKEN}` are read from the shell environment at load time."
5. **§Last verified** — add a dated line for today's migration.

🛑 **Gate #2:** Surface any editorial choices — e.g. should the onboarding section reference the exact shell profile paths (zsh `~/.zshrc` vs bash `~/.bashrc`) or stay shell-agnostic? BC-5535 dropped prescriptive `~/.config/sf/` for `chmod 600` — similar call here.

**Verify:** `grep -c "open question" plugins/marketing/tools/integrations/email-bison.md` returns 0. `grep "Bitwarden" plugins/marketing/tools/integrations/email-bison.md` returns ≥1. Line 17 says "API token", not "API key".

### T4 — Update `CONTRIBUTING.md` (~3 min)

**Objective:** Add an "Email Bison MCP Onboarding" subsection immediately after the Salesforce one (CONTRIBUTING.md:124).

- Title: `## Email Bison MCP Onboarding`
- Keep it **tighter than** the Salesforce section — EB onboarding is 3 steps (env vars + reload + smoke-test), not 6.
- Reference `plugins/marketing/tools/integrations/email-bison.md` for the full detail.
- Call out the key difference from Salesforce: "Email Bison **does** read env vars at runtime; set them in your shell profile. The Bitwarden item's Notes field carries the exact `export` lines ready to copy."

**Verify:** `grep "Email Bison MCP Onboarding" CONTRIBUTING.md` returns 1 hit. Adjacent to `## Salesforce MCP Onboarding`.

### T5 — Clean up repo-root `.mcp.json` (~2 min) — 🛑 **Check-in gate #3 after this task**

**Objective:** Remove the EB entries from the gitignored repo-root `.mcp.json` so duplicate registrations don't survive restart.

**This is Holden's action, not the agent's.** The agent must not read, edit, or grep this file — it contains raw tokens and is gitignored. The agent issues the instruction; Holden deletes the keys (or the file) locally.

- Holden: either delete both `emailbison-b2b` and `emailbison-personal` keys from `/Users/holdenhalford/Projects/work/brite-nites/britenites-claude-plugins/.mcp.json`, leaving `{"mcpServers": {}}`, or remove the file entirely.
- The agent confirms completion by asking Holden to run `jq '.mcpServers | keys' <file>` himself and paste the output, or simply confirm "done."

🛑 **Gate #3:** Confirm with Holden which other entries live in the repo-root file (if any) so he doesn't nuke anything unrelated. The agent never sees the file contents.

**Verify:** Holden confirms the two keys are gone. Agent's working tree never touched the file.

### T6 — Bitwarden item creation (~4 min) — Holden's action

**Objective:** Make the credentials retrievable by any future dev without Slack-grep or cross-repo cross-referencing.

**This is Holden's action, not the agent's.** The agent drafts the Notes-field structure as a template with placeholders (no real values); Holden pastes real token values into his Bitwarden client locally and saves the item.

- Item name: **"Email Bison MCP — API tokens"**
- Collection: Engineering (not personal vault)
- Notes field structure — drafted by the agent as a shape-only template, populated by Holden:
  - A header comment describing which plugin this is for and where onboarding is documented.
  - One labeled block per workspace (b2b / personal) with the env-var name and a placeholder Holden replaces with the live token.
  - The instance URL for each workspace (reference data — not secret, but colocated for single-stop onboarding).
  - A rotation-procedure pointer and a "last rotated" line Holden fills in.

🛑 **Gate (inside T6):** Once Holden saves the item, ask him to confirm "Bitwarden item exists, shared with Engineering." The agent does not verify the item itself.

**Verify:** Holden confirms. Agent proceeds.

### T7 — Update `reference_outbound_mcp_servers.md` memory (~2 min)

**Objective:** Correct the Registration paragraph so future sessions don't re-litigate.

- File: the memory file `reference_outbound_mcp_servers.md` under this project's auto-memory directory.
- Replace the "Registration (dev-scoped until ADR 2a lands)" paragraph with a new one stating plugin-scoped placement, `${ENV_VAR}` substitution, Bitwarden source of truth, PR number reference.
- Add or bump a `last_refreshed` frontmatter field to today's date.

**Verify:** `grep "plugin-scoped" <memory-file>` returns ≥1 hit. No mention of "dev-scoped until ADR 2a lands" remains.

### T8 — Version bump (~2 min) — 🛑 **Check-in gate #4 after this task**

**Objective:** Invalidate the plugin cache so `/reload-plugins` picks up the new MCP registrations.

- `plugins/marketing/.claude-plugin/plugin.json` — bump `"version": "0.2.0"` → `"0.3.0"`. Rationale: net-new MCP server entries = new capability surface = minor bump. Matches SemVer + BC-5535's 0.1.0 → 0.2.0 precedent.
- `.claude-plugin/marketplace.json` — bump the marketing plugin's version to match.
- `plugins/marketing/CHANGELOG.md` — add a `## [0.3.0] - 2026-04-17` entry documenting:
  - Added: `emailbison-b2b` + `emailbison-personal` MCP registrations.
  - Changed: credential sourcing via `${EMAILBISON_B2B_TOKEN}` / `${EMAILBISON_PERSONAL_TOKEN}` (Bitwarden).
  - Docs: Email Bison MCP Onboarding added to CONTRIBUTING.md.

🛑 **Gate #4:** Confirm version scheme (0.3.0 vs 0.2.1). BC-5535 precedent says minor, but Holden has the final call.

**Verify:** `grep '"version"' plugins/marketing/.claude-plugin/plugin.json` returns `0.3.0`. Marketplace version matches.

### T9 — Pre-validate (~3 min) — 🛑 **Check-in gate #5 after this task**

**Objective:** Run repo-wide validators before the round-trip test.

- `./scripts/validate.sh` — expect green.
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — expect green.
- `grep -rE 'Bearer [A-Za-z0-9]{5,}' plugins/ docs/ CONTRIBUTING.md CHANGELOG.md` — expect **zero matches**. Any match means a real token leaked into a committable file. Stop and surface.

🛑 **Gate #5:** Holden reviews the staged diff before `/reload-plugins`. Last moment to catch a leak before the plugin loads with real tokens.

**Verify:** All three checks green. Diff staged but not committed.

### T10 — Live round-trip verification (~3 min)

**Objective:** Prove the env-var substitution works against the real vendor endpoint, both workspaces. The agent coordinates; Holden sets env vars locally.

- Pre-step (Holden): confirm both env vars are set in his shell profile and exported. Agent does **not** run `echo $EMAILBISON_…` — that would leak the token into the conversation.
- Holden: `/reload-plugins` in Claude Code.
- Agent: call `mcp__plugin_marketing_emailbison-b2b__get_active_workspace_info` — expect response with workspace ID **52**, domain `send.outbase.so`.
- Agent: call `mcp__plugin_marketing_emailbison-personal__get_active_workspace_info` — expect workspace ID **11**, domain `personal.outbase.so`.

If either call fails with 401 or a `${...}`-literal-in-header error, see Rollback plan.

**Verify:** Both calls return the expected workspace IDs.

### T11 — Commit, push, review, PR (~6 min) — 🛑 **Check-in gate #6 before push**

**Objective:** Ship.

- `git status` — confirm only expected files changed:
  - `plugins/marketing/.mcp.json`
  - `plugins/marketing/tools/integrations/email-bison.md`
  - `plugins/marketing/.claude-plugin/plugin.json`
  - `plugins/marketing/CHANGELOG.md`
  - `.claude-plugin/marketplace.json`
  - `CONTRIBUTING.md`
  - `docs/plans/BC-5551-plan.md`
- `git diff --staged` — one final pass for inadvertent leaks.

🛑 **Gate #6:** Holden approves the final diff + PR body before push.

- Commit message (single commit):
  ```
  BC-5551: Move Email Bison MCP servers to plugin-scoped .mcp.json

  Plugin distribution twin of BC-5535. Two vendor workspaces (b2b +
  personal) now ship with the marketing plugin via env-var
  substitution. Credentials centralized in a new Engineering Bitwarden
  item.

  - plugins/marketing/.mcp.json: 2 new server entries (env-var subs)
  - email-bison.md: Credentials section + prose consistency fix
    (vendor term is "API token", not "API key")
  - CONTRIBUTING.md: Email Bison MCP Onboarding subsection
  - plugin.json + marketplace.json: 0.2.0 → 0.3.0
  - memory: Registration paragraph corrected

  Unblocks BC-2707, BC-2717-2721 (plugin distribution).
  ```
- `git push -u origin <branch>`.
- `/workflows:review` — expect TRIVIAL or low-severity verdict (config + docs + version bump; no executable code or skill logic).
- Resolve any P1s inline; P2/P3 rolled into follow-up only if not quick to fix.
- `gh pr create` with a body covering: summary, 3 design decisions, test plan (workspace round-trips), linked issues (BC-5535 related, BC-2707/2717-2721 blocks).

**Verify:** PR exists, CI green, `/workflows:review` verdict logged.

## Rollback plan

If T10 round-trip fails (401 or literal-placeholder error):

1. Suspect env-var not exported in the shell the plugin loader reads. Holden runs `[ -n "$EMAILBISON_B2B_TOKEN" ] && echo set || echo missing` (presence-only check, no value leak). If "missing", add to shell profile and re-source.
2. Suspect token revoked. Holden re-issues from the vendor UI, updates the Bitwarden item, exports the new value.
3. Suspect file-shape wrong. `jq '.mcpServers."emailbison-b2b".headers.Authorization' plugins/marketing/.mcp.json` — should print `"Bearer ${EMAILBISON_B2B_TOKEN}"` **literally** (Claude Code substitutes at load time, not at file-read time).
4. **Never** re-add the entries to repo-root `.mcp.json` as a workaround — that undoes the migration. Debug forward.

## Non-goals (for this PR)

- No rotation of the existing tokens. (Rotate separately if a compromise is suspected.)
- No new Email Bison skill authoring (BC-2707/2718/2719/2720/2721).
- No changes to the EB server's behavior or endpoint config.
- No rework of the repo-root `.mcp.json` gitignore anchor — it's correct.

---

## Postmortem + pivot to Option C (2026-04-17)

The original plan above did not ship. Plugin-scoped HTTP MCP registration with `${ENV_VAR}` substitution in headers is not viable in current Claude Code (v2.1.112). Confirmed via direct testing + agent research + open upstream bugs.

### Attempts and results

| Attempt | Result |
|---|---|
| HTTP-type plugin entry with `${EMAILBISON_B2B_TOKEN}` in `Authorization` header | Auth header sent literally as `Bearer ${…}`; vendor returns 401. Matches open Claude Code bugs [#6204](https://github.com/anthropics/claude-code/issues/6204) / [#9427](https://github.com/anthropics/claude-code/issues/9427) / [#28293](https://github.com/anthropics/claude-code/issues/28293) / [#14977](https://github.com/anthropics/claude-code/issues/14977). |
| Stdio wrapper via `npx -y mcp-remote@0.1.38 <URL> --header "..."` | `claude mcp list` extracts the URL substring from args and reclassifies the server as HTTP-type internally. Handshake never completes. |
| `sh -c "npx -y mcp-remote <URL> ..."` to hide URL from arg substring scan | Same result — URL is still in the quoted arg string. |
| All above + explicit `env:` block forwarding `${EMAILBISON_B2B_TOKEN}` into subprocess env | Same result — URL-substring classification fires regardless of env plumbing. |

Direct `curl` to the vendor endpoint using the shell env var: 200 OK with valid MCP `initialize` handshake. `mcp-remote@0.1.38` standalone from the shell: successful proxy. The block is strictly in how Claude Code's plugin-scoped MCP loader handles the configuration, not in the vendor or proxy layers.

### What shipped

1. Engineering Bitwarden item "Email Bison MCP — API tokens" — rotated fresh during this work.
2. `plugins/marketing/tools/integrations/email-bison.md` — § Credential storage rewritten for Bitwarden; § One-time per-dev onboarding added; § Registration rewritten for user-level distribution; § Known Claude Code limitation added documenting the full failure matrix; § Last verified dated.
3. `CONTRIBUTING.md` § Email Bison MCP Onboarding — twin of the Salesforce MCP onboarding section, directed at user-level registration today with a forward pointer to plugin-scoped migration when upstream is fixed.
4. `memory/reference_outbound_mcp_servers.md` § Registration — corrected to reflect user-level registration + blocker + what-ships.
5. Plugin version bumped to `0.2.1` (patch). Rationale: plugin capability surface (MCP servers registered) did not change; only docs + onboarding infrastructure.
6. `plugins/marketing/CHANGELOG.md` — new `[0.2.1]` entry.

### What reverted

- `plugins/marketing/.mcp.json` — back to main's HEAD (salesforce entry only). No EB entries.
- `plugin.json` + `marketplace.json` version — 0.2.0 → 0.2.1 (not 0.3.0 as originally planned).

### Follow-up

- File a Linear issue: "Migrate EB MCP entries to plugin-scoped `.mcp.json` when Claude Code supports HTTP+env-var header substitution." Link to the 4 upstream issues + this PR. Recheck quarterly or on `claude --version` bump.
- File upstream on `anthropics/claude-code`: a fresh issue titled something like "HTTP MCP plugin-scoped `${ENV_VAR}` headers broken; stdio-wrapper workarounds also fail due to URL-substring reclassification." Include reproduction.

### Lessons learned

1. Plugin-scoped HTTP MCP with per-dev Bearer auth is a dead end in current Claude Code. The empirical bug surface is worse than the documentation suggests. `${user_config.*}` substitution with `sensitive: true` (keychain) is the only working path per public precedent (`includeHasan/prospect-studio`) — but changes onboarding UX and has its own open bugs around prompt-on-enable. Future similar issues should start with `userConfig` or accept user-level registration.
2. `claude mcp list` treats any URL substring in args as the server's effective URL. This is an implicit substring-match that can't be escaped by wrapping or nesting. Useful to know when designing future plugin-scoped MCP entries.
3. `mcp-remote@0.1.38` emits verbose startup logs including the full header set to stderr. Document this clearly in any retry to help whoever picks it up.
4. Fast-validation-first plans work. The user-requested restructuring into "prove it works in 5 minutes before touching docs" saved significant rework when the mcp-remote pattern failed. Apply to future infra migrations.
5. Before any skill-authoring or MCP-building work, read Anthropic's official `skill-creator` and `mcp-builder` guidance first. See `memory/feedback_consult_anthropic_skill_patterns.md`.
