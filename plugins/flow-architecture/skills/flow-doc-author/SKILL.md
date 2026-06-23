---
name: flow-doc-author
description: Per-domain story doc authoring sub-skill for the flow-architecture plugin (implements CDR-023). Writes N markdown files at `docs/product/flows/<domain>/<flow-id>.md`, one per sub-flow under a domain, conforming to the Q27 locked template + Q27 amendment 1 (mod 4: optional `## Cross-domain dependencies` section). Hybrid authoring — deterministic frontmatter stamping via the extracted `scripts/build_story_frontmatter.py` builder (scaffold-log children/parent + caller params + constants, fixture-locked); parallel background `Agent(story-doc-author)` body-only dispatch for up to 9 narrative sections (the 9th — `## Cross-domain dependencies` — is OPTIONAL per Q27 amendment 1 and authored only when the sub-flow has cross-domain build-order or gating relations). Runs AFTER `flow-linear-scaffold` so parent + children BC numbers + sibling `blockedBy` relations are available for 1:1 mirror. 2-layer fidelity-review (mechanical `verify-docs.sh` + per-doc narrative drift check). 0 synchronous gates in default mode (filesystem writes; git review is the implicit gate). Per-domain authoring wall ~60s greenfield, ~90s retrofit; the second-wave fidelity-review fan-out adds ~30-60s, which can be overlapped with downstream `flow-journey-author`.
user-invocable: false
disable-model-invocation: true
allowed-tools: Agent, Bash, Read, Write, Edit, Glob, Grep
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q15, Q27"
  related-locks: "memory:108-124 (Q15 7 sub-decisions); Q13.3 fidelity-review pattern (memory:86); Q27 story-doc template"
---

# flow-doc-author

Per-domain story doc authoring sub-skill. Writes one markdown file per sub-flow conforming to the Q27 locked story-doc template. Authors N files in parallel via background agents; collects at sub-flow boundary.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7).

**Ordering constraint.** Runs AFTER `flow-linear-scaffold` (Q13) so the parent + children BC numbers are available for substitution. The orchestrator owns this ordering; this skill assumes scaffold-log output is available in the run state.

The full design rationale lives in `docs/design-rationale/fda-plugin-interview.md` Q15 (memory:108-124). Q27 defines the story-doc template; Q13 (memory:80) defines the upstream scaffold; Q22-Q28 define the substitution sources.

---

## 1. Authoring strategy (Q15.1) --- hybrid

### Deterministic stamping --- the `build_story_frontmatter.py` builder (BC-13168)

The frontmatter is stamped by an **extracted deterministic builder**, not LLM prose, so it is fixture-lockable and cannot silently regress to the empty `children:` / `personas:` placeholders that shipped on every prior scaffold (BC-13028 #4; the BC-11996 hand-fix that recurred). The skill shells out to `scripts/build_story_frontmatter.py`, which reads **only** the per-domain scaffold-log (`.flow/scaffold-log/<domain>.md` --- canonical table shape per `templates/.flow/scaffold-log/SCHEMA.md`; join key `flow_id`/`DOMAIN-NN` per ADR-029) and assembles the frontmatter from the scaffold-log + caller-supplied params + constants:

```
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/build_story_frontmatter.py \
  --scaffold-log <repo>/.flow/scaffold-log/<domain>.md --flow-id <DOMAIN-NN> --as-of <today> \
  [--status <BUILT|IN_PROGRESS|…>] [--personas <role,role>] [--related-flows <ID,ID>]
```

| YAML key | Source |
|---|---|
| `flow_id` | `--flow-id` arg |
| `domain` | `flow_id` prefix (builder-derived) |
| `parent_issue` | **scaffold-log** parents table (builder) |
| `children.{story,engineering,design,qa,docs}` | **scaffold-log** discipline-children table (builder); a missing/errored cell → `TBD` |
| `status` | `--status` (the skill's Q15.7 code-evidence result, capped at BUILT) --- default `NOT_STARTED` |
| `personas` | `--personas` (skill-derived; see note) --- honest `[]` when unknown |
| `related_flows` | `--related-flows` (skill-derived adjacency) --- honest `[]` when unknown |
| `qa_status` | constant `not-tested` |
| `qa_last_signed_off` | constant `null` |
| `eng_status` / `design_status` / `docs_status` | constant `not-started` (delivery mirrors → INDEX; updated post-build, not at scaffold) |
| `figma` / `sandbox_url` / `staging_url` / `real_app_url` / `e2e_test` / `user_docs_url` | constant `TBD` (`sandbox_url` upgraded post-scaffold from Q15.7 code-evidence --- **NOT** the inventory Notes column, which holds component names like `edit-role-dialog`) |
| `intent` | constant `../../intent.md` (per Q27 mod 1) |
| `last_reviewed` | `--as-of` (current ISO-8601; injected so the builder stays golden-stable) |

**Why `personas`/`related_flows` are skill-derived params, not builder inventory reads.** The consumer `master-flow-inventory.md` schema is not standardized across repos and usually carries no personas/related_flows column, so the builder cannot source them deterministically --- it does **not** parse the inventory at all. The skill derives them (from the inventory row when a persona column is present, else the parent journey / `docs/product/personas/` / interview `partial_state`, per BC-13028's "pass personas via `partial_state`") and passes them through; absent → the builder stamps an honest empty `[]`, never a silent placeholder. The lock is `tests/run-story-frontmatter-vslice.sh` (ADR-028 D2-style golden + populated-key assertions).

**Redirect stubs (alias sub-flows).** When a sub-flow is an intentional **alias** --- its canonical story lives at another `flow_id` (commonly another domain in the same repo, e.g. `SFI-05` → `ACL-06`) --- stamp a redirect stub instead of a story doc and author **no body**:

```
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/build_story_frontmatter.py \
  --flow-id <DOMAIN-NN> --doc-type redirect --redirect-to <canonical-DOMAIN-NN> --as-of <today>
```

This emits the 6-key `REDIRECT_CANON` front-matter (no `--scaffold-log`, no body); the audit validates it as a redirect (resolvable pointer + strict-gated front-matter) and skips the story-frame / AC / children gates. Use this only for an alias you or the orchestrator have already identified --- the skill does **not** auto-detect which flows are aliases. Full convention in `docs/decisions/037-fda-redirect-stub-convention.md` (ADR-037).

### Agent-authored body (body-only contract)

One `Agent(story-doc-author, run_in_background: true)` per sub-flow authors the **body only** --- the H1 title `# <DOMAIN-NN>: <Inventory title>`, the doc-type-warning blockquote, and the narrative sections below --- and returns it as markdown. The skill prepends the builder-stamped frontmatter and writes the file. The agent **never emits frontmatter**: it is filesystem-only with no Linear/scaffold-log access, so it cannot know `children: [BC-…]` --- that contradiction was the proximate cause of the empties. Each agent fills:

1. one-line summary blockquote
2. optional `## Status notes` (Q27 mod 2 --- include only when status drift OR retrofit code-evidence flag)
3. optional `## Cross-domain dependencies` (**Q27 amendment 1 mod 4** --- include only when the sub-flow has cross-domain build-order or gating relations. Bullet list of `<this-flow-id> blockedBy <other-flow-id>` and/or `<this-flow-id> gates <other-flow-id>` lines, each with a one-line reason. 1:1 mirror of Linear `blockedBy` relations on the sub-flow parent issue --- enforced by Q29 amendment 2 `cross-domain-deps-bidirectional` gate. Same-domain sibling deps go in `related_flows` front-matter, NOT here.)
4. `## Job story` --- When/I want/So I can JTBD format
5. `## Actor` --- RBAC + persona doc cross-link
6. `## Preconditions` --- max 3 bullets
7. `## Acceptance criteria` --- 3-5 Gherkin `Scenario:` blocks
8. `## Out of scope`
9. `## QA history` --- initial empty row

---

## 2. Dispatch pattern (Q15.2) --- parallel background

Per sub-flow the skill (1) runs `build_story_frontmatter.py` to stamp the frontmatter block (Section 1), (2) dispatches one `Agent(story-doc-author, run_in_background: true)` to author the body, and (3) at collection prepends the stamped frontmatter to the returned body and writes `docs/product/flows/<domain>/<flow-id>.md`. Skill collects all agents at sub-flow completion. The deterministic stamp does not wait on the agent --- it is computed from the scaffold-log up front.

**Wall time:** ~30-60s for any N (vs ~4-8 min serial for N=8). Each agent receives:

- The instruction to return the **body only** (`# <H1>` through `## QA history`); the skill owns the frontmatter via the builder and concatenates.
- Q27 template path (incl. Q27 amendment 1 mod 4 `## Cross-domain dependencies` section).
- Persona doc(s) for the personas that act in THIS sub-flow specifically — resolved from the skill-derived `personas` for this sub-flow (the same set the skill passes to the builder via `--personas`, Section 1), not the project-wide persona set. For each role named in that field, resolve `docs/product/personas/<role>.md`; if the standalone doc is absent, fall back to that role's persona block in the parent journey's per-phase persona lines (or the intent.md `## Target users` cross-link). Embed the resolved subset in `partial_state` so each agent gets the individuated persona(s) for its flow, never a single project-wide default.
- Journey doc (if already authored --- in greenfield this skill runs before journey-author, so usually unavailable).
- Inventory row.
- Code-evidence summary (if status > NOT_STARTED --- Section 7).
- Cross-domain blockedBy snapshot for this sub-flow parent issue (from `flow-linear-scaffold` scaffold-log output --- list of `<other-flow-id, blocker-bc>` pairs; empty list = no cross-domain deps; agent omits the `## Cross-domain dependencies` section in that case).

---

## 3. Idempotency (Q15.3) --- skip-if-exists + `--force`

Pre-write check per sub-flow path. If `docs/product/flows/<domain>/<flow-id>.md` exists:

- **Default:** skip + summarize at end-of-run.
- **`--force`:** overwrite.
- **Interactive mode:** per-doc `AskUserQuestion` --- Overwrite / Skip / Cancel.

---

## 4. Fidelity-review (Q15.4) --- 2-layer

### Mechanical layer

`bash scripts/verify-docs.sh` once after the batch (logs to stdout but does NOT block). Catches mechanical issues --- broken internal links, malformed front-matter, stale `last_reviewed`.

### Narrative layer

Per-doc background fidelity-review agent. Each agent diffs the authored doc against:

- Q27 template structure.
- Persona doc(s).
- Journey doc (if available).
- Inventory row.
- Code-evidence (if collected).

Returns either `PASS` or the top-3 narrative drift findings, capped at 100 words. Same pattern as Q13.3 (per-issue fidelity review in `flow-linear-scaffold`). FAILs surface in the run summary; user can `--force` regen targeted at the failed doc.

---

## 5. Failure recovery (Q15.5) --- log + continue

Story docs are independent --- an agent failure on doc #3 doesn't cascade to docs #4-N. Failed-doc surfaces in the end-of-run summary; user re-runs the skill with `--force` (idempotent against the failure list). Same pattern as Q14.5 in `flow-legacy-cross-reference`.

---

## 6. User-confirmation gates (Q15.6) --- 0 synchronous gates

Filesystem mutations are reviewable post-hoc via `git diff` + `verify-docs.sh` + commit/PR review. Linear writes (Q13) need synchronous gates because the world sees them immediately; markdown files in a branch are pre-publication.

**Pattern rule:** Linear writes -> synchronous gate; filesystem writes -> git review gate.

Contributes 0 to Q10's 5/4 retrofit/greenfield gate budget.

---

## 7. Retrofit code-evidence (Q15.7) --- deterministic per-sub-flow scan

Trigger: inventory status > NOT_STARTED.

Glob/Grep/Read targeted at feature folders:

- `src/components/<domain>/`
- `src/app/(frontend)/(app)/<route>/`
- `src/payload/collections/<collection>.ts`

Extract:

- Existing AC scenarios from `*.test.ts` files -> feed to the narrative agent as `## Acceptance criteria` candidates.
- Component file paths -> populate `<sandbox_url>` heuristic.
- Sandbox URL from `src/components/sandbox/sandbox-nav.tsx`.

### Status mapping caps at BUILT

| Code state | Mapped status |
|---|---|
| code-exists + tests + sandbox-URL | BUILT |
| code-exists but incomplete | IN_PROGRESS |
| no code | NOT_STARTED |

**Cannot promote to QA_SIGNED_OFF** --- requires the Linear QA child's sign-off (workflow event, not codebase state).
**Cannot promote to SHIPPED** --- requires customer-doc filesystem signal at `docs/product/customer-docs/<domain>/<flow-id>.md` (scoped out of code-evidence; v1.1 candidate).

### Status drift handling

If the inventory says NOT_STARTED but code-evidence shows BUILT (or vice versa), the skill flags the drift in the doc's `## Status notes` section --- NOT a silent overwrite:

> BUILT --- code-evidence cited; inventory marked NOT_STARTED --- recommend reconcile.

BriteBase Cut 1a "BUILT --- code-evidence cited" pattern (TEAM-01..06 precedent).

### Status taxonomy

`NOT_STARTED -> IN_PROGRESS -> BUILT -> QA_SIGNED_OFF -> SHIPPED` + `BLOCKED` orthogonal. No `PARTIALLY_BUILT` state. Verified against `master-flow-inventory.md:22-27`, `flows/INDEX.md:15-20`, `docs/templates/job-story.md:4`.

---

## Worked example

Greenfield `/flow:start-project` for the AUTH domain with N=8 sub-flows after Q13 scaffold has written 8 parents + 40 children:

1. Skill reads `state.scaffold_log.auth` -> 8 parent BCs + 40 children BCs.
2. Skill walks `master-flow-inventory.md` AUTH section -> 8 inventory rows.
3. Skill fans out 8 background agents in parallel; each writes one story doc to `docs/product/flows/auth/auth-NN.md`.
4. ~50s wall time for all 8 agents to return.
5. Mechanical layer: `bash scripts/verify-docs.sh` logs 0 errors.
6. Narrative layer: 8 fidelity-review agents return; 7 PASS, 1 flagged for missing `## Out of scope` section.
7. End-of-run summary: `flow-doc-author: 8/8 docs authored, 1 narrative-drift flagged (auth-04 missing Out of scope).` User can re-run with `--force=auth-04` to regen.

---

## See also

- `docs/design-rationale/fda-plugin-interview.md` Q15 --- canonical 7-sub-decision spec.
- `docs/design-rationale/fda-plugin-interview.md` Q27 --- story-doc template.
- `docs/design-rationale/fda-plugin-interview.md` Q13 --- upstream scaffold (provides parent + children BCs).
- `skills/flow-linear-scaffold/SKILL.md` --- preceding sub-skill.
- `skills/flow-journey-author/SKILL.md` --- downstream sub-skill that consumes these story docs as authoring context.
- `skills/flow-preflight/SKILL.md` --- preceding sub-skill; preamble's `MODE` signal drives whether Q15.7 code-evidence fires (retrofit) or skips (greenfield).
