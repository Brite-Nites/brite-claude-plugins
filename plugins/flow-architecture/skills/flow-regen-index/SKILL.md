---
name: flow-regen-index
description: Deterministic INDEX.md rebuild sub-skill for the flow-architecture plugin (implements CDR-023). Regenerates the 11-column per-domain tables in `docs/product/flows/INDEX.md` from story-doc front-matter + Linear discipline state. Preserves section headers, status notes, footnotes, and intro prose verbatim. No Agent dispatch, no fidelity-review — pure deterministic algorithmic output. Triggers: `/flow:regen-index` (user-invocable wrapper), auto-invoked at end of `/flow:add-domain` + `/flow:add-sub-flow`, auto-invoked by `/flow:ship` after a story-doc front-matter edit. Per-regen footprint ~15s end-to-end for a Brand-Hub-shaped 28-domain project.
user-invocable: false
disable-model-invocation: true
allowed-tools: mcp__plugin_workflows_linear-server__list_issues, Bash, Read, Write
license: MIT
metadata:
  version: "0.1.0"
  q-locks: "Q18, Q25"
  related-locks: "memory:179-206 (Q18 8 sub-decisions)"
---

# flow-regen-index

Deterministic INDEX.md rebuilder. Reads story-doc front-matter and Linear discipline state, computes 11 columns per row per Q25 schema, and replaces ONLY data rows in `docs/product/flows/INDEX.md`. Section headers, intro prose, status notes, and footnotes survive verbatim.

This skill is **NOT user-invocable** (`disable-model-invocation: true`, per Q7). The user-facing wrapper is `/flow:regen-index`; orchestrators (`/flow:add-domain`, `/flow:add-sub-flow`, `/flow:ship`) auto-invoke this skill internally.

**No LLM dispatch.** Output is mechanical — column derivations are pure functions of (story-doc front-matter, master-flow-inventory rows, Linear issue state). No fidelity-review (the contract is "regenerate, don't narrate").

The full design rationale lives in `docs/design-rationale/project_fda_plugin_interview.md` Q18 (memory:179-206). Q25 (INDEX schema) and Q27 (story-doc template) define the column/front-matter contracts this skill consumes. DO NOT re-derive — Q18's eight sub-decisions are the authoritative spec.

---

## 1. Source of truth (Q18.1)

Inputs, in priority order:

| Source | Path | Fields consumed |
|---|---|---|
| Story docs | `docs/product/flows/<domain>/*.md` (front-matter) | `status`, `parent_issue`, `children.*`, `figma`, `sandbox_url`, `staging_url`, `real_app_url`, `qa_status`, `user_docs_url`, `flow_id` |
| Master inventory | `docs/product/master-flow-inventory.md` | Canonical section order + canonical flow titles (foreign-key registry — never trust story-doc title) |
| Domain journeys | `docs/product/journeys/<domain>.md` (front-matter) | `milestone:` field → section-header link |
| Linear | batched `list_issues({labels: ["domain:<slug>"]})` per domain | Eng + Design state (state.type) |
| Plugin config | `.flow/config.json` | `<PROJECT_NAME>` placeholder; `linear_project_id` for milestone URL construction |

`master-flow-inventory.md` is the foreign-key registry. When the inventory title diverges from a story-doc title, prefer inventory — fix the story doc separately.

---

## 2. Parser mechanism (Q18.2)

Column-header-signature-based table parser. Regex match a row matching `| ID | Flow | Status | Story | Parent | Eng | Design | QA | Docs | Figma | Live |` (whitespace-tolerant). Identify table boundaries:

1. Header row (column-header signature).
2. Separator row (the `|---|---|...` line).
3. Contiguous data rows.
4. Terminator: blank line OR `##` heading.

Replace ONLY data rows. Preserve section headers, status note paragraphs, footnotes, and intro prose verbatim. Update the `(N sub-flows)` parenthetical in the immediately-preceding `## DOMAIN` section header (table-derived count, not free-text).

**Anti-pattern explicitly avoided:** regenerating the entire file from scratch. That would clobber hand-curated content (e.g., the "TEAM-04 status note" at INDEX.md:62).

---

## 3. Per-column derivation (Q18.3)

11 columns: 2 text + 1 taxonomy-string + 4 link + 4 emoji.

| # | Column | Type | Derivation |
|---|---|---|---|
| 1 | ID | text | `flow_id` cross-validated against master-inventory row ID |
| 2 | Flow | text | master-inventory row's title (canonical — never trust story-doc title) |
| 3 | Status | taxonomy-string | front-matter `status:` verbatim |
| 4 | Story | link | `[doc](./<domain>/<flow-id>.md)` relative path; missing → hourglass marker |
| 5 | Parent | link | `[BC-XXXX](https://linear.app/<workspace>/issue/BC-XXXX)` from front-matter `parent_issue` + `.flow/config.json` workspace; `TBD` → literal `TBD` |
| 6 | Eng | emoji | Linear batched `list_issues` → match `children.engineering` BC; `state.type=="completed"` → check mark; `started` → in-progress marker; `unstarted`/`backlog` → hourglass; `canceled` or `blocked` label → X marker; missing/`TBD` → em-dash |
| 7 | Design | emoji | Same Linear batch + same mapping; matched by `children.design` BC |
| 8 | QA | emoji | front-matter `qa_status:`; `signed-off` → check; `rework-needed` → in-progress; `not-tested` → hourglass; `blocked` → X; missing → em-dash |
| 9 | Docs | emoji | front-matter `user_docs_url:`; non-TBD path → check; `TBD` → hourglass; explicit `blocked` → X; missing → em-dash |
| 10 | Figma | link | non-TBD URL → `[frame](<figma-url>)`; literal `TBD` → render `TBD` |
| 11 | Live | link | URL fallback chain `sandbox_url` -> `staging_url` -> `real_app_url`; first non-`TBD` → `[<path>](<path>)`; all three `TBD` → literal `TBD` |

The exact emoji glyphs are defined in Q25's legend (see `master-flow-inventory.md` status-block reference). This skill emits whatever glyph the legend specifies; the spec above describes the **mapping**, not the literal glyph.

---

## 4. Section header policy (Q18.4)

Two-mode dispatch + soft-warning:

- **Refresh-rows-only** when the `## <DOMAIN>` section EXISTS. Preserves header text verbatim except the parenthetical sub-flow count. Replaces table data rows.
- **Initial-create** when the `## <DOMAIN>` section is MISSING. Writes a fresh section using the Q25 mod 1 schema: `## <DOMAIN> --- <Display name> --- [journey-link](../journeys/<domain>.md) --- [milestone-link](<linear-url>) --- (<N> sub-flows)`.
- **Legacy sections preserved as-is.** Does NOT auto-upgrade headers that are missing Q25 mod 1's emoji-prefixed journey/milestone links.

**Post-regen soft-warning summary.** Detect by substring-match for the emoji-prefixed journey-link AND milestone-link markers in each section header. Missing → emit a warning to stdout listing each section that doesn't match:

```
INDEX.md sections not matching Q25 mod 1 schema (consider upgrading):
  - QUO --- Quote Building (missing journey link, missing milestone link)
  - ...
```

A `--force-upgrade-headers` flag is parked for v1.1.

---

## 5. Front-matter regen (Q18.5)

Add or refresh:

- `generated_at: <ISO-8601 datetime>` (current UTC instant)
- `generated_by: flow-regen-index@<version>` (read version from `.claude-plugin/plugin.json`)
- Flip `generated: true` if currently `false`

Preserve `last_reviewed:` — regen is mechanical, not a review event.

---

## 6. `<PROJECT_NAME>` placeholder + PROJECT-INTENT reference (Q18.6)

Substitute `<PROJECT_NAME>` from `.flow/config.json` `linear_project_name`. Ensure the Q25 mod 2 PROJECT-INTENT reference paragraph exists in the file header:

- Present → preserve verbatim.
- Missing (legacy file) → one-time add a single sentence: `> See [PROJECT-INTENT.md](./intent.md) for the product intent that anchors every flow in this index.`

Preserve on subsequent regens.

---

## 7. Failure recovery (Q18.7)

Per-flow skip + HTML-comment marker so the gap is visible in `git diff` on next inspection:

```html
<!-- regen skipped <FLOW-ID>: <error> -->
```

Linear-fetch transient failures: retry once with 2s backoff (Q13.5 pattern). On persistent fail, emit `?`-placeholder emojis for the Eng/Design columns and append a footnote:

```html
<!-- regen: linear lookup failed for domain <X>; rerun to refresh -->
```

Do NOT abort the whole regen for a single bad doc.

---

## 8. Idempotency / no-op detection (Q18.8)

Diff-aware. Compute the would-be-output in memory, diff against the current `INDEX.md` excluding the `generated_at` field. If the only diff would be the timestamp, print:

```
INDEX.md unchanged; skipping write to avoid timestamp churn.
```

Exit cleanly without writing. This avoids the "every regen produces a one-line timestamp diff" PR-noise problem and makes pre-commit-hook usage practical (parking lot).

0 synchronous user-confirmation gates — filesystem-write pattern; git review is the implicit gate.

---

## Worked example

Brand Hub mid-retrofit, 5 domains scaffolded, story docs landed for 3:

1. Skill reads `.flow/config.json` -> `linear_project_name="Brand Hub"`, `linear_project_id=<uuid>`.
2. Walks `docs/product/flows/<domain>/*.md` -> 18 story docs across 3 domains.
3. Reads `master-flow-inventory.md` -> 5 domains, 31 flows total. 13 flows have no story doc -> rendered as hourglass markers in Story column.
4. Batched `list_issues({labels: ["domain:auth"]})`, `{labels: ["domain:tenancy"]}`, `{labels: ["domain:reports"]}` -> ~14s wall.
5. Computes diff against current INDEX.md -> 18 rows changed, 13 unchanged (still hourglass placeholders).
6. Writes new file; outputs summary `flow-regen-index: 3 sections refreshed, 18 rows updated, 13 placeholder rows preserved, 0 sections missing schema upgrade.`

If a second run fires within seconds with no story-doc changes, step 5 detects no diff except `generated_at` and exits with the no-op message.

---

## See also

- `docs/design-rationale/project_fda_plugin_interview.md` Q18 — canonical 8-sub-decision spec.
- `docs/design-rationale/project_fda_plugin_interview.md` Q25 — INDEX.md schema (11-column header).
- `docs/design-rationale/project_fda_plugin_interview.md` Q27 — story-doc front-matter schema this skill consumes.
- `skills/flow-preflight/SKILL.md` — preceding sub-skill; emits the structured preamble this skill's caller passes through.
- `skills/_shared/linear-writeback-pattern.md` — not consumed by Q18 directly (this skill is read + filesystem-only) but consumed by Q13/Q15/Q16 siblings.
