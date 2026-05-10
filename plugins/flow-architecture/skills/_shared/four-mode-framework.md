# Four-Mode Scope-Review Framework

Shared review-outcome contract cribbed from gstack `plan-ceo-review`. Establishes the four scope-axis recommendations each FDA reviewer agent returns, and the input/output shape consumer skills parse. This file is a **contract**, not executable code — Q21's seven four-mode reviewer agents implement it; Q42 / Q13 / Q43 / Q47 / `inventory-interview` consume it.

Verified against gstack source via `gh api repos/garrytan/gstack/contents/plan-ceo-review/SKILL.md` on 2026-05-07. Drafter C initially cribbed an imagined verdict-axis taxonomy (APPROVED/ADJUSTED/REWORK/CLARIFY); orchestrator caught the divergence. The taxonomy below is the verified scope-axis source.

## Critical clarification

"Four-mode" labels the **OUTCOME taxonomy** — four discrete scope-intervention recommendations a single agent returns. It is NOT the L-scoping. L-scope (Q54) determines **when** reviewers run and **how many parallel agents fire**; four-modes (Q48) determine **what each agent returns**. Orthogonal axes.

## The four modes

Each reviewer returns exactly one mode per invocation. Mutually exclusive. ALL_CAPS_WITH_UNDERSCORES matches gstack source convention for the structured contract.

- **`SCOPE_EXPANSION`** — agent recommends expanding scope; "dream bigger". Used when current scope feels under-ambitious for the opportunity.
- **`SELECTIVE_EXPANSION`** — agent recommends holding overall scope but cherry-picking specific expansions. Hybrid: keep core + add specific high-value items.
- **`HOLD_SCOPE`** — agent recommends keeping scope as-is; focus on execution rigor. Default for sound plans where the question is "execute well" not "rethink scope".
- **`SCOPE_REDUCTION`** — agent recommends stripping scope to essentials. Used when current scope feels over-ambitious or unfocused.

## Founder-mode framing

Cribbed verbatim from gstack source (verified 2026-05-07):

> CEO/founder-mode plan review. Rethink the problem, find the 10-star product, challenge premises, expand scope when it creates a better product.

This framing applies to `plan-ceo-reviewer` invocations; other reviewer agents adapt the framing to their perspective while preserving the scope-axis taxonomy.

## Interface

Closed enum for context fields (mirrors Q46's type-registry pattern). New fields require Q48 amendment with audit trail. The verbatim signature, copied from the Q48 lock (memory:1190-1216):

```typescript
review_input = {
  subject: string,
  perspective: 'ceo' | 'design' | 'eng' | 'qa' | 'docs' | 'story' | 'devex',
  scope_level: 'L1' | 'L2' | 'L3' | 'L4',
  context: {                                       // closed enum; new fields require Q48 amendment
    q41_template?: string,
    story_doc?: string,
    parent_issue?: string,
    sibling_summaries?: string[],
    linear_brief_snapshot?: string,
    custom_framing?: string
  }
}

review_output = {
  mode: 'SCOPE_EXPANSION' | 'SELECTIVE_EXPANSION' | 'HOLD_SCOPE' | 'SCOPE_REDUCTION',
  headline: string,                                // soft-warn at <50 words per Q41 discipline; one-paragraph summary
  expansions?: string[],                           // present iff mode ∈ {SCOPE_EXPANSION, SELECTIVE_EXPANSION}
  reductions?: string[],                           // present iff mode == SCOPE_REDUCTION
  rigor_focus?: string[],                          // present iff mode == HOLD_SCOPE
  rationale?: string[],                            // optional; explanation for chosen mode
  adjustments?: string[],                          // REFRAMED per refinement 7 lock — see "Adjustments reframed" below
  strategic_concerns?: string[],                   // plan-ceo-reviewer specific (Q21:400)
  ergonomic_concerns?: string[]                    // plan-devex-reviewer specific (Q21:401)
}
```

Soft-warn on headline < 50 words matches Q41's locked discipline. Do NOT re-derive this signature; the spec lives at Q48 sub-decision 3 (memory:1189-1218).

## Mode-specific field rules

Per Q48 sub-decision 4:

- `SCOPE_EXPANSION` → `mode` + `headline` + `expansions[]` (1-5 specific scope additions to consider).
- `SELECTIVE_EXPANSION` → `mode` + `headline` + `expansions[]` (cherry-picks; 1-3 entries) + optional `rationale[]` (why hold overall).
- `HOLD_SCOPE` → `mode` + `headline` + optional `rigor_focus[]` (1-5 execution-rigor concerns within the held scope).
- `SCOPE_REDUCTION` → `mode` + `headline` + `reductions[]` (1-5 specific scope strippings).

Perspective-specific fields (`strategic_concerns`, `ergonomic_concerns`) coexist with scope-axis fields per agent — `plan-ceo-reviewer` in `HOLD_SCOPE` mode populates `headline` + `rigor_focus[]` + optionally `strategic_concerns[]`.

## Adjustments reframed (refinement 7 user lock 2026-05-07)

`adjustments[]` was originally locked in Q21 under an implicit verdict-axis assumption ("specific refinements" for an ADJUSTED verdict). Under the scope-axis taxonomy, it is reframed as **"tactical execution refinements within whatever scope mode is recommended"** — coexists with mode-specific fields per agent:

- `HOLD_SCOPE` + `adjustments` = "scope right; here are within-scope tactical edits".
- `SCOPE_REDUCTION` + `adjustments` = "strip these features [reductions]; refactor these tactical bits [adjustments]".
- `SCOPE_EXPANSION` + `adjustments` = "expand to add [expansions]; also refine these tactical bits [adjustments]".
- `SELECTIVE_EXPANSION` + `adjustments` = "cherry-pick these [expansions]; refine these tactical bits [adjustments]".

Backward compatibility preserved: Q43 sub-decision 5's existing consumption ("reviewer's adjustments → bullet list under `**Refinements:**` sub-heading") works unchanged under the reframed semantic. No Q43 amendment needed.

## Framework is a contract, not code

Per Q48 sub-decision 7: this framework is a **shared spec**, NOT executable code or a wrapper. Q21 reviewer agents IMPLEMENT the contract (each agent prompt includes mode-classification guidance + return shape). Consumer skills PARSE the contract (each consumer extracts `mode` + relevant fields from the agent return). Q21 agents and consumer dispatchers reference this file directly; neither wraps the other.

## L-scope composition (consumer-owned)

The framework is per-AGENT-invocation. How many agents fire and how returns compose is a consumer concern:

| L-scope | Reviewers | Mode returns | Composer |
|---|---|---|---|
| L1 PROJECT | CEO + Design + Eng + DevEx (4 parallel) | 4 | `/flow:office-hours` (Q42) → headlines into `docs/product/intent.md` `## L1 review summary`; concerns persist to `docs/plans/l1-concerns-<ISO-8601>.md` |
| L2 DOMAIN | CEO + Design (2 parallel × N domains) | 2 per domain | `flow-inventory-interview` / `flow-add-domain` (Q26 mod 2) → journey doc `## L2 review summary` |
| L3 SUB-FLOW | All 5 disciplines (parallel × N sub-flows) | 5 per sub-flow | `flow-linear-scaffold` (Q13 / Q23 mod 2) → parent issue body `## L3 review summary` |
| L4 DISCIPLINE CHILD | Single per-discipline | 1 | `/flow:plan-{discipline}` (Q43 sub-decision 5) |

Genuine inter-agent disagreement (e.g., L1 CEO returns `SCOPE_EXPANSION` while DevEx returns `SCOPE_REDUCTION`) is "team disagreement worth surfacing": consumers render both in summary; the user resolves at the next gate. No hard-fail composition rule; no CLARIFY semantics — agents must form a scope opinion even with limited info. Questions can be embedded in `rationale[]`; they do not pause composition.

## References

- Q48 — `docs/design-rationale/project_fda_plugin_interview.md` lines 1163-1271.
- Q48 sub-decision 3 (interface signature) — lines 1190-1216.
- Q48 sub-decision 6 (cribbing scope, gstack verification) — lines 1245-1254.
- Q21 amendment 1 — line 1262 (adds `mode` + scope-axis fields to seven of twelve Q21 agents).
- Q54 — meta-Q L-scoping (orthogonal axis).
- Q30.2 — line 281 (file location lock).
- gstack source — `gh api repos/garrytan/gstack/contents/plan-ceo-review/SKILL.md`. Re-verify whenever Q48 is amended.
