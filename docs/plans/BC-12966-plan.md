# BC-12966 — Audit/enhance `email-copywriting` vs. Cold Email Copy Playbook + Proximity Method

**Issue:** BC-12966 (Idea, Low priority) · **Disposition:** HAVE → small ENHANCE
**Target:** `plugins/marketing/skills/email-copywriting/` (marketing plugin)
**Branch:** `drake/bc-12966-idea-auditenhance-the-email-copywriting-skill-vs-the-gtm`

## Sources compared
- Current skill: `plugins/marketing/skills/email-copywriting/SKILL.md` (621 lines) + 28 vertical presets + `evals/evals.json` (9 scenarios)
- Cold Email Copy Playbook (extracted): `brite-gtm@ed034bf:docs/resources/gtm-community/extracted/cold-email-copy-playbook.md`
- Proximity Method (public skill): `github.com/termsheetinator/proximity-cold-email` — `proximity.md` + `spamwords.md`

## Decisions locked (grill-with-docs)
1. **ACV segmentation** → lightweight lens *inside* email-copywriting (§3 subsection).
2. **Spam list** → curated Brite-appropriate subset only. **Reject** finance-domain word bans that collide with Brite vocabulary (`free`, `offer`, `rate`/`rates`, `performance`, `solution`, `new`, `cost`).
3. **Never track open rates** → ALREADY CANON (`launch-campaign.md` Phase 5 step 8 `plain_text:true`; `tam-mapping` `OPEN-TRACKING DISABLED`; `email-bison.md`). Add one-line cross-ref only; no orchestration changes.
4. **Writer-Auditor loop** → FULL loop, adopted. Writer/Auditor are roles one model plays inline (≤3 rounds), the Auditor RUNS existing §8 as its single rule source, and a **compact audit trail** is printed to the operator. **No JSON schema change.**
5. **Subject length** → reconcile to **2–6 words** (real campaigns already exceed 1–3).
6. **Vocabulary** → §3 subsections + handbook cross-refs; **no new ADR**.

## Headline defect
`step_2` bump skeletons (SKILL.md:94, :114) ship `{Circling back|Following up|Bumping this}` — exactly the follow-up clichés BOTH sources ban. This is a live defect, fixed in T1.

---

## Tasks

### T1 — Fix the step_2 bump defect
- **File:** `SKILL.md` Skeleton A step-2 (≈:90-95), Skeleton B step-2 (≈:111-116).
- Replace the `{Circling back|Following up|Bumping this}` openers with angle-based bumps drawn from the new follow-up library (T4) — e.g. insight-add / free-resource framing, no cliché openers.
- **Verify:** grep the two skeletons for `circling back|bumping this|following up` → zero matches (case-insensitive).

### T2 — §3 "Copy principles" subsection (new)
- **File:** `SKILL.md` new subsection under `## Methodology`.
- Content: (a) **Active-position framing** — write from "already working with / already running / already live"; (b) **them-first rule** — name the prospect's company/signal before ours; (c) **subject-as-photograph** — 2–6 words, one mental picture, *clarity > curiosity > clever*; (d) **proximity spectrum** mental model (far-left → middle-right target → too-far-right).
- Note compatibility: active-position (sender stance) coexists with existing hypothesis-framing rule (prospect worldview); credibility ceiling reinforces no-fabricated-proof.
- **Verify:** subsection present; cross-refs resolve.

### T3 — CTA library + friction test + one-email-one-CTA
- **File:** `SKILL.md` new §3 subsection.
- Low-friction CTA phrasings ("Want me to send it?", "Mind if I send the breakdown?", "Would you hate me if I sent…"), the **friction test**, and the **one-email-one-CTA** rule.
- **Verify:** subsection present; skeletons' CTAs consistent with the rule.

### T4 — Follow-up angle library + "what NOT to do"
- **File:** `SKILL.md` new §3 subsection.
- Angles: insight-add / social-proof / free-resource / permission-close (+ humor / algorithm / direct-close). Explicit **"what NOT to do"** cliché list ("just bumping this up", "circling back", "haven't heard from you", "I'm sure you're busy but…").
- Follow-up angle = **authoring guidance only** (no `step_2.angle` schema field).
- **Verify:** library present; T1 bumps draw from it.

### T5 — ACV-segmentation lens
- **File:** `SKILL.md` new §3 subsection.
- ACV decision tree (<$10k → ROLE; $10–50k → SIZE+ROLE; >$50k → INDUSTRY+PAIN) + 4-questions-per-segment, framed as "what to emphasize in copy." Cross-ref icp-scoring/situation-mining as upstream inputs.
- **Verify:** subsection present; positioned as lens, not a schema/IO change.

### T6 — Writer-Auditor loop (full)
- **File:** `SKILL.md` new section (after Methodology, before/within Operational Runbook) + wire into Flow 1/2/3 pre-Write step.
- Roles played inline by one model: Writer drafts → Auditor runs §8 guardrails + curated spam subset + proximity/active-position checks → FAIL returns line-level fixes → Writer revises flagged lines only → loop ≤3 rounds → on persistent fail, surface current draft + remaining issues.
- After loop: write the **same JSON artifact** + print **compact audit trail** (rounds run, issues resolved, spectrum positions). Internal exchange hidden.
- **Verify:** loop documented; Flows reference it; no new required JSON fields.

### T7 — Extend §8 anti-slop (single rule source)
- **File:** `SKILL.md` §8 + the subject-length rule at :53.
- Add: setup-verb ban (build/set up/install/launch/create/implement) in body; follow-up-cliché ban list; **curated** Brite spam-trigger subset (ALL-CAPS, multiple `!!!`, pressure phrases like "act now"/"limited time" — explicitly NOT the finance word bans); explicit **RE/FWD subject-spoofing exclusion** note (do-not-adopt, deliverability/trust risk).
- Reconcile subject length **1–3 → 2–6** at :53.
- **Verify:** §8 lists the new bans; subject rule says 2–6; allow-listed Brite words (`free`,`offer`,`rate`,`performance`) are NOT banned.

### T8 — Cross-ref "never track open rates"
- **File:** `SKILL.md` (deliverability note near §3 or Brite Implementation).
- One line pointing to `launch-campaign.md` Phase 5 step 8 + `email-bison.md` `plain_text:true` canon.
- **Verify:** cross-ref present; no orchestration files touched.

### T9 — Reconcile §7 rubric + presets/README
- **Files:** `SKILL.md` §7 Health Rubric; `presets/README.md:37`.
- §7: reference the loop + new guardrails in scoring bands. `presets/README.md`: subject "1-3 words" → "2-6 words"; fix the stray `Re: {subject}` mention (canon: do NOT include `Re:`).
- **Verify:** README subject-length + Re: note consistent with §3/§8.

### T10 — New eval scenarios
- **File:** `evals/evals.json`.
- Add Tier-1 scenarios: `followup-cliche-ban` (no circling-back/bumping in step_2), `setup-verb-ban` (no build/install/launch in body), `friction-test-cta` (single low-friction CTA), `photograph-subject-length` (2–6 words). Add Tier-1/2 `writer-auditor-audit-trail` (audit-trail summary emitted; artifact still written).
- Mirror new scenarios as Behavioral Tests in SKILL.md.
- **Verify:** `evals.json` parses; ids match SKILL.md Behavioral Tests.

### T11 — Version bump (same commit)
- **Files:** `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (marketing entry), `evals/evals.json` `version`.
- Bump marketing plugin minor (per CLAUDE.md cache-keying gotcha — required in the SAME commit as skill edits).
- **Verify:** versions match across plugin.json + marketplace.json; evals version tracks skill `metadata.version`.

### T12 — Validate
- Run `./scripts/validate.sh` (CI-equivalent) + `./scripts/check-guardrails.sh` if applicable.
- Run marketing lint if present; confirm no Step-sequence false positives from new `## Step`-like headings.
- **Verify:** validate.sh green.

---

## Scope guard
Consistent with "HAVE → small ENHANCE": **no new skill, no new command, no JSON-schema break.** Changes are concentrated in `SKILL.md` (§3 + §8 + §7 + skeletons + new loop section), `evals.json`, `presets/README.md`, and version metadata. The Writer-Auditor loop (T6) is the heaviest piece; if preferred it can land as a second commit after T1–T5/T7–T11.

## Out of scope
- Authoring new `handbook/marketing/frameworks/*` pages for the new vocabulary (different repo; cross-ref/define-inline for now).
- Orchestration/open-tracking changes (already canon).
- Porting Proximity's full 350-word finance spam list.
- RE/FWD subject-spoofing (explicitly rejected).
