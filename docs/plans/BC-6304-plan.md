# BC-6304 — Clarify two-call vendor gate reality (Sx-9)

**Issue:** [BC-6304](https://linear.app/brite-nites/issue/BC-6304)
**Pattern:** 5th application of BC-5906 round-2 dogfood-bundle pattern (after BC-6298/6299/6300/6301).
**Plan written:** 2026-04-29

## Reconciliation table — issue body vs ground truth

| # | Issue § Scope says | Ground truth (after live read) | Resolution |
|---|---|---|---|
| 1 | Edit `launch-campaign.md` only | `email-bison.md § MCP confirmation gates` (line 238 + line 251) carries the same wrapper-vs-API misframing | User approved scope expansion to both files (2026-04-29 plan-gate, per BC-6298 task-1 precedent — 5th instance of dogfood-bundle pattern) |
| 2 | "Phase 4 § Two-call MCP confirmation gate (lines 315-327)" | Section header is `## Phase 4 — UPLOAD`; the two-call gate prose runs lines 314–326 | Edit the gate prose; phase header itself is fine |
| 3 | "Phase 11 — same qualification re `resume_campaign` (pending direct verification)" | Phase 11 vendor gate uses the EXACT BC-2707 framing the issue is qualifying — same pattern as Phase 4/6 | Apply the same call-api-vs-wrapper qualification |
| 4 | (Implicit "label only, no behavior change") | User-confirmed 2026-04-29: this PR is labeling reality only; "should we install a real vendor-side gate" is a separate investigation | File follow-up Linear ticket post-merge for the wrapper-path investigation; explicitly note the visibility gap in the new prose so the question is auditable |

## Context — what is changing and why

Issue Sx-9 finding: `discover_tools` advertises extended-tier tools (e.g. `bulk_create_leads`, `import_leads_to_campaign`, `resume_campaign`) with descriptions referencing a `confirmation` parameter and a two-call gate. Round-2 dogfood verified those gates are enforced **at the MCP-tool-wrapper layer**, not at the underlying REST API. Via `call_api` (the documented invocation pattern in launch-campaign.md), the API has no `confirmation` field — the load-bearing safeguard is the operator-side `AskUserQuestion` turn, with BC-2707's turn-structure rationale still applying to that operator-side gate.

Today's spec mixes the two layers in language that implies the vendor API is enforcing the gate when the agent goes through `call_api`. Operators reading the spec believe a vendor call-1 returns a confirmation prompt; reality is the API just executes immediately. The fix is purely clarifying language — no behavior change.

**Safety significance:** the labeling fix IS a safety improvement, not just cosmetic. Current spec implies two gates (agent + vendor); reality is one (agent). Future maintainers reading the current spec might rationalize removing the agent-side gate as belt-and-suspenders. Fixing the label closes that trap. Whether to also install a real vendor-side gate (e.g., switch to direct wrapper-tool invocation where the wrapper's own gate fires) is a separate investigation — see Out of scope below.

## Tasks

### Task 1 — Add the wrapper-vs-API note to § Tool tier map

**File:** `plugins/marketing/commands/launch-campaign.md`
**Anchor:** insert after line 53 (the `Tool names in phase narratives are conceptual labels...` paragraph) and before the existing `**Allowed-tools breadth.**` paragraph at line 55.

**Insert this paragraph:**

```markdown
**Vendor confirmation gates via `call_api` (Sx-9, BC-5906).** Extended-tier tools advertised by `discover_tools` may describe `confirmation` parameters and two-call vendor gates in their tool prose. Those gates are enforced by the **MCP-tool-wrapper layer**, NOT by the underlying REST API. Round-2 dogfood verified: `/api/leads/multiple` POST and `/api/campaigns/{id}/leads/attach-leads` POST have no `confirmation` field at the API level; `/api/campaigns/{id}/resume` follows the same pattern. Via `call_api` (this command's documented invocation pattern), no vendor-side confirmation prompt fires — the agent-side `AskUserQuestion` semantic gate is **the only load-bearing safeguard** for every `call_api`-routed mutation. BC-2707's turn-structure rationale still applies to the operator-side gate (model must yield to the user between any two consequential calls); it just lives at the agent layer, not the vendor layer. Restoring vendor-side enforcement would require switching to direct wrapper-tool invocation for the gated tools — tracked as a future follow-up to BC-6304, not in scope for this command's current shape.
```

**Why here:** the § Tool tier map already explains that extended-tier tools route through `call_api`. The wrapper-vs-API note is the natural follow-up — it tells the reader what NOT to expect from the API layer once they've seen how to invoke it.

**Verification:** `grep -n 'wrapper layer' plugins/marketing/commands/launch-campaign.md` returns ≥1 match in the § Tool tier map block.

### Task 2 — Qualify Phase 4 two-call gate prose

**File:** `plugins/marketing/commands/launch-campaign.md`
**Anchor:** lines 314–319 (the existing "Two-call MCP confirmation gate required per BC-2707…" block).

**Replace** (current line 314):

```markdown
**Two-call MCP confirmation gate required** per BC-2707 precedent. `bulk_create_leads` may or may not be vendor-gated — treat it as gated regardless. Pattern:
```

**With:**

```markdown
**Two-call gate required — agent-side, not vendor-side** (Sx-9, BC-5906; turn-structure rationale per BC-2707). Per § Tool tier map, `bulk_create_leads` is invoked via `call_api` against `/api/leads/multiple`, which has NO `confirmation` field at the API level. The two-call gate this phase enforces is the **agent-side `AskUserQuestion`** turn — call-1 issues the API request, the operator sees the proposed action via the gate, and call-2 (or in this phase the chunked equivalent) only fires after a real operator turn. BC-2707's turn-structure guarantee (model must yield between calls) applies verbatim to the operator-side gate. Pattern:
```

**Also update step 4 of the same block** (current line 319):

```markdown
4. **Never** issue both calls in the same turn. The anti-pattern this gate blocks is the skill issuing both calls without a real user turn between them — not the wording of the affirmative (see `docs/precedents/BC-2707.md` for the turn-structure rationale).
```

**With:**

```markdown
4. **Never** issue both calls in the same turn. The anti-pattern this gate blocks is the skill issuing both API requests without a real operator turn between them — not the wording of the affirmative (see `docs/precedents/BC-2707.md` for the turn-structure rationale). Note: there is no vendor `confirmation` parameter to send on call-2 — the second call is just the actual API request after operator approval (see § Tool tier map for the wrapper-vs-API distinction).
```

**Verification:** `grep -n 'agent-side, not vendor-side' plugins/marketing/commands/launch-campaign.md` returns 1 match in Phase 4.

### Task 3 — Qualify Phase 6 two-call gate prose

**File:** `plugins/marketing/commands/launch-campaign.md`
**Anchor:** line 434 (the existing "Two-call MCP gate applies per `email-bison.md`...").

**Replace:**

```markdown
**Two-call MCP gate applies** per `email-bison.md` § MCP confirmation gates + `docs/precedents/BC-2707.md` (turn structure, not vocabulary) — `import_leads_to_campaign` is listed as vendor-gated.
```

**With:**

```markdown
**Two-call gate applies — agent-side** (Sx-9, BC-5906; turn-structure per BC-2707). `import_leads_to_campaign` is listed as vendor-gated in `email-bison.md § MCP confirmation gates`, but per § Tool tier map this command invokes it via `call_api` against `/api/campaigns/{id}/leads/attach-leads`, which has NO `confirmation` field at the API level. The load-bearing safeguard is the agent-side `AskUserQuestion` turn between call-1 and call-2 — same shape as Phase 4. The `allow_parallel_sending` branch below IS a real semantic vendor gate (the API does return a parallel-sending prompt body), so it stays as-written.
```

**Verification:** `grep -n 'agent-side' plugins/marketing/commands/launch-campaign.md` returns ≥2 matches (Phase 4 + Phase 6).

### Task 4 — Qualify Phase 11 two-call gate prose

**File:** `plugins/marketing/commands/launch-campaign.md`
**Anchor:** lines 760–763 (the "Vendor MCP two-call gate (per BC-2707)…" block under § Double-confirm gate).

**Replace** lines 760–763:

```markdown
2. **Vendor MCP two-call gate** (per BC-2707). First call to `resume_campaign` returns a vendor prompt; the skill relays it verbatim; on operator affirmative turn, second call with `confirmation: true`.

The two gates are layered — the operator says "yes" twice per campaign, in two different contexts, with both gates' prompts rendered separately. The anti-pattern this layering blocks: the skill issuing both the intent gate and the vendor gate's second call in the same turn without real user turns between them. Per `docs/precedents/BC-2707.md` the guarantee being enforced is turn structure, not vocabulary — accept any clear affirmative ("yes", "approved", "go ahead", "proceed", "do it"); ambiguous or silent responses still halt.
```

**With:**

```markdown
2. **Agent-side per-campaign turn-structure gate** (Sx-9, BC-5906; turn-structure per BC-2707). Per § Tool tier map, `resume_campaign` is invoked via `call_api` against `PATCH /api/campaigns/{id}/resume`, which has NO `confirmation` field at the API level. The "second gate" is the operator's affirmative turn between two `call_api` requests against the resume endpoint — call-1 surfaces the per-campaign vendor description (which the spec relays verbatim), call-2 actually fires the resume after the operator turn.

The two gates are layered — the operator says "yes" twice per campaign, in two different contexts, with both prompts rendered separately. The anti-pattern this layering blocks: the skill issuing both the intent gate and the per-campaign call-2 in the same turn without real user turns between them. Per `docs/precedents/BC-2707.md` the guarantee being enforced is turn structure, not vocabulary — accept any clear affirmative ("yes", "approved", "go ahead", "proceed", "do it"); ambiguous or silent responses still halt.
```

**Also update Steps section line 786** (current):

```markdown
   - First call to `resume_campaign` with campaign ID, no `confirmation`. Vendor returns the prompt (typically: "This will transition campaign {id} from Draft to Queued and begin sending emails. Proceed?").
```

**With:**

```markdown
   - First call to `resume_campaign` (`call_api` against `PATCH /api/campaigns/{id}/resume`). Per Sx-9 the API has no `confirmation` parameter; the call returns the standard resume response. The "prompt" the spec relays comes from the wrapper-tool's `discover_tools` description, which describes the resume-campaign action in operator-facing language (typically: "This will transition campaign {id} from Draft to Queued and begin sending emails."). Render that description verbatim before call-2 to preserve BC-2707 turn structure.
```

**And step 793** (current):

```markdown
   - On operator affirmative, second call with `confirmation: true`. Record the returned campaign state (should be `Queued`).
```

**With:**

```markdown
   - On operator affirmative, second `call_api` request against the resume endpoint (no `confirmation` field — see § Tool tier map). Record the returned campaign state (should be `Queued`).
```

**And the Forbidden patterns bullet** (current line 810):

```markdown
- Issuing both `resume_campaign` calls in the same turn without a real operator turn between them. Defense-in-depth against same-turn auto-confirm per BC-2707.
```

**With:**

```markdown
- Issuing both `resume_campaign` `call_api` requests in the same turn without a real operator turn between them. Defense-in-depth against same-turn auto-confirm per BC-2707 — the gate is operator turn structure, not a vendor `confirmation` parameter (see § Tool tier map).
```

**Verification:** `grep -c 'agent-side' plugins/marketing/commands/launch-campaign.md` returns ≥3 (Phase 4 + Phase 6 + Phase 11). `grep -n "no .confirmation. field" plugins/marketing/commands/launch-campaign.md` returns ≥3 occurrences.

### Task 5 — Qualifying note in `email-bison.md § MCP confirmation gates`

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Anchor:** line 251 (the trailing paragraph of § MCP confirmation gates: `This pattern is **stronger** than a skill-level "ask the user" step…`).

**Replace** line 251:

```markdown
This pattern is **stronger** than a skill-level "ask the user" step — the MCP itself gates the action, so bypassing it requires an explicit confirmation parameter. Skills should mirror the MCP's two-call shape in their Operational Runbook rather than introducing a parallel confirmation layer.
```

**With:**

```markdown
This pattern is **stronger** than a skill-level "ask the user" step — when invoked through the MCP-tool-wrapper layer, the wrapper itself gates the action, so bypassing it requires an explicit `confirmation` parameter on call-2. Skills should mirror the MCP's two-call shape in their Operational Runbook rather than introducing a parallel confirmation layer.

**Caveat — `call_api` invocation bypasses the wrapper gate** (Sx-9, BC-5906). The `confirmation` enforcement above lives in the MCP-tool-wrapper layer, not in the REST API. Skills that invoke these endpoints via `call_api` (the documented pattern for extended-tier tools — see `/marketing:launch-campaign § Tool tier map`) are sending raw API requests; the gated tools have NO `confirmation` field at the API level. Verified for `/api/leads/multiple` (POST), `/api/campaigns/{id}/leads/attach-leads` (POST), and `/api/campaigns/{id}/resume` (PATCH) during BC-5906 round-2. For `call_api`-based skills, the load-bearing safeguard is the agent-side `AskUserQuestion` turn between call-1 and call-2; BC-2707's turn-structure rationale still applies, just at the agent layer instead of the wrapper layer. Restoring vendor-side enforcement requires switching to direct wrapper-tool invocation where the gated tool is wrapper-callable — tracked as a follow-up investigation to BC-6304.
```

**Verification:** `grep -n 'call_api.*invocation bypasses' plugins/marketing/tools/integrations/email-bison.md` returns 1 match.

### Task 6 — Plugin version bump (per BC-6000 invariant)

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json` (matching marketing entry)

**Action:** bump patch version on both. Even though this is a docs-only change, `commands/launch-campaign.md` lives under `plugins/marketing/commands/`, which IS in the version-bump trigger set per CLAUDE.md gotcha. `email-bison.md` lives under `plugins/marketing/tools/integrations/` which is NOT in the trigger set, but the launch-campaign edit alone requires the bump.

**Verification:** `git diff plugins/marketing/.claude-plugin/plugin.json` shows `version` change; matching `.claude-plugin/marketplace.json` entry version matches.

### Task 7 — Validate

**Command:** `./scripts/validate.sh`
**Expectation:** exits 0.

### Task 8 — File follow-up Linear ticket (post-merge)

After the PR merges, create a Linear ticket in the Brite Plugin Marketplace project with:

- **Title (draft):** "Investigate wrapper-tool invocation path for `resume_campaign` / `import_leads_to_campaign` / `bulk_create_leads` to restore vendor-side confirmation gates"
- **Priority:** Low (or whatever Holden assigns) — labeling fix already de-risks the immediate failure mode.
- **Body sketch:** "BC-6304 documented that `call_api`-routed mutations bypass the MCP wrapper's `confirmation` gate, leaving the agent-side `AskUserQuestion` as the sole safeguard. This issue tracks the research question: are these tools also wrapper-callable directly (i.e., listed in `discover_tools` as direct callables, not just routed through `call_api`)? If yes, switching launch-campaign Phase 4/6/11 to direct wrapper invocation would restore the wrapper's own `confirmation` gate as defense-in-depth atop the agent-side gate. If no, document why and rest on the agent-side gate as canonical."
- **Labels:** `command` (matches BC-6304 sibling chain).
- **Created by:** Corinne. **Unassigned** so Holden can prioritize.

**Why post-merge:** matches BC-5931 task-4 precedent ("file forward-referenced follow-up issues during review phase, not ship phase, so dead references don't ship in the merge"). The investigation ticket only links to BC-6304 once BC-6304 is merged.

## Verification matrix (file-level checks at end of execution)

| Check | Command | Expected |
|---|---|---|
| Tool tier map note added | `grep -c 'wrapper layer' plugins/marketing/commands/launch-campaign.md` | `≥ 1` |
| Phase 4/6/11 qualified | `grep -c 'agent-side' plugins/marketing/commands/launch-campaign.md` | `≥ 3` |
| `no confirmation field` mentions | `grep -c "no .confirmation. field" plugins/marketing/commands/launch-campaign.md` | `≥ 3` |
| email-bison caveat added | `grep -c 'call_api.*invocation bypasses' plugins/marketing/tools/integrations/email-bison.md` | `= 1` |
| Plugin version bumped | `git diff plugins/marketing/.claude-plugin/plugin.json` | shows `version` change |
| Marketplace entry bumped | `git diff .claude-plugin/marketplace.json` | shows marketing entry `version` change |
| validate.sh clean | `./scripts/validate.sh` | exits 0 |
| BC-2707 reference still present | `grep -c 'BC-2707' plugins/marketing/commands/launch-campaign.md` | `≥ 4` |
| Sx-9 attribution present | `grep -c 'Sx-9' plugins/marketing/commands/launch-campaign.md` | `≥ 4` |

## Out of scope

- **No code change.** Pure docs.
- **No CLAUDE.md gotcha promotion** — 5th instance of dogfood-bundle pattern, but per BC-6300 task-1 user-delegation precedent, project-level promotions defer to a future spinoff or `/workflows:promote-precedent` invocation.
- **No edit to `discover_tools` or `search_api_spec` wrapper behavior** — the issue is documenting the wrapper/API distinction, not changing how the wrapper works.
- **No new precedent file authoring during the dogfood-bundle ship phase** — let `/workflows:ship` compound-learnings handle precedent traces post-merge.
- **No installation of a real vendor-side gate.** Investigated and decided post-conversation 2026-04-29: that's a separate research ticket (Task 8 files it), not a BC-6304 deliverable. BC-6304 is labeling reality so future maintainers don't trust a gate that isn't there; restoring vendor enforcement is a different scope.

## Pattern-match log (per BC-6301 task-2 brainstorm-skip recipe)

5th instance of BC-5906 round-2 dogfood-bundle pattern:
- BC-6298: 5 EB API quirks → docs-only update both files → TRIVIAL ship → 1 PR
- BC-6299: Phase 3 VARIABLES Sx-2/3/4 + F15 → docs-only update both files → TRIVIAL ship → 1 PR
- BC-6300: Phase 4 lead-body field names Sx-6 → docs-only update both files → TRIVIAL ship → 1 PR
- BC-6301: Phase 9 SEQUENCE Sx-13/14 → docs-only update both files (+ email-copywriting) → TRIVIAL ship → 1 PR
- **BC-6304** (this plan): Sx-9 wrapper-vs-API gate → docs-only update both files + 1 follow-up ticket → expected TRIVIAL ship → 1 PR

Determinative API/spec contract verified by BC-5906 round-2 transcript (Sx-9 entry). No brainstorm overhead added.
