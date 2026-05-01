# BC-6556 — launch-campaign Phase 1 step 5 fail-closed (near-term backstop)

**Linear:** https://linear.app/brite-nites/issue/BC-6556
**Branch:** `corinne/bc-6556-fail-closed-validation`
**Worktree:** `.claude/worktrees/bc-6556-fail-closed`

## Summary

Tighten launch-campaign Phase 1 step 5 from warn-and-override to fail-closed when a content variable referenced in the copy artifact has no resolution path (no EB-standard match, no CSV column ≥95%, no non-empty `custom_variables[].default`, no `{SENDER_*}` resolution). Update the example JSON artifact schema in email-copywriting/SKILL.md to model populated defaults instead of empty defaults. Add a short doc note explaining the empty-render finding + the safety-net framing.

Three small edits + version bump. Backstop until BC-6557 (smart-merge formula layer) lands.

## Why this is a docs-only change

Both files are markdown specs that drive agent behavior at runtime — not code. The Phase 1 step 5 spec is what the launch-campaign agent reads and follows; tightening the language tightens the runtime behavior. Same for the SKILL.md example schema and doc note.

## Tasks

### Task 1 — Edit launch-campaign.md Phase 1 step 5 (~5 min)

**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** Phase 1, step 5 (variable-presence check, F7), lines ~212-217

**Current text (last sentence of step 5):**

> "Report any variable that fails all four checks. Operator can override ('proceed despite') via the end-of-Phase-1 gate."

**Change to:**

> "**HALT** if any variable fails all four checks. The error message names the offending variable(s) and the resolution paths each variable failed. No operator override at the end-of-Phase-1 gate — the operator must fix the copy artifact (add a non-empty `custom_variables[].default`, or surface the variable as a CSV column ≥95% populated) and re-run. This fail-closed behavior is the near-term backstop until the smart-merge formula layer (BC-6557) ships the deeper context-aware fallback."

**Verify:**
- Re-read step 5 paragraph end-to-end after edit; confirm wording is unambiguous about the HALT
- Check the end-of-Phase-1 gate text ("User gate 1") around line 239-250 — make sure no leftover "proceed despite" override mechanism contradicts the new fail-closed behavior in step 5. The current gate just asks "Proceed to Phase 2?" with Yes/Abort, which is consistent with the change. No edit needed there.
- Spot-check: does anything else in launch-campaign.md reference the warn-and-override path for content variables? Quick grep for "proceed despite" / "override" in Phase 1.

### Task 2 — Update email-copywriting JSON artifact schema example (~5 min)

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Section:** § JSON artifact schema, lines ~222-244

**Current example:**

```json
"custom_variables": [
  {"name": "COMPANY", "default": ""},
  {"name": "FIRST_NAME", "default": ""},
  {"name": "RECENCY_ANCHOR", "default": ""},
  {"name": "PROOF_POINT_COMPANY", "default": ""},
  {"name": "PROOF_POINT_NUMBER", "default": ""},
  {"name": "FREE_ASSET_NOUN", "default": "architectural preview"},
  {"name": "SENDER_FIRST_NAME", "default": ""}
],
```

**Change to:**

```json
"custom_variables": [
  {"name": "COMPANY", "default": ""},
  {"name": "FIRST_NAME", "default": ""},
  {"name": "RECENCY_ANCHOR", "default": "downtown master-plan announcement"},
  {"name": "PROOF_POINT_COMPANY", "default": "Boulder's Pearl Street"},
  {"name": "PROOF_POINT_NUMBER", "default": "ran 38% higher evening visits"},
  {"name": "FREE_ASSET_NOUN", "default": "architectural preview"},
  {"name": "SENDER_FIRST_NAME", "default": ""}
],
```

**Reasoning for which variables get populated defaults vs. empty:**
- **Populated:** content variables whose value is the same for every lead in the campaign (`RECENCY_ANCHOR`, `PROOF_POINT_*`, `FREE_ASSET_NOUN`). The campaign-wide hook + proof point.
- **Empty:** per-lead variables (`COMPANY`, `FIRST_NAME`) — these always come from per-lead values (CSV columns or EB-standard fields). And `{SENDER_*}` variables — resolved via the priority chain in step 7, not via campaign-level defaults.

**Verify:**
- Read the updated example block top-to-bottom; confirm it parses as valid JSON
- Confirm the populated defaults match the rest of the example artifact's narrative (Denver Parks & Rec, Municipalities, T2 free-asset campaign)
- Check the "Field reference" section directly below the JSON block — does it still describe the `default` field accurately? Yes, the field semantics are unchanged; only the example content changes.

### Task 3 — Add doc note to email-copywriting (~10 min)

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Section:** §4 Architectural rules (lines 261-268), as a new bullet at the end of that subsection

**Add new bullet:**

```markdown
- **Content-variable defaults must be non-empty (BC-6556 fail-closed gate).** Email Bison's render engine substitutes any unresolved `{TOKEN}` with empty string — silent, no error (verified BC-6308 round-3 R-2b: `{RECENCY_ANCHOR}` with null value rendered as `""`, producing `"Saw the  at Acme Bob..."` with double-space). To prevent this in production: every content variable referenced in `step_1`/`step_2` subject/body MUST have a non-empty `custom_variables[].default` in the artifact. Per-lead variables (`{COMPANY}`, `{FIRST_NAME}`) and sender variables (`{SENDER_*}`) are exceptions — they're resolved via per-lead CSV values and the §5 Workflow 1 priority chain respectively, not via campaign-level defaults. Enforced by `launch-campaign.md` Phase 1 step 5 fail-closed gate. Defaults are a **safety net** for prospects with thin per-lead data, not a substitute for good per-lead values — for high-personalization campaigns, populate the per-lead value via the CSV. Long-term direction: smart-merge formula layer with context-aware fallback (BC-6557).
```

**Verify:**
- Wording matches the rule's intent — fail-closed at launch time, defaults are safety net not substitute
- Cross-link to BC-6556 (this issue) and BC-6557 (smart-merge research) is correct
- Bullet flows naturally from the existing four bullets in §4 (entity-canon, offer-tier, preset-files, supply-vertical, hypothesis-framing)
- Total file size under any guardrail limit (`./scripts/check-guardrails.sh` if applicable to SKILL.md — verify scope before running)

### Task 4 — Plugin version bump (~2 min)

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json` — bump `version` field (patch-level)
- `.claude-plugin/marketplace.json` — bump matching marketing plugin entry's `version` field

**Verify:**
- Both versions match
- Bump is patch-level (e.g., `0.1.0` → `0.1.1`, or whatever current version + 1 patch)
- Per CLAUDE.md rule: bump in the SAME commit as plugin content edits (Tasks 1+2+3)

### Task 5 — Validate + commit (~3 min)

**Run:**
```bash
./scripts/validate.sh
```

This is the CI-equivalent. Confirms plugin.json schema is intact, hook-eval doesn't break, and other guardrails pass.

**Commit strategy:** one commit covering all three edits + the version bump. Since they're all part of the same load-bearing change (fail-closed gate + supporting docs + the version-bump-required-by-the-rule), bundling matches the `feedback_pacing.md` "commits at natural checkpoints" — this is one checkpoint.

**Verify:**
- `./scripts/validate.sh` exits 0
- `git status` shows only the expected 4 files modified
- `git diff` reads cleanly end-to-end

## Out of scope

- Audit + restructure of preset files (28 templates) — confirmed during BC-6549 analysis that template restructure can't fix load-bearing tokens
- Smart-merge formula layer — see BC-6557
- Spintax-fallback investigation — EB confirmed not to support this syntax during BC-6308 round-3 testing

## Test commands (per CLAUDE.md)

- `./scripts/validate.sh` — full validation (CI-equivalent)
- `./scripts/check-guardrails.sh --claude-md plugins/marketing/skills/email-copywriting/SKILL.md` — applicable if guardrails apply to SKILL.md files (verify scope before running)

## Acceptance criteria (mirrors BC-6556 ticket)

- [ ] launch-campaign.md Phase 1 step 5 spec is fail-closed (no operator override path) for content-variable empty-default case
- [ ] email-copywriting/SKILL.md JSON artifact schema example shows populated defaults for content variables
- [ ] email-copywriting/SKILL.md has short doc note explaining the empty-render finding + the fail-closed gate + the safety-net framing
- [ ] plugin.json + marketplace.json version bumped (per CLAUDE.md rule)
- [ ] `./scripts/validate.sh` passes
- [ ] BC-6554 round-4 dogfood walk validates the fail-closed behavior live (post-merge)

## Time budget

20-30 minutes total: ~5 min per content edit + 2 min version bump + 3 min validate + commit + a few minutes of read-back.
