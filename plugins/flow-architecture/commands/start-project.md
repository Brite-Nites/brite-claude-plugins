---
description: Greenfield Flow-Driven Architecture orchestrator — 9 phases / 4 gates / hybrid control flow per Q37 lock
---

<!-- eval-waiver: Nine-phase, four-gate greenfield orchestrator with hybrid control flow: preflight, office-hours, inventory interview, a per-domain flow-linear-scaffold inner loop, doc-author, journey-author, persona-author, index-regen; every artifact is AI-authored and gated by AskUserQuestion, with no separable deterministic artifact in the command body to fixture (all Linear writes are dispatched to flow-linear-scaffold). -->

# /flow:start-project

Greenfield UI-bearing FDA build orchestrator. Runs **9 phases / 4 user-confirmation gates** with **hybrid control flow** per Q37 lock (`plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:682`): Phase 4 is a per-domain inner loop preserving Q13.5 atomic recovery; Phases 5+6+7 are globally batched activating Q15.2 + Q16.2 internal parallelism + the BC-14018 per-persona fan-out. Wall ≈ 22–70 min on Brand Hub-shape projects depending on domain count.

> **Scope:** UI-bearing builds only (CDR-023 partition). Non-UI-bearing work uses CDR-014's Phase Pattern with `/workflows:fix-milestone --migrate ...`, not FDA. `flow-preflight` performs upstream mode classification — `/flow:start-project` runs only when mode resolves to `greenfield`.

> **DO NOT re-derive** the phase sequence, gate positions, L-review routing, or per-phase failure matrix below. All seven sub-decisions are locked at memory:682+ with a refinement audit trail at memory:698. Re-litigation already resolved at lock time.

## Architecture overview

```
  /flow:start-project (greenfield) — 9 phases / 4 gates
  ═══════════════════════════════════════════════════════════════════

   ┌─ Phase 1 ─┐ G1 ┌─ Phase 2 ─┐ G2 ┌─ Phase 3 ─┐ G3 ┌─ Phase 4 ─┐
   │ preflight │───►│  office-  │───►│ inventory │───►│  linear-  │
   │ bootstrap │    │   hours   │    │ interview │    │  scaffold │
   │   (Q12)   │    │   (Q42)   │    │   (Q19)   │    │   (Q13)   │
   └───────────┘    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
                          ↓ L1 review      ↓ L2 review      ↓ L3 review
                          → intent.md      → journey stash  → parent issue
                          (CEO+Des+Eng+DX  (CEO+Des per     (5 disciplines
                          parallel)         domain)          per sub-flow)

   ┌─ Phase 4 ─┐ G4 ┌─ Phase 5 ─┐    ┌─ Phase 6 ─┐    ┌─ Phase 7 ─┐
   │  linear-  │───►│  doc-     │───►│  journey- │───►│  persona- │
   │  scaffold │    │  author   │    │   author  │    │   author  │
   │   (Q13)   │    │   (Q15)   │    │   (Q16)   │    │ (BC-14018)│
   └───────────┘    └───────────┘    └───────────┘    └─────┬─────┘
   per-domain       globally         globally         globally
   inner loop       batched          batched          batched
   (preserves       (Q15.2 internal  (Q16.2 internal  (1 agent per
   Q13.5 atomic     parallelism)     parallelism)     persona slug)
   recovery)                                                ↓
                    ┌─ Phase 8 ─┐    ┌─ Phase 9 ─┐
                    │  regen-   │───►│ complete  │
                    │   index   │    │           │
                    │   (Q18)   │    │           │
                    └───────────┘    └───────────┘
                                     status: completed
                                     written to breadcrumb
```

Greenfield SKIPS `flow-legacy-cross-reference` (Q14) — that's retrofit-only. Retrofit shape is 9 phases / 5 gates and lives in `/flow:retrofit-project` (BC-6963 territory).

> **Diagram note on G4 placement.** Both G3 and G4 are `(3→4)` transition gates per Q37 sub-decision 3 lock (memory:688): "G3 (3→4): master-flow-inventory.md content; G4 (3→4 — fires alongside G3 OR after G3 if user pauses, whichever): pre-scaffold batch preview". G4 gates **entry into Phase 4 execution** (Q13 lock at memory:80, sub-decision 4 "pre-scaffold preview"), NOT the Phase-4-to-Phase-5 boundary. The ASCII diagram above places G4 visually between the Phase-4 and Phase-5 boxes for layout reasons — the authoritative source is the textual gate definitions in this file (and the lock at memory:688), not the box positioning.

## Breadcrumb

The orchestrator writes phase progress to `docs/plans/.flow-phase-state.json` (Q31.4 lock — note the **leading dot** on the filename; NOT `.flow/phase-state.json`) after every phase completion. Writes go through `bash $CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh write <state-path> <input-path>` (BC-6956 shipped; BC-9027 file-arg refactor) — atomic-rename via mktemp + python3 json.dump + parse-verify + content-match per Q31.5 lock. Never write the breadcrumb file directly with a heredoc.

Breadcrumb shape (per Q31.4 — the `last_updated` field name is load-bearing: `scripts/flow-resume-breadcrumb.sh read` keys on it for stale detection, so writing `updated_at` would silently skip staleness checks):

```json
{
  "version": "1",
  "mode": "greenfield",
  "linear_project_id": "<uuid from .flow/config.json>",
  "linear_project_name": "<string from .flow/config.json>",
  "linear_team_key": "<e.g., BC>",
  "run_started_at": "<ISO-8601; set once at Phase 1 entry; consumed by Q29.1 index-complete gate>",
  "current_phase": "1|2|3|4|5|6|7|8|9",
  "completed_phases": ["1", "2", ...],
  "domains": [
    {
      "slug": "<domain-slug>",
      "scaffold_state": "pending|in_progress|completed|failed",
      "failure_reason": null,
      "parent_issue_ids": []
    }
  ],
  "status": "in_flight",
  "last_updated": "<ISO-8601 refreshed each write>"
}
```

`status` transitions: `in_flight` (set at Phase 1 entry) → `completed` (Phase 9 terminator) OR `abandoned` (user halt at any gate). Phase 4's per-domain inner loop maintains `domains[]` so resume can pick up at the next pending domain.

## Resume contract

`flow-preflight` is the entry — every orchestrator dispatches through it. When preflight detects an in-flight non-stale breadcrumb, it returns `MODE=resume` and the orchestrator dispatches at `current_phase`:

| Resume phase | Behavior |
|---|---|
| 1 | re-run Phase 1 (preflight + bootstrap is idempotent). |
| 2 | re-emit G1 confirmation summary from `.flow/config.json` then continue at Phase 2. |
| 3 | re-emit G2 summary from `docs/product/intent.md` then continue at Phase 3. |
| 4 | per-domain replay — iterate `breadcrumb.domains[]`; skip `scaffold_state == "completed"`; resume at first non-completed. L3 review state not persisted (re-runs per parking lot #31 v1; ~2-5 min per sub-flow). |
| 5 | re-run whole Phase 5 (~30-60s with Q15.2 internal parallelism). Q15's skip-if-exists per Q15.3 keeps already-written story docs from being clobbered without `--force`. |
| 6 | re-run whole Phase 6 (~60-90s with Q16.2 internal parallelism). L2 review state not persisted; re-runs (~2-5 min per domain) per parking lot #31 v1. Q16's skip-if-exists per Q16.3 likewise gates journey-doc clobber. |
| 7 | re-run whole Phase 7 (persona author, ~90s per BC-14018 fan-out). The skill's skip-if-exists keeps already-written persona docs from being clobbered without `--force`. |
| 8 | re-run whole Phase 8. INDEX regeneration is idempotent. |
| 9 | only reached for a mid-Phase-9 in_flight crash (after summary render, before the final breadcrumb write); re-emit the completion summary, then write `status: completed`. A breadcrumb already at `status: completed` is stale per Q31.3 and flow-preflight offers discard instead of resuming here. |

Stale breadcrumb handling (>7 days, or `status: completed | abandoned`, or malformed) lives inside `flow-preflight` Section 3.1 and prompts the user via `AskUserQuestion` to discard / force-resume / cancel. Orchestrator does not re-implement that policy.

## L-review routing (Q37 sub-decision 4 + Q54)

| Level | Phase | Where it fires | Output target |
|---|---|---|---|
| **L1 review** | 2 | inside `/flow:office-hours` (Q42) — 4 reviewers (CEO + Design + Engineering + Developer-experience) parallel | `docs/product/intent.md` `## L1 review summary` section |
| **L2 review** | 3 | inside `flow-inventory-interview` per domain — CEO + Design parallel | in-memory `state.l2_review_<domain>` stash; consumed by Phase 6 to populate journey doc `## L2 review summary` per Q26 mod 2 / Q16.7 optional read path |
| **L3 review** | 4 | inside `flow-linear-scaffold` per sub-flow **BEFORE** the G4 preview gate — all 5 disciplines (Story + Eng + Design + QA + Docs) parallel | Linear parent issue `## L3 review summary` section per Q23 mod 2; headlines visible in G4 preview |
| L4 review | n/a | JIT during `/flow:session-start` Step 5 — not orchestrator-driven |  — |

L-review state is **in-memory only** during single invocation per parking lot #31 v1 acceptance. On crash-resume, L2 + L3 re-run when their phase re-runs.

## Session state object

Phases flow via a single session-scoped state object. No re-fetching from filesystem or Linear between phases unless explicitly re-probed.

```
{
  "mode":              "greenfield",
  "linear_project_id": "<uuid>",
  "linear_project_name":"<string>",
  "linear_team_key":   "<e.g., BC>",
  "repo_root":         "<absolute path>",
  "run_started_at":    "<ISO-8601>",
  "current_phase":     "1..9",
  "completed_phases":  [...],
  "preamble":          { ...10 KEY=VALUE fields from flow-context-load.sh },
  "intent_path":       "docs/product/intent.md",
  "inventory_path":    "docs/product/master-flow-inventory.md",
  "inventory":         { "domains": [ { "slug", "display_name", "sub_flows": [...] } ] },
  "domains":           [ { "slug", "scaffold_state", "failure_reason", "parent_issue_ids": [...] } ],
  "l1_review":         { "summary_written_at": "<ISO-8601 | null>" },
  "l2_review_<slug>":  "<in-memory blob, one entry per domain slug>",
  "l3_review":         { "<sub-flow-id>": "<in-memory blob>" },
  "ship_artifacts":    { "story_docs": [...], "journey_docs": [...], "index_path": "..." },
  "status":            "in_flight"
}
```

This object is **session-scoped**. The breadcrumb is the persistent projection — `current_phase`, `completed_phases[]`, `domains[]`, `run_started_at`, `status`. L-review state is not breadcrumb-persisted (parking lot #31 v1).

## The 4 user gates

- **G1 (1→2):** bootstrap completed; `.flow/config.json` written + verified.
- **G2 (2→3):** PROJECT-INTENT.md content review (post-office-hours, L1-vetted).
- **G3 (3→4):** `master-flow-inventory.md` content review (post-inventory-interview, L2 stashed per domain).
- **G4 (3→4):** pre-scaffold batch preview consolidating ALL domains' planned scaffolds — NOT N separate gates. L3 reviews per sub-flow already populated at this point.

Phases 5/6/7/8 run without further orchestrator gates per Q15.6 / Q16.6 / BC-14018 / Q18.8 lock 0 sync gates each.

## Per-phase failure matrix (Q37 sub-decision 6 — verbatim from memory:694)

| Phase | Failure semantics |
|---|---|
| 1 | fail-closed per Q36.5. No partial `.flow/config.json` on disk — atomic-rename guarantees absent-or-complete. |
| 2 | pause at G2 + retry. User can re-run office-hours; intent.md gets re-written via Q41 template + Q42 L1-review write. |
| 3 | Q19.6 interview-loop max-retry. Inventory append is hard-rejected on duplicate per Q20.4. |
| 4 | per-domain Q13.5 sub-flow-atomic recovery — failure isolated to one domain. Orchestrator pauses inner loop for user adjudication (`AskUserQuestion`: retry / skip-domain / abort). On user choice "retry" or "skip", inner loop resumes with the next pending domain in `breadcrumb.domains[]`. |
| 5 | log + continue per Q15.5. Operating at global batch scope — partial Q15 failures surface in batch summary. Orchestrator does NOT roll back since outputs are filesystem writes reviewable via `git diff` + `verify-docs.sh`. |
| 6 | log + continue per Q16.5 (same shape as Phase 5). |
| 7 | log + continue (BC-14018, same shape as Phase 5/6). A persona whose agent returns the `PERSONA-DOC-AUTHOR-ERROR` sentinel (or whose write fails) surfaces in the batch summary; user re-runs with `--force`. One failed persona never aborts the batch. |
| 8 | Q18.7 log + continue + skip-row marker. INDEX renders a "regen-failed: <reason>" row instead of clobbering with a partial INDEX. |
| 9 | n/a — terminator. |
| user halt at any gate | breadcrumb `status: abandoned`; future `/flow:start-project` invocation detects abandoned + offers discard per Q31.3 stale-breadcrumb policy. (Q31.1 lock at memory:313 reserves the `reason` field for `overrides[]` entries — Q29.5 hard-gate decisions, not user-cancel attribution; do not add a top-level `reason` field without a Q31 amendment + audit trail.) |

---

## Phase 1: preflight + bootstrap

**Sub-skill:** `flow-preflight` (Q12 + Q36 embedded 7-step bootstrap; BC-6957 shipped at `plugins/flow-architecture/skills/flow-preflight/SKILL.md`).

**Pre-flow-preflight setup:** the orchestrator owns the `LINEAR_ISSUE_COUNT` env-var per flow-preflight Section 6.4 ownership note. Before dispatching the skill:

1. Call the Linear MCP `mcp__plugin_workflows_linear-server__list_issues` with `{project: <candidate project_id from .flow/config.json>, limit: 10}`.
2. Count the returned items as an integer (0–10).
3. `export LINEAR_ISSUE_COUNT=<integer>` so flow-preflight Section 6.4 picks it up.

Treat the captured integer as data only — never interpolate any Linear-derived field (issue titles, project name, descriptions) into a shell expression, `bash -c`, `eval`, or unquoted `$(...)`. Only the integer count crosses into env. The MCP call is the trust boundary; values from the MCP response stay inside the LLM context, never inside a shell pipeline.

The `limit: 10` cap aligns with Q36.3 step-4's threshold-IS-the-cap semantics — a returned count of exactly 10 means "≥ 10" (no pagination needed). If the candidate project isn't yet known (first-ever run with no `.flow/config.json`), pass `LINEAR_ISSUE_COUNT=` (empty) and flow-preflight degrades to `greenfield` by default per Section 6.4.

**Run:**

```bash
# Dispatch flow-preflight inline (skill is disable-model-invocation: true,
# user-invocable: false — orchestrators call directly).
```

flow-preflight runs its 5 environment checks (Section 1), FDA-artifact discovery (Section 2), mode classification (Section 3), Linear scope confirmation (Section 4), preamble emission (Section 5), and on first-run the Q36 7-step bootstrap (Section 6).

**Mode guard:** if flow-preflight emits `MODE != greenfield`, surface error redirect per Q47 sub-decision 3 and STOP:

- `MODE=retrofit` → `"Project has legacy work signal. Use /flow:retrofit-project to retrofit FDA shape, then /flow:add-* for incremental additions."`
- `MODE=incremental-add` → `"Project already has FDA shape. Use /flow:add-domain (new domain) or /flow:add-sub-flow (new flow under existing domain)."`
- `MODE=resume` → orchestrator dispatches at breadcrumb's `current_phase` per the Resume contract section above.

**Capture from preamble** (10 KEY=VALUE fields per flow-preflight Section 5):

- `LINEAR_PROJECT_ID`, `LINEAR_PROJECT_NAME`, `LINEAR_TEAM_KEY` (last derived from `.flow/config.json`)
- `REPO_ROOT`
- `INTENT_EXISTS`, `INVENTORY_EXISTS`, `FLOWS_DIR_EXISTS`, `BREADCRUMB_EXISTS` (all `no` for fresh greenfield)
- `GH_AUTH`, `LINEAR_MCP` (orchestrator already probed Linear in flow-preflight Section 1.1)

**Templates scaffold (BC-11029, Q58):** after `.flow/config.json` is written and the 10 fields are captured, but BEFORE the Phase 1 terminal breadcrumb write, the orchestrator copies the project-side verify-docs.sh ecosystem from `$CLAUDE_PLUGIN_ROOT/templates/scripts/` into the consumer project's `scripts/` directory **and the canonical doc templates** (`domain-journey.md`, `job-story.md`, `persona.md`) from `$CLAUDE_PLUGIN_ROOT/templates/docs/templates/` into the consumer's `docs/templates/` directory, then substitutes the 4 placeholders via a python3-built sed script file. Q58 locks the canonical source + substitution flow; seeding the doc templates is what gives `story-doc-author` / `journey-doc-author` / `persona-doc-author` a real `template_path` to read (their fallback-to-drifted-prose failure mode otherwise).

1. **Resolve LINEAR_ORG_SLUG.** Call `mcp__plugin_workflows_linear-server__get_project({id: <LINEAR_PROJECT_ID>})` and parse `LINEAR_ORG_SLUG` from the `url` field (`https://linear.app/<slug>/project/...`). The MCP response is the trust boundary — Linear-derived strings (`LINEAR_PROJECT_NAME`, `LINEAR_ORG_SLUG`) MUST NOT cross into shell as `$VAR` inside a double-quoted argument (a backtick or `$(...)` in a malicious project name would execute on the developer's machine at sed-time). Step 4 below builds the sed script via a single-quoted python heredoc, mirroring the protection pattern the breadcrumb write uses below.

2. **Build the 13 template-source → target-path parallel arrays** (bash 3.2 compatible — no associative arrays):

   ```bash
   SRC_PATHS=(
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/verify-docs.sh"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/regenerate-flow-index.sh"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/precommit-flow-index.sh"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/regenerate-flow-index.mts"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/verify-linear-references.mts"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/normalize-fda-frontmatter.mjs"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/lib/fda-title.mts"
     "$CLAUDE_PLUGIN_ROOT/templates/scripts/lib/linear-graphql.mts"
     "$CLAUDE_PLUGIN_ROOT/templates/.flow/scaffold-log/SCHEMA.md"
     "$CLAUDE_PLUGIN_ROOT/templates/README.md"
     "$CLAUDE_PLUGIN_ROOT/templates/docs/templates/domain-journey.md"
     "$CLAUDE_PLUGIN_ROOT/templates/docs/templates/job-story.md"
     "$CLAUDE_PLUGIN_ROOT/templates/docs/templates/persona.md"
   )
   TARGET_PATHS=(
     "$REPO_ROOT/scripts/verify-docs.sh"
     "$REPO_ROOT/scripts/regenerate-flow-index.sh"
     "$REPO_ROOT/scripts/precommit-flow-index.sh"
     "$REPO_ROOT/scripts/regenerate-flow-index.mts"
     "$REPO_ROOT/scripts/verify-linear-references.mts"
     "$REPO_ROOT/scripts/normalize-fda-frontmatter.mjs"
     "$REPO_ROOT/scripts/lib/fda-title.mts"
     "$REPO_ROOT/scripts/lib/linear-graphql.mts"
     "$REPO_ROOT/.flow/scaffold-log/SCHEMA.md"
     "$REPO_ROOT/scripts/FDA-TEMPLATES-README.md"
     "$REPO_ROOT/docs/templates/domain-journey.md"
     "$REPO_ROOT/docs/templates/job-story.md"
     "$REPO_ROOT/docs/templates/persona.md"
   )
   ```

   The `.flow/config.json` template is schema-reference only and is NOT copied — `flow-preflight` Section 4.4 owns the runtime `.flow/config.json` write per Q12.4 lock. That schema-reference file stays plugin-side; only the 13 above land in the consumer project. (`precommit-flow-index.sh` (BC-16783) — like the `regenerate-flow-index.sh` wrapper — carries no placeholders, so the sed pass no-ops over it. The three `docs/templates/*.md` entries carry no `<LINEAR_*>`/`<PROJECT_NAME>`/`<EXPECTED_FDA_ISSUE_COUNT>` placeholders at all — the journey template's former `linear_project_id: <LINEAR_PROJECT_ID>` line, once the sed pass's one substituted token, was dropped per ADR-033 (project-id state lives in `.flow/config.json`, read at regen time) — so the sed pass leaves every authoring placeholder — `<DOMAIN>`, `<DOMAIN-NN>`, `<role>`, `<slug>` — intact for the doc-author agents to fill.)

3. **Idempotency check** (default behavior — no `--overwrite-scripts`): probe each of the 13 target paths via `test -f`. If ANY exists, surface the conflict list and HALT Phase 1. Recovery semantics differ from Q36.5's atomic-rename (which guarantees absent-or-complete): templates-scaffold's per-file loop CAN leave partial state on crash. That partial state is recoverable but NOT atomic — the next re-run halts on this idempotency check before any further mutation, surfacing the conflict to the operator. See § Failure semantics below.

   ```bash
   if [ "${FLOW_OVERWRITE_SCRIPTS:-false}" != "true" ]; then
     conflicts=()
     for i in "${!TARGET_PATHS[@]}"; do
       if [ -f "${TARGET_PATHS[$i]}" ]; then
         conflicts+=("${TARGET_PATHS[$i]}")
       fi
     done
     if [ "${#conflicts[@]}" -gt 0 ]; then
       printf 'Templates already present in project (paths listed) — re-run with --overwrite-scripts to replace.\n' >&2
       printf '%s\n' "${conflicts[@]}" >&2
       # HALT Phase 1 — no breadcrumb write, no further mutation
     fi
   fi
   ```

4. **Copy + substitute + chmod** (python3-built sed script + per-file loop): copy templates into target paths, then run a single sed pass per target using a sed script file built by python3 with properly-escaped values. Placeholder mappings:

   | Placeholder | Value source |
   |---|---|
   | `<LINEAR_PROJECT_ID>` | captured `LINEAR_PROJECT_ID` |
   | `<LINEAR_ORG_SLUG>` | parsed from `get_project` `url` (step 1) |
   | `<PROJECT_NAME>` | captured `LINEAR_PROJECT_NAME` |
   | `<EXPECTED_FDA_ISSUE_COUNT>` | literal `0` (count gate disabled by default; consumer opts in by editing) |

   Substitution recipe — uses the single-quoted python heredoc + `mktemp` sed-script-file pattern, mirroring the BC-9027 breadcrumb-write protection (same trust-boundary semantics: Linear-derived strings stay inside the python source as input, never interpolated into shell):

   ```bash
   SED_SCRIPT="$(mktemp -t flow-sed.XXXXXX)"
   LINEAR_PROJECT_ID_IN="$LINEAR_PROJECT_ID" \
   LINEAR_ORG_SLUG_IN="$LINEAR_ORG_SLUG" \
   PROJECT_NAME_IN="$LINEAR_PROJECT_NAME" \
   EXPECTED_COUNT_IN="0" \
     python3 > "$SED_SCRIPT" <<'PY'
   import os
   def esc(s):
       # sed replacement-string metacharacters: \, &, the chosen delimiter |
       return s.replace("\\", "\\\\").replace("|", "\\|").replace("&", "\\&").replace("\n", "\\n")
   for ph, env in [
       ("<LINEAR_PROJECT_ID>", "LINEAR_PROJECT_ID_IN"),
       ("<LINEAR_ORG_SLUG>", "LINEAR_ORG_SLUG_IN"),
       ("<PROJECT_NAME>", "PROJECT_NAME_IN"),
       ("<EXPECTED_FDA_ISSUE_COUNT>", "EXPECTED_COUNT_IN"),
   ]:
       value = os.environ.get(env, "")
       print(f"s|{ph}|{esc(value)}|g")
   PY

   # Copy template files into target paths (mkdir -p ensures lib/ subdirs exist).
   for idx in "${!SRC_PATHS[@]}"; do
     mkdir -p "$(dirname "${TARGET_PATHS[$idx]}")"
     cp "${SRC_PATHS[$idx]}" "${TARGET_PATHS[$idx]}"
   done

   # Cross-platform sed -i: -i.bak works on both BSD (macOS default) and
   # GNU sed; the .bak file is removed after the substitution succeeds.
   for idx in "${!TARGET_PATHS[@]}"; do
     sed -i.bak -f "$SED_SCRIPT" "${TARGET_PATHS[$idx]}"
     rm -f "${TARGET_PATHS[$idx]}.bak"
   done
   rm -f "$SED_SCRIPT"

   # chmod +x the three .sh files. The .mjs + .mts files are invoked via
   # npx tsx and don't require the executable bit.
   chmod +x "$REPO_ROOT/scripts/verify-docs.sh"
   chmod +x "$REPO_ROOT/scripts/regenerate-flow-index.sh"
   chmod +x "$REPO_ROOT/scripts/precommit-flow-index.sh"
   ```

   Trust boundary discipline: Linear-derived strings enter the python source via env-vars (passed as discrete process-environment entries, never spliced into a shell expression), get escaped for sed-replacement-string metacharacters (`\`, `&`, `|`), then land in the sed script file as literal-text replacements. No path from MCP response → shell command line; no command-substitution surface.

5. **Emit confirmation line:** `"Templates scaffolded: 13 files written under scripts/ + docs/templates/ + .flow/scaffold-log/. Required dev dependencies: gray-matter + tsx (add to package.json if absent). Run \`bash scripts/verify-docs.sh --no-linear\` to verify, and \`npm install\` (or \`npm run prepare\`) to activate the flow-INDEX pre-commit hook."`

**Pre-commit hook wiring (BC-16783, Q60).** After the templates copy succeeds, wire the flow-INDEX auto-regen into the consumer's git pre-commit hook so `docs/product/flows/INDEX.md` self-corrects at commit time instead of drifting until CI catches it. This step is **best-effort and fail-open — a failure here NEVER aborts Phase 1** (the copied helper + CI's `verify-docs` drift gate still stand). It respects the consumer-owned-pre-commit split (Q29.7): **never clobber a hand-authored hook** — inject one line when a hook exists, create the first hook only when none does.

   ```bash
   HOOK="$REPO_ROOT/scripts/pre-commit.sh"
   SOURCE_LINE='bash scripts/precommit-flow-index.sh || true'
   if [ -f "$HOOK" ]; then
     # Existing consumer hook — inject ONE idempotent line; never rewrite the file.
     if ! grep -qF 'scripts/precommit-flow-index.sh' "$HOOK"; then
       printf '\n# Flow INDEX auto-regen (BC-16783) — keep docs/product/flows/INDEX.md in sync\n%s\n' "$SOURCE_LINE" >> "$HOOK"
     fi
   else
     # No hook yet (the common case) — create the consumer's FIRST pre-commit.sh
     # sourcing the helper. Creation-when-absent, NOT clobbering (Q29.7-safe).
     {
       printf '#!/usr/bin/env bash\n'
       printf '# Pre-commit hook (created by /flow scaffold, BC-16783). Consumer-owned — edit freely.\n'
       printf 'set -euo pipefail\n\n'
       printf '# Flow INDEX auto-regen — keep docs/product/flows/INDEX.md in sync\n'
       printf '%s\n' "$SOURCE_LINE"
     } > "$HOOK"
     chmod +x "$HOOK"
   fi

   # Install the tracked hook on `npm install` via a `prepare` script (fleet-command
   # precedent). Add it ONLY when package.json exists and has no `prepare` already —
   # never overwrite a consumer's existing prepare (husky etc.); document the one-liner instead.
   if [ -f "$REPO_ROOT/package.json" ]; then
     PKG="$REPO_ROOT/package.json" python3 <<'PY'
   import json, os
   p = os.environ["PKG"]
   with open(p) as f:
       data = json.load(f)
   scripts = data.setdefault("scripts", {})
   if "prepare" not in scripts:
       scripts["prepare"] = "hp=$(git rev-parse --git-path hooks/pre-commit 2>/dev/null) || exit 0; [ -n \"$hp\" ] || exit 0; if [ -e \"$hp\" ] && ! grep -q precommit-flow-index \"$hp\" 2>/dev/null; then echo 'flow-index: existing pre-commit hook — not overwriting'; exit 0; fi; mkdir -p \"$(dirname \"$hp\")\" && cp scripts/pre-commit.sh \"$hp\" && chmod +x \"$hp\" || true"
       with open(p, "w") as f:
           json.dump(data, f, indent=2)
           f.write("\n")
       print("added prepare script (installs scripts/pre-commit.sh on npm install)")
   else:
       print("package.json already has a prepare script — left as-is; wire scripts/pre-commit.sh manually (see FDA-TEMPLATES-README.md)")
   PY
   fi
   ```

   The hook activates once the developer runs `npm install` (or `npm run prepare`). When no Node/`package.json` is present, or a `prepare` already exists, the helper file still ships — the consumer wires the one-liner by hand per `scripts/FDA-TEMPLATES-README.md`. Either way the feature degrades to "no auto-regen, CI still gates," never to a broken commit.

**`--overwrite-scripts` flag.** Orchestrator-level flag; default off. When set, step 3's idempotency check is bypassed and step 4 runs unconditionally — every target path is overwritten with the freshly-substituted template. Use this when consumer's `scripts/verify-docs.sh` has fallen out of sync with the canonical template and the consumer wants the latest. Hand-edits in target files are LOST when this flag is set — there is no per-file diff prompt. Re-runs without the flag preserve existing copies.

**Failure semantics (templates scaffold):** any failure in steps 1-4 aborts Phase 1 before the terminal breadcrumb write. The 13-file `cp` + sed + chmod loop is NOT atomic — a crash between file 3 and file 4 leaves a partial filesystem state. This differs from Q36.5's atomic-rename invariant for `.flow/config.json` (absent-or-complete); templates-scaffold's recovery contract is fail-loud-on-next-run: the next re-run halts on the per-file `test -f` idempotency check before mutating anything further. The operator recovers by either `rm`-ing the partially-copied files OR passing `--overwrite-scripts` to replace them en masse. No silent partial state — every partial state surfaces at the next invocation's idempotency check.

**Initial breadcrumb write:** at end of Phase 1, write the breadcrumb with `run_started_at` (ISO-8601 now), `current_phase: 2`, `completed_phases: ["1"]`, `status: in_flight`, empty `domains: []`.

The helper script `flow-resume-breadcrumb.sh write <state-path> <input-path>` reads the full JSON document from `<input-path>` (per BC-6956 contract as amended by BC-9027; it does not take `--mode` / `--current-phase` / `--status` flags and no longer reads from stdin). Construct the JSON via python3 (stdlib only per Q32), redirect into a `mktemp` file, then call the helper with both paths:

```bash
BREADCRUMB_PATH="$REPO_ROOT/docs/plans/.flow-phase-state.json"
TMP_JSON="$(mktemp -t flow-breadcrumb.XXXXXX)"
python3 > "$TMP_JSON" <<'PY'
import json, sys, datetime
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump({
    "version": "1",
    "mode": "greenfield",
    "status": "in_flight",
    "run_started_at": now,
    "last_updated": now,
    "current_phase": "2",
    "completed_phases": ["1"],
    "domains": [],
}, sys.stdout)
PY
bash "$CLAUDE_PLUGIN_ROOT/scripts/flow-resume-breadcrumb.sh" write "$BREADCRUMB_PATH" "$TMP_JSON"
rm -f "$TMP_JSON"
```

The `<<'PY'` heredoc is single-quoted so the inner python source is not subject to shell variable expansion — Linear-derived strings cannot land here as injection vectors. The breadcrumb path is passed as a discrete argument to the helper (never spliced into a `bash -c` string). The `mktemp` file intermediate is the BC-9027 fix: the previous pattern `python3 <<'PY' | bash $HELPER write ...` tripped the workflows security-hook classifier as a "piped download/execution" false-positive. Routing through `$TMP_JSON` keeps the helper-call as a plain argv invocation with no stdin pipe.

### Gate G1 (1→2)

`AskUserQuestion`:

> "Phase 1 complete. `.flow/config.json` written for Linear project `<LINEAR_PROJECT_NAME>` (team `<LINEAR_TEAM_KEY>`). Continue to Phase 2 (office-hours intent capture)?"

Options:

- **Continue to Phase 2** *(Recommended)*
- **Pause + resume later** — exits cleanly; breadcrumb retains `status: in_flight`; next `/flow:start-project` invocation resumes at Phase 2.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 1):** fail-closed per Q36.5. No partial `.flow/config.json`. Any failure inside flow-preflight surfaces verbatim with the remediation hint flow-preflight emitted.

---

## Phase 2: office hours

**Sub-skill / command:** `/flow:office-hours` (Q42 — pending; orchestrator references by name; pre-shipped sub-skill names locked in interview record at memory:682, Q37 sub-decision 1).

**Run:** dispatch `/flow:office-hours`. The command:

1. Captures the project mission, target users, problem, success criteria, out-of-scope, and constraints via guided interview per Q41 template (`docs/product/intent.md` skeleton at `handbook/about-handbook/style-guide/templates/project-intent.md`).
2. Fires the **L1 review** — 4 reviewers (CEO + Design + Engineering + Developer-experience) in parallel — and writes one-paragraph headlines into the `## L1 review summary` section of `intent.md`. The Q42 write uses Q31.5 atomic-rename per Q41 sub-decision 5.
3. Updates intent.md front-matter `l1_reviewed` to the current ISO-8601 timestamp.

**Output:** `docs/product/intent.md` exists; front-matter populated; all 7 required body sections present; `## L1 review summary` populated.

**Capture into state:** `state.intent_path`, `state.l1_review.summary_written_at`.

**Breadcrumb update:** `current_phase: 3`, `completed_phases: ["1", "2"]`.

### Gate G2 (2→3)

`AskUserQuestion`:

> "Phase 2 complete. `docs/product/intent.md` written + L1 multi-perspective review embedded. Review the intent doc before proceeding to inventory."

Options:

- **Continue to Phase 3** *(Recommended)* — intent looks right; proceed to inventory interview.
- **Re-run office-hours** — re-enter Phase 2; previous intent.md is preserved (`/flow:office-hours` skip-if-exists + `--force` semantics).
- **Pause + resume later** — exits cleanly; resumes at Phase 3 next run.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 2):** pause at G2 + retry. If `/flow:office-hours` fails mid-run (e.g., L1 reviewer dispatch error, file-write failure), surface error; user re-runs Phase 2.

---

## Phase 3: inventory

**Sub-skill:** `flow-inventory-interview` (Q19; not yet shipped — orchestrator references by name).

**Run:** dispatch `flow-inventory-interview`. The skill:

1. Reads `docs/product/intent.md` as Phase 0 priority filter per Q19 Phase 0 input contract (memory:208, Q19 lock).
2. Runs the Q19.6 interview-loop to enumerate domains + their sub-flows. Hard-rejects duplicate domain or sub-flow IDs per Q20.4.
3. Fires the **L2 review** per domain — CEO + Design parallel — and the orchestrator stashes each domain's L2 output as `state.l2_review_<domain-slug>` for Phase 6 hand-off (in-memory only per parking lot #31 v1; on crash-resume, Phase 6 re-runs L2 — ~2-5 min per domain).
4. Writes `docs/product/master-flow-inventory.md` via atomic-rename.

**Capture into state:** `state.inventory_path`, `state.inventory.domains[]`, `state.l2_review_<domain-slug>` per domain.

**Initialize `state.domains[]` from inventory:** for each domain in `state.inventory.domains[]`, append `{slug, scaffold_state: "pending", failure_reason: null, parent_issue_ids: []}` to `state.domains[]`. Persist to breadcrumb `domains[]` for Phase 4's per-domain resume support.

**Breadcrumb update:** `current_phase: 4`, `completed_phases: ["1", "2", "3"]`, `domains: [...]`.

### Gate G3 (3→4)

`AskUserQuestion`:

> "Phase 3 complete. `docs/product/master-flow-inventory.md` written + L2 reviews stashed per domain. Review inventory before scaffold preview."

Options:

- **Continue to G4 batch preview** *(Recommended)* — inventory looks right; proceed to Phase 4 scaffold preview consolidating all domains.
- **Edit inventory + re-run** — opens the inventory doc for hand-edit; user can then re-trigger Phase 3 via re-invocation (skip-if-exists + `--force` semantics in Q19).
- **Pause + resume later** — exits cleanly; resumes at Phase 4 next run.
- **Cancel session** — write `status: abandoned`; exit cleanly.

**Failure semantics (Phase 3):** Q19.6 interview-loop max-retry. Q20.4 duplicate-ID hard-reject surfaces user-visible error; orchestrator does not retry automatically.

---

## Phase 4: linear scaffold (per-domain inner loop)

**Sub-skill:** `flow-linear-scaffold` (Q13; not yet shipped — orchestrator references by name).

This is the **per-domain inner loop** — orchestrator iterates over `state.domains[]` and invokes `flow-linear-scaffold` one domain at a time. This preserves Q13.5's sub-flow-atomic failure recovery semantics + Q13.4's per-domain preview content (consolidated by orchestrator at G4 below).

**Per-domain footprint** (Q13 lock): 1 milestone + 1 parent per sub-flow + 5 children per sub-flow + chains + labels = `2 + 7N` writes per domain where N = sub-flow count.

### 4.1 Inner-loop iteration

For each domain in `state.domains[]` (in inventory order):

1. **Skip-if-completed:** if `breadcrumb.domains[<i>].scaffold_state == "completed"`, skip (resume support).
2. **L3 review fires INSIDE flow-linear-scaffold** per sub-flow per Q23 mod 2 — all 5 disciplines (Story + Eng + Design + QA + Docs) in parallel. Headlines populate the parent issue's `## L3 review summary` section **before** the G4 preview gate so the preview includes L3 headlines for human review.
3. **Per-domain preview content** computed deterministically from inventory + parent issue numbers — used in G4 consolidation below.
4. **Domain scaffold execution gated by G4:** the orchestrator does NOT execute Linear writes for this domain inside 4.1. Per-domain Q13.4 preview content is collected; **G4** (next subsection) consolidates ALL domains' previews into a single user-facing preview; only after G4 approval does the orchestrator execute Linear writes for all approved domains.

### 4.2 Aggregate previews + Gate G4 (3→4)

After the inner loop completes (all domains' previews collected, all L3 reviews fired + parent `## L3 review summary` populated), present **a single consolidated preview** via `AskUserQuestion`:

> "Phase 4 scaffold preview — ALL domains consolidated:
>
> - **Domain `<slug-1>` (`<N>` sub-flows):** `<2+7N>` Linear writes — `<headline summary>`. L3 review headlines: `<one-line per discipline>`.
> - **Domain `<slug-2>` (`<M>` sub-flows):** `<2+7M>` writes — `<headline summary>`. L3 headlines: ...
> - ...
>
> Total: `<sum>` writes across `<D>` domains. Apply all?"

Options:

- **Apply all** *(Recommended)* — execute Linear writes for every domain. Per-domain Q13.5 atomic recovery applies during execution (see 4.3).
- **Apply per-domain (re-prompt)** — re-prompt per domain (preserves Q13.4's per-domain semantics for users who want finer control). Each per-domain decision applies / skips that domain's writes.
- **Edit before applying** — surface the underlying inventory + L3 review content; user edits + re-runs Phase 4.
- **Pause + resume later** — exits cleanly; resumes at Phase 4 next run; in-memory L3 state lost (re-runs per parking lot #31 v1).
- **Cancel session** — write `status: abandoned`; exit cleanly.

This is **a single G4 gate**, NOT N separate gates for N domains (Q37 sub-decision 3 explicit lock). User authorization at G4 covers the whole batch.

### 4.3 Per-domain execution with Q13.5 atomic recovery

After G4 approval, orchestrator iterates `state.domains[]` and invokes `flow-linear-scaffold` for each domain to execute that domain's Linear writes. **Q13.5 sub-flow-atomic recovery applies per domain:**

- On success: mark `breadcrumb.domains[<i>].scaffold_state = "completed"`, capture `parent_issue_ids[]`, write breadcrumb.
- On failure: mark `breadcrumb.domains[<i>].scaffold_state = "failed"`, set `failure_reason`, write breadcrumb. Orchestrator pauses inner loop via `AskUserQuestion`:

  > "Domain `<slug>` scaffold failed: `<reason>`. How should I proceed?"
  >
  > - **Retry this domain** — re-invoke `flow-linear-scaffold` for `<slug>`.
  > - **Skip this domain + continue** — leave Linear writes incomplete for `<slug>`; mark `scaffold_state = "failed"`; continue inner loop with next pending domain.
  > - **Abort Phase 4** — write `status: abandoned` to breadcrumb; exit. Successful domains remain scaffolded.

After all domains processed (any combination of completed / failed / skipped), proceed to Phase 5 with the domains that completed successfully.

**Breadcrumb update at end of Phase 4:** `current_phase: 5`, `completed_phases: ["1", "2", "3", "4"]`, `domains[].scaffold_state` reflecting per-domain outcome.

**Failure semantics (Phase 4):** per-domain Q13.5 sub-flow-atomic recovery — failure isolated to one domain; orchestrator pauses inner loop for user adjudication then resumes with remaining domains.

---

## Phase 5: doc author (globally batched)

**Sub-skill:** `flow-doc-author` (Q15; not yet shipped — orchestrator references by name).

This phase is **globally batched** — orchestrator invokes `flow-doc-author` ONCE with all N domains' sub-flows. This activates Q15.2's per-sub-flow internal parallelism (~30-60s wall regardless of N).

**Pre-condition:** Phase 4 completed; `state.domains[]` populated with parent issue IDs per completed domain.

**Run:** dispatch `flow-doc-author` with the full set of sub-flows from `state.inventory.domains[*].sub_flows[*]`, filtered to domains where `scaffold_state == "completed"`. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + per-sub-flow parent issue (for L3 headlines + AC).
2. Writes story docs at `docs/product/flows/<domain>/<sub-flow-id>.md` per sub-flow.
3. Q15.2 internal parallelism dispatches per-sub-flow drafters concurrently.
4. Skip-if-exists per Q15.3: existing story docs preserved unless `--force` flag passed.
5. Q15.5 log + continue: partial failures within the batch surface in batch summary; orchestrator does NOT roll back successful writes.

**Capture into state:** `state.ship_artifacts.story_docs[]`.

**No gate.** Q15.6 locks 0 sync gates for Phase 5. The phase runs to completion (or partial-with-batch-summary) and dispatches to Phase 6.

**Breadcrumb update:** `current_phase: 6`, `completed_phases: ["1", "2", "3", "4", "5"]`.

**Failure semantics (Phase 5):** log + continue per Q15.5. Partial Q15 failures surface in batch summary; outputs are filesystem writes reviewable via `git diff` + `bash scripts/verify-docs.sh`.

---

## Phase 6: journey author (globally batched)

**Sub-skill:** `flow-journey-author` (Q16; not yet shipped — orchestrator references by name).

This phase is **globally batched** — orchestrator invokes `flow-journey-author` ONCE with all N domains. This activates Q16.2's per-domain internal parallelism (~60-90s wall regardless of N).

**Pre-condition:** Phase 5 completed; story docs written for all completed domains.

**Run:** dispatch `flow-journey-author` with the full set of domains from `state.inventory.domains[]`, filtered to `scaffold_state == "completed"`. The skill:

1. Reads `intent.md` + `master-flow-inventory.md` + per-domain story docs + `state.l2_review_<domain>` stash from Phase 3.
2. Writes journey docs at `docs/product/journeys/<domain>.md` per domain.
3. Populates each journey doc's `## L2 review summary` section from the stash per Q26 mod 2 / Q16.7 optional read path. **Read the stash only — DO NOT re-fire L2 reviewers in Phase 6.** L2 fires exactly once per domain inside Phase 3; on crash-resume, Phase 3 re-runs (and re-fires L2) per parking lot #31 v1, never Phase 6.
4. Q16.2 internal parallelism dispatches per-domain drafters concurrently.
5. Skip-if-exists per Q16.3: existing journey docs preserved unless `--force` flag passed.
6. Q16.5 log + continue: partial failures within the batch surface in batch summary.

**Capture into state:** `state.ship_artifacts.journey_docs[]`.

**No gate.** Q16.6 locks 0 sync gates for Phase 6.

**Breadcrumb update:** `current_phase: 7`, `completed_phases: ["1", "2", "3", "4", "5", "6"]`.

**Failure semantics (Phase 6):** log + continue per Q16.5. Same shape as Phase 5.

---

## Phase 7: persona author (globally batched)

**Sub-skill:** `flow-persona-author` (BC-14018; shipped at `plugins/flow-architecture/skills/flow-persona-author/SKILL.md`).

This phase is **globally batched** — orchestrator invokes `flow-persona-author` ONCE for the whole project. The skill enumerates the project-wide persona set and fans out 1 `Agent(persona-doc-author)` per unique persona slug under a ~10 concurrency cap (~90s wall for K≤10 personas).

**Pre-condition:** Phase 6 completed; journey docs written for all completed domains. Personas are authored AFTER journeys because the journey docs are the persona-doc-author agent's richest behavioral source AND the story docs (Phase 5) are the source of the `personas:` slug set this skill enumerates.

**Run:** dispatch `flow-persona-author`. The skill:

1. Reconciles the persona set — the union of every non-empty story-doc `personas:` slug (`docs/product/flows/<domain>/*.md`, the same parse as `flow_persona_lint.py`) with the inventory persona column / `intent.md` `## Target users`, minus honest-empty (ADR-041 / ADR-029 honest-empty canon).
2. Per slug, gathers the `persona-doc-author` inputs (slug, display_name, device, `journey_paths` = journeys whose aggregate `personas:` includes the slug, `served_flows` = flows whose `personas:` include it, intent_path, template_path, today).
3. Writes whole-file persona docs at `docs/product/personas/<slug>.md` (the agent emits front-matter + body; only `last_reviewed` is dispatcher-supplied — no builder). Strips the agent's inline HTML source-comments before writing.
4. Per-persona fan-out runs concurrently under the cap.
5. Skip-if-exists: existing persona docs preserved unless `--force` flag passed.
6. Authors/refreshes `docs/product/personas/INDEX.md` (new rows land `Drafted`; `quality-reviewer` promotes to `Reviewed` — the skill does not self-certify).
7. Log + continue: a persona returning the `PERSONA-DOC-AUTHOR-ERROR` sentinel surfaces in the batch summary.

**Capture into state:** `state.ship_artifacts.persona_docs[]`.

**No gate.** BC-14018 locks 0 sync gates for Phase 7 (filesystem write; git review is the implicit gate — same rule as Phases 5/6).

**Breadcrumb update:** `current_phase: 8`, `completed_phases: ["1", "2", "3", "4", "5", "6", "7"]`.

**Failure semantics (Phase 7):** log + continue per BC-14018. Same shape as Phase 5/6 — one failed persona surfaces in the batch summary and never aborts the batch; user re-runs with `--force`.

---

## Phase 8: regen index

**Sub-skill:** `flow-regen-index` (Q18; not yet shipped — orchestrator references by name).

**Run:** dispatch `flow-regen-index`. The skill regenerates `docs/product/flows/INDEX.md` from `master-flow-inventory.md` + per-domain story doc presence. Idempotent — re-running yields the same INDEX content for the same input.

**No gate.** Q18.8 locks 0 sync gates for Phase 8.

**Capture into state:** `state.ship_artifacts.index_path`.

**Breadcrumb update:** `current_phase: 9`, `completed_phases: ["1", "2", "3", "4", "5", "6", "7", "8"]`.

**Failure semantics (Phase 8):** Q18.7 log + continue + skip-row marker. If a specific row's render fails (e.g., a sub-flow's story doc missing), INDEX includes a "regen-failed: <reason>" marker for that row rather than clobbering with a partial INDEX or omitting the row silently.

---

## Phase 9: complete

Inline terminator phase. No sub-skill dispatch — orchestrator owns the final summary + breadcrumb write.

**Run:**

1. Render user-facing completion summary listing artifacts produced:
   - `docs/product/intent.md`
   - `docs/product/master-flow-inventory.md`
   - `docs/product/flows/<domain>/<sub-flow>.md` per sub-flow (count + sample paths)
   - `docs/product/journeys/<domain>.md` per domain
   - `docs/product/personas/<slug>.md` per behavioral persona + `docs/product/personas/INDEX.md`
   - `docs/product/flows/INDEX.md`
   - Linear: `<N>` milestones + `<sum>` parent issues + `<sum × 5>` discipline children — list URLs grouped by domain
   - L-review coverage: L1 (1 invocation, intent.md) + L2 (`<D>` invocations, journey docs) + L3 (`<sum>` invocations, parent issues)

2. **Final breadcrumb write:** `status: completed`, `current_phase: 9`, `completed_phases: ["1"..."9"]`. The Q31.5 atomic-rename write through `flow-resume-breadcrumb.sh write` is the **last operation** of the orchestrator — never write the `completed` marker before all artifacts land on disk (BC-5761 precedent applied here).

3. Recommend next steps:
   - Run `/flow:audit` (Q38; pending) for project-health snapshot covering the 37-gate stack (post-Q29 amendment 6).
   - Run `/flow:plan-<discipline>` per discipline child for AC + Tasks population.
   - Hand-edit `docs/product/journeys/<domain>.md` to refine narrative voice if needed (atomic rename ensures journey doc fully written; `--force` regen will clobber hand-edits per Q16.3).

**Failure semantics (Phase 9):** n/a — terminator. Any failure prior to the final breadcrumb write leaves breadcrumb at Phase 8 or earlier; resume picks up appropriately.

---

## Gate-respect contract

Every `AskUserQuestion` in this command — G1, G2, G3, G4, per-domain Phase 4 adjudication prompts, and Phase 4.2's "Apply per-domain (re-prompt)" escape — is bound by the gate-respect contract (`plugins/flow-architecture/skills/_shared/gate-respect.md` once promoted; cf. cadence `skills/_shared/gate-respect.md`). Once the user picks an option, execute exactly that option. To deviate, re-prompt via a new `AskUserQuestion`. Mentions in the breadcrumb, notes, or batch summaries do NOT constitute user authorization.

Origin: cadence BC-5866 precedent surfaced this class-bug across orchestrators; same discipline applies here from day 1.

## Phase-exit breadcrumb update (canonical pattern)

Every phase ends with a breadcrumb update so resume can reason about what's complete. Each phase ID (`1` through `8`) appends at the phase's terminal step:

1. Append the phase number to `breadcrumb.completed_phases` (in order).
2. Set `breadcrumb.current_phase` to the next phase number (or leave at `9` after Phase 9).
3. Set `breadcrumb.status` (`in_flight` until Phase 9 terminator; then `completed`).
4. Refresh `breadcrumb.last_updated` with the current ISO-8601 timestamp (NOT `updated_at` — the helper script's stale-detection in `read` mode keys on `last_updated`; writing the wrong field name would silently break staleness checks).
5. Persist via the BC-6956 helper. The helper `write` subcommand takes two positional arguments — `<state-path>` (the breadcrumb on disk) and `<input-path>` (a `mktemp`'d file holding the new JSON) — per BC-9027. See the Phase 1 example for the canonical `python3 > $TMP_JSON <<'PY' ... PY; bash $HELPER write $BREADCRUMB_PATH $TMP_JSON; rm -f $TMP_JSON` form. Construct dynamic values inside a single-quoted python heredoc (`<<'PY'`) so Linear-derived strings cannot expand into the shell; pass `$BREADCRUMB_PATH` and `$TMP_JSON` as discrete arguments to the helper (never inside `bash -c` or an unquoted `$(...)`). The `mktemp` file intermediate replaces the previous stdin-pipe pattern, which tripped the workflows security-hook classifier.

The breadcrumb append is the **last step** of a phase, after all of the phase's artifacts (intent.md / inventory / Linear writes / story docs / journey docs / INDEX) have landed. Writing the breadcrumb earlier would let a killed session resume with a phase marked "complete" but artifact missing.

## See also

- `plugins/flow-architecture/docs/design-rationale/fda-plugin-interview.md:682` — Q37 lock (canonical source; seven sub-decisions + refinement audit trail at line 698).
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-architecture-overview.md` §3e — Greenfield Orchestrator Phase Flow (synthesis view).
- `plugins/flow-architecture/skills/flow-preflight/SKILL.md` — Phase 1 sub-skill (BC-6957 shipped).
- `plugins/flow-architecture/scripts/flow-resume-breadcrumb.sh` — Q31.5 atomic-rename breadcrumb helper (BC-6956 shipped).
- `plugins/cadence/commands/weekly.md` — orchestrator precedent (5 phases / 3 gates / phase-state breadcrumb / gate-respect contract).
- Handbook CDR-023 — Flow-Driven Architecture (the policy this plugin implements).
- Handbook `how-we-work/operating-standards/flow-driven-architecture.md` — operating-standards page (Q34 lock).
