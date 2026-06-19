# BC-12975 — Rapid GTM-Asset Design Workflow (Claude Design + Claude Code handoff)

**Status:** Design — pending approval
**Issue:** [BC-12975](https://linear.app/brite-nites/issue/BC-12975) — `[Idea]` Claude Design rapid GTM-asset workflow for the asset team (decks / landing pages / demos). Project: *Asset Studio*. Owner: Sarah + Max (GTM asset team). Disposition: PLAY / workflow idea.
**Decision (this session):** Build a **single auto-invoked skill in the `marketing` plugin**. No slash command (so no ADR-028 command eval-gate burden). Source docs: `brite-gtm/docs/resources/gtm-community/extracted/{claude-design-build-decks-demos-and-web-pages-in-minutes, claude-code-claude-design-the-b2b-and-gtm-scaling-playbook}.md` (read from git `ed034bf`).

---

## 1. Problem

The GTM asset team (brite-gtm Phase 6) already *has* design capability — what it lacks is a **fast, repeatable, brand-safe loop** for producing client-facing assets: pitch decks, campaign landing pages, animated demos, and clickable mobile prototypes. The external GTM-community walkthrough surfaced **Claude Design** (`claude.ai/design`) as a way to cut deck/landing-page turnaround from hours to minutes, with a clean **Export → Hand off to Claude Code → deploy** path.

The ask is **speed + repeatability + brand-consistency**, not net-new design capability.

## 2. Key constraints (these shape the whole design)

1. **Claude Design is a hosted product, not scriptable.** It lives at `claude.ai/design` (Pro/Max/enterprise). Claude Code cannot call it. Therefore this skill is a **human-in-the-loop playbook** that (a) tells the operator exactly how to drive Claude Design well, and (b) automates only the *tail* — the Claude Code cleanup + deploy step.
2. **Brand guardrails live in `brite-gtm`, not this repo.** brite-claude-plugins has the 23-vertical canonicals, offer-design frameworks, and an *expected-but-currently-missing* `docs/marketing-context.md`. So the skill defines a **brand-interface contract with graceful degradation** (mirrors situation-mining's enrichment fallback): use brand inputs when present, warn-and-continue when absent.
3. **Token cost is real.** Source docs repeatedly warn Claude Design "burns tokens fast." The skill bakes in an explicit **when-NOT-to-use** rule.
4. **Skill-only ⇒ no command eval gate.** ADR-028's emit-mode + behavioral-eval requirement applies to *commands*. A pure skill carries none. Confirmed in this session.

## 3. Scope — what the skill owns vs hands off

**Owns:**
- Brief framing for Claude Design with Brite brand inputs (the brand-interface contract).
- **Vertical-aware brief-shaping** (first-class step) — resolve the target vertical against the canonicals and inject persona/offer/posture/ICP into the brief + brand-consistency checklist (see §5.1).
- Asset-type routing (which asset wins for which use case) + token-cost gate.
- The proven Claude Design techniques: *animated-video-first → convert to deck*; *screenshot/URL → landing page in <5 min*; the 90/10 edit rule; tweaks-panel vs edit-mode vs comments.
- The **Claude Code handoff + deploy tail**: ingest the exported zip/handoff command, clean up code, make responsive, deploy via the existing `vercel:deploy` skill.
- A post-generation **brand-consistency checklist**.

**Hands off to (existing skills — cross-referenced, not duplicated):**
- `ui-ux-pro-max` — when the operator needs a design system / palette / font direction *before* prompting Claude Design.
- `frontend-design` — when the exported asset needs real code polish beyond cleanup.
- `web-design-guidelines` — to audit a deployed landing page for accessibility/UX compliance.
- `content-strategy` / `email-copywriting` — when slide/landing copy needs drafting first (the source docs' "write copy in chat first" step).

**Explicitly out of scope:** building a Claude Design clone, any API integration with the hosted product, brand-asset storage (stays in brite-gtm), and net-new design capability.

## 4. Proposed skill

- **Plugin:** `marketing`
- **Path:** `plugins/marketing/skills/<slug>/SKILL.md`
- **Name (proposed):** `rapid-asset-design` *(alternatives: `gtm-asset-design`, `claude-design-workflow`. The Linear project is literally "Asset Studio" — `asset-studio` is tempting but overloaded; deferring to review.)*
- **`user-invocable: true`**, `allowed-tools: Read, Write, Glob, Bash, WebFetch` (+ `mcp__plugin_vercel_vercel__*` for the deploy tail — *to confirm against the MCP soft-cap note; may instead just reference the vercel:deploy skill without declaring the tools*).
- **Description (draft):** third-person, trigger terms: "pitch deck", "landing page", "demo", "mobile prototype", "Claude Design", "rapid asset", "campaign page", "GTM asset". States it produces client-facing GTM assets via claude.ai/design + Claude Code handoff, and that it is NOT for coding UI from scratch (→ frontend-design) or design-system planning (→ ui-ux-pro-max).

### Body structure (marketing 10-section house style)

1. **Before Starting** — read `docs/marketing-context.md` if present (brand voice / entity / ICP); else warn + continue. Confirm Brite entity (`brite-nites` / `brite-labs`, never Supply). Note Claude Design plan requirement.
1b. **Resolve target vertical** (first-class) — operator names a vertical (or skips for generic). Validate the slug against `data/canonicals/_manifest.yaml` `verticals[]` (hard-fail on unknown, same contract as plan-campaign Step 2 / ADR-032). Load `data/canonicals/{vertical}.yaml` (personas + offers + posture) and, when a specific offer/segment is targeted, `data/canonicals/icp/{vertical}.json`. Surface the resolved persona titles + offer posture for confirmation. Graceful: no vertical → generic positioning + hypothesis-framing, with a recommendation to pick one. Reuses ADR-032's single-source ICP resolution — **does not** build a parallel resolver.
2. **Methodology** — the asset-production loop as a repeatable framework: brief → (copy-first) → generate → edit (3 modes) → brand-check → export → handoff/deploy.
3. **Brite Implementation** — the brand-interface contract; the asset-type routing matrix; token-cost gate; cross-skill boundaries.
4. **Claude Design Runbook** — 4 end-to-end flows: (A) pitch deck via animated-video trick; (B) campaign landing page from screenshot/URL; (C) animated demo / interactive visual; (D) clickable mobile prototype. Each: preconditions, prompt patterns, expected output, edit guidance, handoff.
5. **Claude Code Handoff & Deploy** — ingest export → cleanup → responsive → `vercel:deploy`. Mark side-effects (deploy) and require explicit confirmation before deploying.
6. **Brand-Consistency Checklist** — post-generation gate (palette, type, logo usage, voice, vertical-appropriate positioning per canonicals/offer frameworks).
7. **Asset-Type Routing Matrix** — use-case → recommended asset → which Claude Design mode → token-cost tier.
8. **Health Scoring Rubric** — 10 / 7–9 / 4–6 / 1–3 bands for "is this asset ready to ship to a client."
9. **Anti-Slop Guardrails** — no generic AI-deck aesthetics; token-cost gate (don't use for what a doc/template would do); no fabricated stats on slides; brand-degradation must be explicit, never silently faked; no Supply-vertical positioning.
10. **Behavioral Tests** — Tier 1 (free assertions: routing matrix returns a deck for "pitch", graceful warn when marketing-context.md absent, refuses Supply entity); Tier 2 (tool-assisted: deploy tail confirmation gate fires).

## 5. Brand-interface contract (graceful degradation)

The skill expects, but does not require, these brand inputs:
| Input | Source if present | If absent |
|---|---|---|
| Voice / tone | `docs/marketing-context.md` | Warn; ask operator inline or proceed neutral |
| Entity (Nites/Labs) | marketing-context.md / operator | Ask via AskUserQuestion; never default to Supply |
| Palette / fonts / logo | operator-supplied or brite-gtm pointer | Note dependency; recommend `ui-ux-pro-max` to generate a direction |
| Vertical positioning | resolved in §5.1 | Generic positioning + hypothesis-framing |

### 5.1 Vertical-aware brief-shaping (first-class)

The skill resolves the target vertical against the canonicals and injects the result into both the Claude Design brief and the brand-consistency checklist. Data sources (already present — no new files):

| Resolution | File | Fields injected into the brief |
|---|---|---|
| Valid-slug gate | `data/canonicals/_manifest.yaml` → `verticals[]` (27) | hard-fail on unknown slug |
| Audience | `data/canonicals/{vertical}.yaml` → `personas[].titles` | who the asset addresses |
| What it sells + how | same → `offers[]` (`display`, `posture`, `target_personas`) | offer + posture (knowledge / free-asset / pilot / risk-reversal per ADR-017) drives tone + CTA |
| ICP detail (optional) | `data/canonicals/icp/{vertical}.json` → segment `industries`, `intent_signals` | sharper audience framing when a segment is targeted |

> **ICP-layer dependency (review fix):** the `data/canonicals/icp/` layer (BC-11163 / ADR-032) is **not yet merged to `main`**. The skill treats the ICP read as genuinely optional — absent directory ⇒ degrade to `{vertical}.yaml` personas/offers. `seed_accounts` / `exclusions` are internal-only and must never reach a client asset or shared link. The slug-validation contract (`_manifest.yaml` `verticals[]`) **does** exist on `main` independently of ADR-032.

**Rules:** validate-or-hard-fail on the slug against `_manifest.yaml`; never invent a vertical outside the 27-slug canon; Nites + Labs only (no Supply); offer posture governs the asset's stance, and the **brand-consistency checklist asserts the produced asset matches that posture**. Resolution is the same single-source path plan-campaign uses — this skill reads, it does not re-implement.

## 6. Risks / open questions

- **R1 — vercel MCP tools vs soft-cap.** Declaring `mcp__plugin_vercel_vercel__*` may be unnecessary; the deploy tail can simply *route to* the `vercel:deploy` skill. Decision in planning. *(Lean: route, don't declare.)*
- **R2 — Skill name.** `rapid-asset-design` vs `gtm-asset-design` vs `asset-studio`. Confirm at plan time.
- **R3 — marketing-context.md is currently missing in-repo** (see memory note BC-12570). Graceful degradation must be genuinely exercised by a Tier-1 test, not assumed.
- **R4 — Cross-repo brand guardrails.** We document the contract + dependency here; the actual brite-gtm brand-hub wiring is a separate future ticket, not this PR.

## 7. Acceptance (maps to the ticket's open dimensions)

- ✅ Respects brand guardrails → brand-interface contract + brand-consistency checklist + graceful degradation.
- ✅ Fits vs existing frontend-design/ui-ux-pro-max/web-design-guidelines → explicit cross-skill boundaries, no duplication.
- ✅ Names the winning asset types → routing matrix (decks + campaign landing pages flagged as highest-leverage, per the ticket).
- ✅ Repeatable workflow + handoff-to-Claude-Code path → the runbook + deploy tail.
- ✅ **Vertical-aware** → §5.1 resolves persona/offer/posture/ICP from the canonicals into the brief; slug validated against the 27-vertical manifest (ADR-032 contract). Out of scope: per-vertical template *files*, auto-detecting the vertical from a Linear issue, canonical write-back (future tickets).

## 8. Validation / ship requirements

- `plugins/marketing/skills/<slug>/SKILL.md` with matching `name:` frontmatter; body < ~500 lines.
- Bump `plugins/marketing/.claude-plugin/plugin.json` **and** the `.claude-plugin/marketplace.json` marketing entry in the same commit.
- `scripts/validate.sh` green (frontmatter, step-sequence lint — use `Step Nb` not `Step N.M`; no hallucinated MCP names; `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_SKILL_DIR}` paths).
- No command ⇒ no emit-mode/eval gate. Skill ships Tier 1/2 behavioral tests per house style.

## 9. Extension — BriteBase Design System wiring + per-vertical deck templates (added 2026-06-19)

The original design treated brand palette/fonts/logo as "lives in brite-gtm, degrade gracefully" (§5, R4) because the design system wasn't reachable from this repo. It now is: the **BriteBase Design System** is a live `claude.ai/design` project (readable via the `/design-sync` skill) mirrored by the `brite-brand-hub` repo's `colors_and_type.css`. Two extensions landed on this branch:

**9.1 Brand-token resolution (skill).** Added a **Resolve Brand Tokens** step (ordered sources: live DS via `/design-sync` → `brite-brand-hub` checkout → operator paste → explicit degrade) + a reusable `{brand_tokens}` block embedded in Flow A and the Handoff Prompt. Routes the live read to `/design-sync` rather than declaring the design-system tool (R1's "route, don't declare"). Flow A retargeted to the **animated intro deck**. Brand snapshot committed at `plugins/marketing/data/brand/britebase-tokens.json` (synced from `colors_and_type.css`).

**9.2 Per-vertical deck templates — reversing §7's "out of scope" deferral.** §7 deferred per-vertical template *files*; this builds them as the GTM-asset-team standard, **generated, not hand-authored** (the canonicals are the per-vertical truth and they change — 27 hand-made copies would rot). Two layers:
- **Visual standard (once):** `skills/rapid-asset-design/assets/intro-deck-skeleton.html` — the brand-locked 4-archetype slide skeleton, published into the BriteBase DS via `/design-sync`; reps seed projects from it.
- **Content standard (generated):** `scripts/build_deck_template.py` (deterministic, stdlib-only, `--check` drift mode; mirrors the `build_*.py` + `test_*.sh` house pattern) resolves canonical personas/offers/posture + brand tokens → `data/deck-templates/{vertical}-intro-deck.md` (rep cheat-sheet + paste-ready prompt, three blanks `{prospect}`/`{contact}`/`{angle}`, posture guardrail). Pilot: `municipalities`.

**Decisions (this session):** form = generated prompts + 1 DS skeleton; access = mixed (power reps self-serve, asset team runs for the rest); coverage = municipalities pilot → replicate (Active set first); landing = extend PR #483 (folded in rather than a new ticket). Self-test `test_build_deck_template.sh` wired into `validate.sh` (§15a-bc-12975). The generator structurally never reads the ICP layer, so `seed_accounts`/`exclusions` cannot leak into a client-facing template. Marketing `0.14.0 → 0.14.2`.
