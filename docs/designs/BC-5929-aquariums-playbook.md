## Design: BC-5929 aquariums vertical playbook

**Issue**: BC-5929 — Create `plugins/marketing/references/vertical-playbooks/aquariums.md`
**Date**: 2026-04-23

### Problem
Aquariums (R-5 of the email-copywriting preset roadmap) need their own vertical playbook because they're structurally different from zoos (indoor / climate-controlled / $50–$60 21+ tickets / summer Glow Nights / humid tank galleries / husbandry-controlled tank lighting). The zoos-ledger split decision (2026-04-21) already invalidated the combined vertical; this issue delivers the separate authoritative reference that BC-5933 (aquariums presets) and all future aquariums-vertical marketing work consume.

### Approach
Reference-file pattern (BC-5920 / BC-5921 / BC-5922 lineage, 3rd iteration). Research-agent deep-dive first (issue Task 1), pre-compose gate, then 9-section playbook composition. Apply BC-5921/BC-5922 precedents mechanically; engineer deliberately for 3rd-instance architecture promotion where research supports it.

### Key Decisions
1. **Hybrid 3-candidate offer space for research brief.** Evaluate Glow-Native 21+ After-Hours (aquarium-native — revenue-share on adult tickets + bioluminescence/UV content), Production-Finance E-analog (zoos pattern — sponsor orchestration), and Permanent Canvas Offer-B-analog (pending R-19). Operator picks primary at pre-compose gate. Rationale: aquariums' structural uniqueness (21+ revenue shape, humidity constraint, better Brite fit) makes the aquarium-native candidate probably winning, but we don't foreclose the zoos-analog without research.
2. **Target 1–2 precedent promotions.** (a) If OdySea Aquarium Moment Factory precedent holds in research, invert Moment Factory framing at aquariums → BC-5921 task-1 3rd instance → elevates to architecture 9/10 + standing recipe check. (b) If Shedd Jellies Lightswitch permanent install is representative of an aquarium architectural-lighting-design-firm archetype, add as vertical-unique 5th archetype → BC-5921 task-3 2nd instance.
3. **Pre-compose gate mandatory (BC-5921/BC-5922 task-2).** Issue Task 4 prescribes VP-titled personas (VP Revenue / Director of Adult Programs / Director of Operations / Director of Guest Experience). Same enterprise-VP-title tell as hotels (R-7) and ski (R-8). Schedule batched AskUserQuestion after research is in hand, before composition: (i) persona set (research-backed vs issue-body vs hybrid), (ii) Moment Factory framing (primary-with-inversion vs peer-paragraph vs rare), (iii) primary offer pick.
4. **ICP = mid-market/independent aquariums; enterprise flagships = ceiling references.** Matches hotels + ski convention. Already implicit in issue voice rule ("no enterprise-aquarium name-drops Georgia / Monterey Bay as default"). No operator question needed.
5. **AC literal-grep trap sweep extended per BC-5922 task-3.** AC grep bans `magical undersea`, `immersive wonder`. Sweep all URL slugs for substrings `magical` / `immersive` / `undersea` / `wonder` / other AC-banned tokens before AC check. Swap citations if any URL trips the grep.
6. **Tank-lighting husbandry exclusion is a hard rule, not a voice note.** Issue Non-Goal #3 ("Do NOT pitch tank-engineering lighting"). Goes in § Anti-slop AND § Voice rules AND Brite-wins/loses positioning.

### Alternatives Considered
- **Aquarium-native-only offer set (Glow-Native + Holiday Overlay).** Rejected — narrows research brief prematurely; loses zoos-analog comparison value. Operator chose hybrid.
- **Mechanical precedent application without promotion engineering.** Rejected — memory flywheel metrics show architecture-class promotions compound faster than pattern-class repeats. Operator chose promotion-target.
- **Compose directly from zoos + hotels playbooks without fresh research.** Rejected — issue Task 1 requires research-agent deep-dive; aquarium vendor landscape (Lightswitch / Christie Digital / Available Light / humidity-rated-architectural firms) did not surface from the BC-5879 session research.

### Risks & Mitigations
- **Research contradicts a precedent-promotion hypothesis** (e.g., OdySea turns out to be a one-off with no broader Moment Factory aquarium presence) → promote only one precedent, not both; document null-result hypotheses in precedent file explicitly.
- **Persona research doesn't clearly contradict issue directive** → pre-compose gate presents "keep issue directive" as a real option, not just a formality.
- **Offer-candidate research exceeds 3 candidates** (e.g., research surfaces a distinct "Corporate Event Add-On" aquarium offer type) → extend candidate list; don't force fit.
- **URL slug AC-grep trap during composition** → run `grep -ci 'magical\|immersive\|undersea\|wonder'` against full file at AC check time, not just rule bodies (BC-5922 task-3 defensive discipline).
- **Husbandry-controlled tank-lighting exclusion misread as soft rule** → mirror in § Anti-slop #3, § Voice rule #5, and Brite-wins/loses body; reject any composition that hints at tank-engineering pitching.

### Scope Boundaries
- **In scope**: `plugins/marketing/references/vertical-playbooks/aquariums.md` (9 sections per issue spec), 1-2 precedent promotion entries in `docs/precedents/BC-5929.md`, corresponding INDEX.md row updates, plan file at `docs/plans/BC-5929-plan.md`, validate.sh baseline preservation.
- **Out of scope**: BC-5933 preset composition (R-11), BC-5938 preset-library ship readiness (R-16), BC-5941 Facilities-VP motion confirmation (R-19 blocker for Offer B), Tianyu / Chinese-lantern framing (already excluded by issue), tank-engineering / husbandry-controlled lighting (hard exclusion per issue Non-Goal #3), enterprise aquariums as primary ICP (ceiling references only).

### Open Questions
- None at design approval. Remaining uncertainty lives in the research output and is resolved at the pre-compose gate.
