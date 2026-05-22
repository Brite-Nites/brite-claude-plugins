# FDA Plugin — Resume Bridging Prompt (post-Phase-3-close)

> **How to use this file.** Paste the bridging block below verbatim as
> the first user message in a new Claude Code session inside this
> repo (`Brite-Nites/brite-claude-plugins`). It gives the new drafter
> (Phase 4) or drafter + orchestrator pair (Phase 5 / Phase 6)
> immediate full design-rationale context without re-reading 2,306
> lines of the memory snapshot. Treat it as the equivalent of the
> orchestrator handoff prompt that bootstrapped this work originally.
>
> **Updating this file.** If the state below drifts (e.g., new
> phases close, new amendments land, new editorial fixes apply), the
> resuming session is expected to update this prompt as part of its
> own session-windup, mirroring the validation-first discipline that
> got us here.

---

```markdown
══════════════════════════════════════════════════════════════
FDA PLUGIN — RESUME BRIDGING PROMPT (post-Phase-3-close)
══════════════════════════════════════════════════════════════

PROJECT: Flow-Driven Architecture (FDA) plugin v1.0 codification.
Builds plugin `flow-architecture` at `plugins/flow-architecture/` in
`Brite-Nites/brite-claude-plugins`. Closes 2026-05-10 Phase 3 (Linear
scoping); Phase 4 (implementation) is the resumption target.

═══════ ARCHIVE LOCATIONS ═══════

CANONICAL (this repo, committed via plugin-repo PR #260):
  plugins/flow-architecture/docs/design-rationale/
    fda-plugin-interview.md         (2,306-line memory snapshot)
    fda-plugin-architecture-overview.md     (1,174-line synthesis)
    fda-plugin-drafter-d-windup.md          (D session windup)
    fda-plugin-drafter-e-revision-2.md      (E source draft, 21-issue bodies)
    00-resume-bridge.md                     (this file)

HISTORICAL (brite-base PR #174 — OPEN at time of writing; merge at
convenience, non-blocking for Phase 4):
  https://github.com/Brite-Nites/brite-base/pull/174
  Same 4 files at brite-base:docs/plans/fda-plugin-*.md until post-Phase-6
  deletion per docs/plans/<id>.md "delete after ship" convention.

══════ LINEAR SCOPE (Brite Plugin Marketplace project) ══════

Milestone: "Flow-Driven Architecture Plugin v1.0"
  id 0bf7b980-5d7c-4a18-a2ca-3af58df4a8f8
  21 issues created: parents BC-6959/60/61; standalones BC-6954/55/56/57/
  62/63/64/65/69/71/72/73/75/77/96/97/98/99
Label: `flow-architecture` (id d3f9fd25-1d5f-4ecf-ac2e-deab6f1a896f)
Per-issue label set: [flow-architecture, <categorical>, <T-shirt size>]
  categorical ∈ {skill, agent, command, infrastructure, documentation}
  size ∈ {size-S, size-M, size-L} (parents have no size)

══════ Q-LOCK NAVIGATION (memory line refs) ══════

  Q1 amend 1 (CDR-014 Phase Pattern self-application)  L62-66 + scope tests
  Q1-Q12 scoping interview                              L2208-2255
  Q11 21-issue enumeration                              L2227-2253
  Q21 12 named agents + amendment 1 scope-axis fields   L452 + L1236
  Q30 plugin scaffold                                   L274
  Q31 breadcrumb schema base + amend 1+2                L300 + L318 + L323
  Q37 / Q47 orchestrator phase trees                    L671 / L732
  Q40 production readiness (12 criteria, 4 categories)  L1769
  Q42 / Q43 / Q46 office-hours / plan-X / writeback     L885 / L1063 / L986
  Q48 four-mode framework (gstack-verbatim taxonomy)    L1163
  Q50 / Q51 / Q52 / Q53 cloning taxonomy + per-step     L1444 / L1470 / L1524 / L1621
  Q55 plugin CLAUDE.md content (13 H2 sections)         L1680

═══════ METHODOLOGY DISCIPLINES (operational, codified in Q55 §11) ═══════

1. Validation-first cycle (bidirectional + transitive): orchestrator catches
   drafter; drafter catches orchestrator; both catch own prior work; both catch
   inherited errors. 34 catches total across the interview.
2. Parking-lot-#39 + extension: re-verify cribbed sources at EACH consumer
   lock, NOT inheritance. Heavily-cited foundation locks accumulate errors at
   downstream consumer drafting.
3. Three-way cribbing taxonomy (Q50 sub-decision 7): FDA-native (most Qs);
   gstack-inspired (Q42 + Q44 + Q48; loose transfer with verbatim-where-cited);
   workflows-cloned (Q51 + Q52 + Q53; full clone with FDA-swap per 7-axis).
4. Schema-discipline amendment pattern: amendment-with-audit-trail in BOTH
   originating + target Q-locks; original incorrect text preserved; cross-link
   amendments. 16 amendments precedent across the interview.
5. Per-cluster authorization gates (Phase 3 lesson): per-cluster gates aren't
   just user-direction checkpoints — they're validation-first synthesis rounds
   that catch surface-vs-record-completeness gaps at cluster boundaries.

═══════ EDITORIAL-FIX LEDGER (5 total, Phase 3) ═══════

  FIX-1 drafter   BC-6955  Q31 schema citation expansion
  FIX-2 drafter   BC-6971  CC1 strict separate-greps batch + retention rationale
  FIX-3 drafter   BC-6997  Q40 amendment-count cascade footnote 6 → 16
  FIX-4 orch      BC-6959  predictive-ID drift (BC-6958-61 → BC-6962-BC-6965)
  FIX-5 orch      BC-6963  Brand Hub dogfood cross-link backfill (→ BC-6998)

══════ PHASE STATUS ══════

  ✓ Phase 1  Design close        (2026-05-08)
  ✓ Phase 2  Org PRs landed      (2026-05-10; handbook PR #513 + #514 merged)
  ✓ Phase 3  Linear scoping      (2026-05-10; 23 mutations + memory amendment)
  ◐ Phase 4  Plugin impl         (RESUME HERE — drafter-solo per Q9 narrowed)
  □ Phase 5  Brand Hub dogfood   (Q8 v1.0 acceptance gate; BC-6998)
  □ Phase 6  Release v1.0        (BC-6999; CDR-023 Proposed → Accepted)

══════ ORCHESTRATOR ROLE ══════

Retired post-Phase-3 per Q9 narrowed lock. Re-emerge for:
  - Phase 5 Brand Hub dogfood (BC-6998)
  - Phase 6 release coordination (BC-6999)
NOT re-emerge for: Phase 4 implementation (drafter solo).

══════ RE-ADDRESS BEFORE STARTING ══════

  1. Read this prompt (you just did).
  2. Read plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md
     end-to-end OR grep-navigate via Q-lock line refs above.
  3. Apply parking-lot-#39 + extension at every cribbed-content lock.
  4. Invoke `mcp__plugin_workflows_linear-server__get_issue` on the BC-ID you're
     resuming work on; verify body matches design-rationale memory before edit.
══════════════════════════════════════════════════════════════
```

---

**Authoring metadata.** Written 2026-05-10 by the retiring Phase 3
orchestrator session as part of Q9.2 cross-repo bridging closure.
Drifts vs. the original drafted version (caught by the first Phase 4
session that consumed it):

1. ~~"brite-base PR #174 merged into main"~~ — corrected to OPEN at
   time of writing; merge at convenience, non-blocking for Phase 4.
2. ~~"canonical archive at plugins/flow-architecture/docs/design-rationale/"~~
   — corrected to "committed via plugin-repo PR #260". Path now exists
   in this repo.

If you spot further drift, update this file as part of session-windup
— the prompt is a living artifact, not a frozen snapshot.
