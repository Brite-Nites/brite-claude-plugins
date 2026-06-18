# BC-12975 — Execution Plan: `rapid-asset-design` skill

**Design:** `docs/designs/BC-12975-design.md` (approved)
**Deliverable:** one auto-invoked skill at `plugins/marketing/skills/rapid-asset-design/SKILL.md` + version bumps. No command, no new data files, no API integration.
**Branch:** `drake/bc-12975-idea-claude-design-rapid-gtm-asset-workflow-for-the-asset` (off `origin/main`).
**Green gate per task:** `scripts/validate-single.sh marketing` (fast) and finally `scripts/validate.sh` (full). The skill's "tests" are its Tier 1/2 behavioral assertions; verification = validate.sh passes + assertions read true against the written body.

> **Lint traps to avoid (from CLAUDE.md gotchas):**
> - Use **`Flow A/B/C/D`** and `### N. ` numbered headers in the runbook — NOT `## Step N` / `## Step N.M` (the step-sequence linter mis-parses sub-steps; sub-step form must be `Step Nb`).
> - Fully-qualified MCP names only; `${CLAUDE_PLUGIN_ROOT}` for paths, never absolute.
> - Version bump `plugin.json` **and** `marketplace.json` in the SAME commit.

---

## Task 1 — Scaffold skill + frontmatter (2–3 min)
- Create `plugins/marketing/skills/rapid-asset-design/SKILL.md`.
- Frontmatter:
  - `name: rapid-asset-design`
  - `description:` third-person, what + when, trigger terms: "pitch deck", "landing page", "demo", "mobile prototype", "Claude Design", "rapid asset", "campaign page", "GTM asset". Include the boundary: NOT for coding UI from scratch (→ `frontend-design`) or design-system planning (→ `ui-ux-pro-max`).
  - `user-invocable: true`
  - `allowed-tools: Read, Write, Glob, Bash, WebFetch` (R1 resolved: **route to `vercel:deploy`, do NOT declare vercel MCP tools** — stays under the soft-cap).
  - `metadata:` `version: 0.1.0`, `category: GTM Asset Production`, `upstream:` cite the two brite-gtm source docs.
- **Verify:** `scripts/validate-single.sh marketing` passes frontmatter checks; `name` matches dir slug.

## Task 2 — Before Starting + Resolve target vertical (§1, §1b) (4–5 min)
- **Before Starting:** read `docs/marketing-context.md` if present (graceful warn-and-continue if absent — it currently *is* absent in-repo); confirm entity (`brite-nites`/`brite-labs`, never Supply); note Claude Design plan requirement (Pro/Max/enterprise).
- **Resolve target vertical (§1b):** operator names a vertical → validate slug against `${CLAUDE_PLUGIN_ROOT}/data/canonicals/_manifest.yaml` `verticals[]` (hard-fail on unknown, ADR-032 contract) → load `data/canonicals/{vertical}.yaml` (personas+offers+posture) → optional `data/canonicals/icp/{vertical}.json` segment → surface persona titles + offer posture for confirmation. No vertical → generic + hypothesis-framing + recommend picking one.
- **Verify:** body references the exact files/fields from design §5.1; no parallel resolver invented.

## Task 3 — Methodology + Brite Implementation (§2, §3) (5 min)
- **Methodology:** the asset-production loop as a framework — brief → (copy-first) → generate → edit (tweaks/edit-mode/comments) → brand-check → export → handoff/deploy.
- **Brite Implementation:** brand-interface contract table (design §5), vertical brief-shaping (§5.1), token-cost gate, cross-skill boundaries (owns vs hands off to `ui-ux-pro-max` / `frontend-design` / `web-design-guidelines` / `content-strategy` / `email-copywriting`).
- **Verify:** cross-skill boundaries unambiguous; no duplication of the three existing design skills.

## Task 4 — Claude Design Runbook: 4 flows (§4) (6–8 min)
- **Flow A — Pitch deck** via the animated-video-first trick (copy in chat → "make an animated video" → duplicate → "convert to slide deck"); 90/10 edit rule.
- **Flow B — Campaign landing page** from screenshot or URL (<5 min; 3 parallel directions; light/dark/wireframe toggle).
- **Flow C — Animated demo / interactive visual** (hero embeds, product demos; screen-record for video since no direct video export).
- **Flow D — Clickable mobile prototype** (high-fidelity, device frame, multi-screen).
- Each flow: preconditions, prompt patterns (with the resolved vertical persona/offer injected), expected output, edit guidance, handoff.
- **Verify:** uses `Flow A–D` headers (no `## Step N`); prompt patterns reference the §1b resolved inputs.

## Task 5 — Claude Code Handoff & Deploy + Brand-Consistency Checklist + Routing Matrix (§5, §6, §7) (5–6 min)
- **Handoff & Deploy:** ingest Claude Design export (zip / "hand off to Claude Code" command) → cleanup + responsive → **route to the `vercel:deploy` skill**. Deploy is a side-effect → require explicit operator confirmation before deploying; never auto-deploy.
- **Brand-Consistency Checklist:** palette/type/logo/voice + **asset positioning must match the resolved offer posture** (knowledge/free-asset/pilot/risk-reversal).
- **Asset-Type Routing Matrix:** use-case → asset → Claude Design mode → token-cost tier (flag decks + campaign landing pages as highest-leverage per the ticket).
- **Verify:** deploy confirmation gate is explicit; matrix covers all 4 asset types.

## Task 6 — Health Rubric + Anti-Slop Guardrails (§8, §9) (3–4 min)
- **Health Scoring Rubric:** 10 / 7–9 / 4–6 / 1–3 bands for "client-ready asset."
- **Anti-Slop Guardrails:** no generic AI-deck look; **token-cost gate** (don't use Claude Design for what a doc/template does); no fabricated stats on slides; brand-degradation must be explicit never silently faked; no Supply-vertical positioning; hypothesis-framing for any inferred positioning.
- **Verify:** guardrails match house style (situation-mining); token-cost rule present.

## Task 7 — Behavioral Tests (§10) (3–4 min)
- **Tier 1 (free assertions, no tool calls):**
  - "pitch deck for X" → routing matrix returns *deck via animated-video flow*.
  - `marketing-context.md` absent → warns + continues (does not halt).
  - unknown vertical slug → hard-fail referencing the 27-slug manifest.
  - Supply-vertical entity request → refused.
- **Tier 2 (tool-assisted):** deploy tail requires explicit confirmation before invoking `vercel:deploy`.
- **Verify:** assertions are concrete and checkable against the written body.

## Task 8 — Version bump + full validate (2–3 min)
- Bump `plugins/marketing/.claude-plugin/plugin.json` version (minor) **and** the matching `marketing` entry in `.claude-plugin/marketplace.json` — same commit.
- Run `scripts/validate.sh`; fix any lint (step-sequence, frontmatter, MCP-name, path).
- `git check-ignore -v` on the new SKILL.md (APFS gotcha) — confirm tracked.
- **Verify:** `scripts/validate.sh` green; body < ~500 lines.

---

## Out of scope (confirmed)
Per-vertical asset *template files*; auto-detecting vertical from a Linear issue; canonical write-back; any API/automation against the hosted `claude.ai/design`; brite-gtm brand-hub wiring (future ticket).

## Risks carried into execution
- **R3:** `marketing-context.md` is genuinely missing in-repo → Task 7 Tier-1 graceful-degradation assertion must be real.
- Body length: 10 sections + 4 flows may push length; if > ~500 lines, move the 4 flows or the routing matrix to a `${CLAUDE_SKILL_DIR}/reference.md` (one level deep).
