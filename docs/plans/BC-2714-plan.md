# BC-2714: Research — Map Brite's Outbound Pipeline for Skill Authoring

**Issue:** [BC-2714](https://linear.app/brite-nites/issue/BC-2714)
**Type:** Research (no code changes — output is a findings doc)
**Output:** `docs/research/outbound-pipeline-findings.md`
**Blocks:** BC-2717 (list-building), BC-2718 (campaign-orchestration), BC-2719 (deliverability-audit), BC-2720 (reply-processing), BC-2721 (campaign-analysis), BC-2722 (outbound-playbook)

---

## Task 1: Query handbook for cold outreach playbook content

**What:** Run broad Context7 queries against `/brite-nites/handbook` to discover all files related to the cold outreach playbook.
**Queries:**
- "cold outreach playbook tools tech stack end-to-end workflow"
- "demand generation outbound sending reply processing"
- "email deliverability campaign metrics"
**Output:** List of handbook file paths and a short summary of each.
**Verify:** At minimum, files under `marketing/demand-generation/outbound/cold-outreach-playbook/` are identified.

## Task 2: Read all identified handbook files in detail

**What:** Read each file found in Task 1 — README, tools-and-tech-stack, end-to-end-workflow, and any sub-pages. Take structured notes.
**Output:** Raw notes organized by handbook section: what each file covers, key details, tool references, metrics mentioned.
**Verify:** Every file from Task 1 has been read and summarized.

## Task 3: Map the 5 functional layers with tool assignments

**What:** From the notes in Task 2, construct the 5-layer pipeline map:
1. **Sending** — tools, data flow, configuration
2. **Reply Processing** — tools, routing logic, escalation
3. **Automation** — workflow triggers, sequences, integrations
4. **CRM** — lead management, opportunity tracking, field mapping
5. **Engagement** — tracking, scoring, signals

For each layer: what handbook says (original tool) vs. current Brite tool (2026-04).
**Output:** Layer diagram + tool mapping table.
**Verify:** All 5 layers have both "handbook says" and "current" tool columns filled.

## Task 4: Document handbook drift and migration status

**What:** Cross-reference handbook tool references against known Brite migrations:
- HubSpot → Salesforce (CRM SoR migration — from auto-memory)
- Aircall → Dialpad (per issue description)
- Any other stale references found in Task 2

**Output:** Drift table with columns: Layer, Handbook says, Current (2026-04), Migration status.
**Verify:** Every tool reference in the handbook has been checked against current state. Known migration statuses documented.

## Task 5: Map handbook coverage to each planned skill

**What:** For each of the 5 planned skills, document:
1. **list-building** (BC-2717) — prospect identification, data sourcing, list assembly
2. **campaign-orchestration** (BC-2718) — sequence design, sending cadence, A/B testing
3. **deliverability-audit** (BC-2719) — domain health, inbox placement, SPF/DKIM/DMARC
4. **reply-processing** (BC-2720) — classification, routing, follow-up triggers
5. **campaign-analysis** (BC-2721) — metrics, attribution, reporting

For each: handbook content that maps to it, gaps, stakeholder questions, recommended SoR query targets.
**Output:** Coverage matrix table.
**Verify:** All 5 skills have coverage, gaps, and SoR query recommendations.

## Task 6: Write the findings doc

**What:** Assemble all research from Tasks 1-5 into the prescribed output format at `docs/research/outbound-pipeline-findings.md`.
**Structure:**
1. Layer Diagram (5 layers with tools, data flow)
2. Tool Mapping table (Layer / Handbook says / Current / Migration status)
3. Handbook Coverage Matrix (Skill / Coverage / Gaps / Stakeholder questions)
4. Skill Boundary Recommendations (what each skill owns vs. defers)
5. Open Questions (for stakeholder review)

**Verify:**
- [ ] All handbook cold outreach files read and summarized
- [ ] Tool migration status documented (HubSpot→Salesforce, Aircall→Dialpad)
- [ ] Clear skill boundary recommendations for all 5 outbound skills
- [ ] Findings doc written at `docs/research/outbound-pipeline-findings.md`
- [ ] Gaps and open questions documented for stakeholder review
