# BC-6301 Plan — Phase 9 SEQUENCE: variant boolean + auto-Re: prepend

**Issue:** [BC-6301](https://linear.app/brite-nites/issue/BC-6301) — High priority, 5th BC-5906 round-2 follow-up.
**Pattern:** Docs-only spec correction (matches BC-6298/6299/6300/6306 — all `/workflows:review` TRIVIAL).
**Branch:** `corinne/bc-6301-bc-5906-follow-up-launch-campaign-phase-9-sequence-variant`

## What this fixes (plain language)

Two small bugs in how `/marketing:launch-campaign` Phase 9 creates the 2-step email sequence in Email Bison:

1. **`variant` field is wrong type.** Spec sends the string `"A"`; EB wants a boolean `false`/`true`.
2. **Double `Re:` prefix.** Spec tells operators to write step_2 subjects starting with `"Re:"`. EB auto-prepends `"Re: "` whenever `thread_reply: true`, so recipients get `"Re: Re: ..."`.

## Plan-gate scope questions (decide before execution)

**Q1 — Co-update `tools/integrations/email-bison.md`?**
Established 4-ship pattern (BC-6298/6299/6300/6306) — when spec drift surfaces an EB API contract fact, we co-update the canonical EB reference. Recommended: **yes**, both findings (variant type + auto-Re: behavior) belong in the integration doc, not just the command spec.

**Q2 — Dogfood artifact handling.**
Two test-copy.json files reference `Re:` prefix:
- `docs/dogfood/bc-5826/test-copy.json` — production-template artifact. **FIX.**
- `docs/dogfood/bc-5906/test-copy.json` — round-2 dogfood input that surfaced Sx-14. **KEEP VERBATIM** as historical evidence.

## Tasks

### Task 1 — Fix `variant: "A"` → `variant: false` in launch-campaign.md (Sx-13)

**File:** `plugins/marketing/commands/launch-campaign.md`
**Lines:** 615, 623 (issue-body lines 600/608 are stale).
**Change:** `"variant": "A"` → `"variant": false` in both blocks.
**Verify:** `grep -nE '"variant"\s*:\s*"' plugins/marketing/commands/launch-campaign.md` returns nothing.

### Task 2 — Reverse `Re:` prefix rule + update preview example (Sx-14)

**File:** `plugins/marketing/commands/launch-campaign.md`
**Three edits:**

1. **Line 600** (Phase 9 step 2 validation rule) — reverse:
   - From: `step_2.subject` starts with `Re:` (per EB format rule).
   - To: `step_2.subject` does NOT start with `Re:` — EB auto-prepends `Re: ` when `thread_reply: true`. HARD FAIL if subject starts with `Re:`.

2. **Line 630** (explanatory text below the JSON body) — clarify:
   - Add: ...AND triggers EB to auto-prepend `Re: ` to step_2.email_subject in delivery.

3. **Line 689** (Phase 10 preview example) — show the auto-prepend explicitly:
   - From: `> Subject: Re: Quick question`
   - To: `> Subject: Quick question  (EB delivers as: "Re: Quick question")`

**Verify:** `grep -nE 'starts with .Re:.|Re: subject pattern' plugins/marketing/commands/launch-campaign.md` returns no broken-rule lines.

### Task 3 — Sweep `email-copywriting/SKILL.md` for `Re:` prefix references

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**4 lines confirmed via grep:** 55, 135, 155, 237

1. **Line 55** (rule statement) — reverse to: `Step 2 subject does NOT include a Re: prefix. EB auto-prepends Re: at delivery when thread_reply: true (which step 2 always has).`

2. **Lines 135, 155** (skeleton step-2 bump examples) — change `Subject: Re: {subject}` → `Subject: {subject}  (EB delivers as "Re: {subject}")`

3. **Line 237** (JSON artifact schema example) — drop the `Re: ` prefix from the step_2.subject value.

**Verify:** `grep -nE 'Re: \{|"Re: ' plugins/marketing/skills/email-copywriting/SKILL.md` returns no lines.

### Task 4 — Fix bc-5826 production-template artifact

**File:** `docs/dogfood/bc-5826/test-copy.json`
**Line 24:** strip `"Re: "` from step_2.subject.
**Skip:** `docs/dogfood/bc-5906/test-copy.json` (historical evidence per Q2).

### Task 5 — Co-update `tools/integrations/email-bison.md` (if Q1 = yes)

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Add to § Known gotchas / Sequence section:**

- `variant` is BOOLEAN, not a string. Send `false` (or `true` for A/B variants). Sending `"A"` will 422 or silently coerce. (Source: BC-5906 round-2 Sx-13.)
- EB auto-prepends `Re: ` when `thread_reply: true`. Send the bare subject for step_2; EB prepends in delivery. Sending `"Re: <subject>"` produces double-Re: in the recipient's inbox. (Source: BC-5906 round-2 Sx-14.)

### Task 6 — Bump plugin version

**Per CLAUDE.md gotcha:** edits under `plugins/marketing/commands/` and `plugins/marketing/skills/` require version bump in same commit.

**Files:**
- `plugins/marketing/.claude-plugin/plugin.json` — `0.3.12` → `0.3.13`
- `.claude-plugin/marketplace.json` — matching marketing entry → `0.3.13`
- `plugins/marketing/CHANGELOG.md` — append `0.3.13` entry with one-line BC-6301 summary.

## Validation

1. `./scripts/validate.sh` — full plugin validation passes
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — passes
3. Manual grep sweep — no `"variant": "A"` or `"Re: {` lines remain in shipped paths
4. `/workflows:review` — expect TRIVIAL verdict (5th instance of pattern)

## Out of scope

- BC-6308 round-3 dogfood re-walk (validates this fix end-to-end against `emailbison-personal`) — separate issue.
- Deeper audit of dogfood artifacts beyond bc-5826/bc-5906 (none found in grep sweep).
