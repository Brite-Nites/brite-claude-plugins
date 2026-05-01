# BC-6548 — Lowercase tokens silently render as literal text — add validation in email-copywriting + launch-campaign

**Issue:** BC-6548 (Backlog → In Progress at execute start)
**Branch:** `corinne/bc-6548-bc-6308-follow-up-lowercase-tokens-silently-render-as`
**Chain position:** 11th in BC-5906 → BC-6308 chain (1 ship after BC-6544 PR #242)
**Blocks:** BC-6554 (round-4 dogfood walk — 1 of 5 remaining gates)

## Plain-language gist

EB only resolves UPPERCASE merge tokens like `{FIRST_NAME}`. Lowercase ones like `{first_name}` render as the literal text "first_name" in the email — a silent broken send with no diagnostic. We use UPPERCASE everywhere already, but if anyone drifts (hand-edit, port from another tool), the email goes out broken. This plan locks the rule by adding a hard validation step before campaign launch + clear "always UPPERCASE" notes in the skill that writes copy and the EB reference doc, plus a refresh of two "unverified" markers that BC-6308 round-3 has now resolved.

## Scope

**Issue-enumerated sites (3):**
1. `plugins/marketing/skills/email-copywriting/SKILL.md` — add Token-format invariant (around line 47 in § Email Bison format rules; extend hard-failure checklist near line 444)
2. `plugins/marketing/commands/launch-campaign.md` Phase 9 step 2 — add token-case HARD FAIL guard (extend BC-6301's Re: prefix pattern at line 722)
3. `plugins/marketing/tools/integrations/email-bison.md` — add § Token case sensitivity gotcha (around line 279, the existing render-engine cluster)

**Scope-expansion (user-confirmed, BC-5953 + BC-6544 task-1 precedent):**
4. Update 2 stale "unverified" markers to reflect BC-6308 round-3 R-2a verification:
   - `email-bison.md:279` Sx-3 entry — replace "Render-engine case-sensitivity ... is unverified — flagged for verification at BC-6308 round-3 lead spot-check" with the verified outcome
   - `launch-campaign.md:402` Phase 3 step 7 metadata note — same replacement pattern

## Out of scope

- Changing EB's actual render-engine behavior (out of Brite's control)
- Auditing the 14 existing marketing skill templates for lowercase tokens (issue says no audit needed; UPPERCASE convention already locked in)
- Empty-value handling (BC-6549 — separate follow-up)
- Phase 1 step 6 messaging-sanity-checklist defense-in-depth (not in issue scope; Phase 9 step 2 is the canonical mutation gate)

## Tasks

### T1 — email-copywriting/SKILL.md

**Site A** (around line 47, § Email Bison format rules):

Promote the existing convention bullet from soft to invariant. Current:
```
- Use uppercase single-brace variables only: `{FIRST_NAME}`, `{COMPANY}`, `{CITY}`. Never `{{firstname}}` or `{{FIRST_NAME}}` — double-brace breaks the EB merge engine.
```

Replace with explicit case-sensitivity rule:
```
- **All `{TOKEN}` references in step_1.subject, step_1.body, step_2.subject, step_2.body MUST be UPPERCASE** (e.g., `{FIRST_NAME}`, `{COMPANY}`, `{RECENCY_ANCHOR}`). EB's render engine does NOT recognize lowercase tokens as variable references — they render as **literal text** in delivery (verified BC-6308 round-3 R-2a). Authoring a lowercase token (`{first_name}`) is a silent-failure deliverability bug. Never `{{firstname}}` or `{{FIRST_NAME}}` either — double-brace breaks the EB merge engine.
```

**Site B** (around line 444, § Skill-specific hard failures):

Add a new bullet next to the `{{` double-brace HARD FAIL:
```
- **Do not emit lowercase or mixed-case `{token}` references in subjects or bodies.** EB's render engine ONLY resolves UPPERCASE tokens (e.g., `{FIRST_NAME}`); lowercase or mixed-case tokens (`{first_name}`, `{First_Name}`) render as literal text in delivery — verified BC-6308 round-3 R-2a Preview Body output. If a draft contains any `{[a-z][A-Za-z_]*}` pattern, self-correct to UPPERCASE before emit. Hard failure if present in the written artifact.
```

**Verify:** Read both edited sections; confirm no other `{token}` references in SKILL.md were missed.

### T2 — launch-campaign.md Phase 9 step 2

**Site:** line 722, after the BC-6301 Re: prefix HARD FAIL bullet, BEFORE the `step_2.body follows same format constraints` bullet.

Add a new bullet:
```
   - All `{TOKEN}` references in step_1.subject, step_1.body, step_2.subject, step_2.body MUST be UPPERCASE. Grep all `\{[A-Za-z_]+\}` matches; HARD FAIL if any match contains lowercase characters (i.e., `[a-z]`). Error message: "Artifact contains lowercase or mixed-case token `{X}` — EB's render engine only resolves UPPERCASE tokens; lowercase tokens render as literal text in delivery (verified BC-6308 round-3 R-2a). Update the artifact to use UPPERCASE: `{X.upper()}`."
```

**Verify:** Phase 9 step 2 checklist now reads: format constraints → Re: prefix guard → token-case guard → step_2.body → wait_in_days. Order preserved.

### T3 — email-bison.md § Render engine callout

**Site:** Insert a new bullet between line 279 (Sx-3 custom-variable lowercasing) and line 280 (Sx-4 no DELETE).

Add:
```
- **Token render is UPPERCASE-only.** EB's render engine recognizes ONLY UPPERCASE `{TOKEN}` references as variable references (e.g., `{FIRST_NAME}`, `{RECENCY_ANCHOR}`). UPPERCASE tokens resolve via case-insensitive lookup against the lead's `custom_variables` (which EB stores with lowercased names per Sx-3). Lowercase or mixed-case tokens (`{first_name}`, `{First_Name}`) are NOT resolved — they render as literal text without braces (e.g., `{first_name}` becomes the string `first_name` in the delivered email). Always use UPPERCASE in copy artifacts. Verified BC-6308 round-3 R-2a Preview Body output (workspace 13 test campaigns ids 29 + 30, deleted at T14 cleanup). Surfaced by BC-6308 round-3 (R-2a); spec fix shipped in BC-6548.
```

### T4 — Stale "unverified" marker refresh

**Site A:** `email-bison.md:279` (Sx-3 entry, end of bullet).

Replace:
```
Render-engine case-sensitivity (whether `{UPPERCASE_TOKEN}` in a sequence body resolves against the lowercase-stored variable) is unverified — flagged for verification at BC-6308 round-3 lead spot-check. If render is case-sensitive, every uppercase merge token in copy artifacts silently fails to resolve at send time.
```

With:
```
Render-engine case-sensitivity verified BC-6308 round-3 R-2a: UPPERCASE `{UPPERCASE_TOKEN}` resolves correctly against the lowercased store (case-insensitive match); lowercase `{lowercase_token}` does NOT resolve and renders as literal text — see BC-6548 token-case render gotcha below.
```

**Site B:** `launch-campaign.md:402` (Phase 3 step 7, end of metadata note).

Replace:
```
Render-engine case-sensitivity is unverified — flagged for verification at BC-6308 round-3 Phase 4 lead spot-check.
```

With:
```
Render-engine case-sensitivity verified BC-6308 round-3 R-2a: UPPERCASE tokens resolve correctly via case-insensitive lookup against the lowercased store; lowercase tokens do NOT resolve and render as literal text (BC-6548).
```

**Verify:** Grep `unverified.*case-sensit|flagged for verification at BC-6308` across `plugins/marketing/` to confirm no other stale markers remain.

## Validation

- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — confirms no anti-slop introduced
- `./scripts/validate.sh` — full plugin validation (CI-equivalent)
- Grep regression check: `grep -rn -E "\{[a-z][A-Za-z_]*\}" plugins/marketing --include="*.md"` should return zero hits in artifact-template literal positions (false-positives in spec-prose explaining lowercase like `{first_name}` are acceptable when explicitly demonstrating the bug)

## Acceptance criteria

- [ ] `email-copywriting/SKILL.md` line 47 area: UPPERCASE rule promoted from convention to invariant with explicit case-sensitivity language
- [ ] `email-copywriting/SKILL.md` line 444 area: lowercase-token HARD FAIL bullet added next to `{{` double-brace rule
- [ ] `launch-campaign.md` Phase 9 step 2: lowercase-token HARD FAIL bullet added between Re: prefix guard and step_2.body format check
- [ ] `email-bison.md` § Render engine: token-case-sensitivity bullet added between Sx-3 and Sx-4
- [ ] Stale "unverified" markers refreshed in both files
- [ ] All edits cite BC-6308 round-3 R-2a as verification source + BC-6548 as the spec-fix issue
- [ ] Validation scripts pass; bump `plugin.json` + `marketplace.json` version per CLAUDE.md gotcha
- [ ] Commit message follows BC-NNNN convention; trailer per CLAUDE.md commit guidance

## Pacing notes (from feedback_pacing)

Single bundled commit at end of T1-T4 (5-site docs-only edit) — no natural mid-task checkpoint warrants a split. Per BC-6544 + BC-6298 + BC-6300 + BC-6299 + BC-6301 + BC-6302 + BC-6303 + BC-6306 chain pattern: docs-only spec fixes ship as one TRIVIAL commit per task body.

## Precedent activations

- BC-6544 task-1 / BC-6298 task-1: plan-gate scope-expansion (2 stale markers found via grep beyond issue-enumerated 3 sites — surfaced before plan-write, user confirmed include) — 12th application
- BC-6301 task-2: 5x pattern-match brainstorm-skip rule — applied (no brainstorm, single-pattern fix)
- BC-6302 task-1 / feedback_jargon proactive: plain-language gist before plan-write — applied
- BC-5953 task: grep-c verification finds stale markers issue body doesn't enumerate — 2nd application after BC-5953 itself
