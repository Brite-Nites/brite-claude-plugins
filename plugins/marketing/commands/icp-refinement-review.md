---
description: Review pending `icp-refinement` signals emitted by `/marketing:campaign-debrief` to `docs/campaigns/{entity}/{slug}/discoveries.json`. For each signal, operator picks promote / reject / defer. Promoted signals flip `promotion_status` in place AND emit a handbook markdown blob the operator pastes into a manual handbook PR (this command does NOT auto-open handbook PRs — operator review is the point). Per BC-8722's discoveries pattern + `plugins/marketing/references/discoveries-promotion.md`. Tier 9 / weekly cadence. Triggers on "icp-refinement-review", "review discoveries", "review icp signals", or direct `/marketing:icp-refinement-review` invocation.
argument-hint: [--non-interactive] [--decision-map <path-to-json>]
allowed-tools: Read, Write, Bash, AskUserQuestion
---

# /marketing:icp-refinement-review

> **How this command runs**: like `/marketing:plan-campaign`, this is a model-interpreted spec, not a binary. Steps execute in order using the tool palette above. The deterministic IO (glob, mutate, emit) is delegated to `plugins/marketing/scripts/icp_refinement_review.py`; operator decisions go through `AskUserQuestion`. To debug a partial run, re-invoke and skip already-decided signals via `--decision-map`.

The review loop for `category=icp-refinement` signals in the GTM Discoveries pipeline (BC-8722). Reads pending signals across every campaign run, surfaces them grouped by vertical, captures one operator decision per signal, mutates `discoveries.json` files in place, and emits a handbook-PR markdown blob the operator pastes into a manual PR.

| Layer | What this command touches |
|---|---|
| Plugin filesystem | `docs/campaigns/*/*/discoveries.json` — flips `promotion_status` for decided signals |
| Handbook repo | **Nothing** — emits markdown to stdout/scratch for operator-driven PR |
| Linear / SF / EB | Untouched — this command is a pure-disk review loop |

## Inputs / outputs / precedent

**Inputs**: optional `--non-interactive` flag + `--decision-map <path>` JSON. Both unset = interactive mode.

**Outputs**:
- `docs/campaigns/*/*/discoveries.json` — `promotion_status` mutations for decided signals (preserves file structure; one read+write per touched file).
- Stdout — handbook markdown blob per `promoted` signal (operator pastes into handbook PR).
- Stdout — summary: N promoted / M rejected / K deferred + updated file paths.

**Precedent + sources**:
- `plugins/marketing/data/discoveries-schema.json` (BC-8722) — the schema contract this command consumes + mutates.
- `plugins/marketing/scripts/lint_discoveries.py` (BC-8722) — schema enforcement; runs in `scripts/validate.sh` against the mutated files.
- `plugins/marketing/references/discoveries-promotion.md` — full signal → review → handbook PR flow + promotion-status invariants.
- `plugins/marketing/skills/campaign-debrief/SKILL.md` § Discoveries — the producer side of the `icp-refinement` payload contract.
- `plugins/marketing/commands/plan-campaign.md` — multi-step interactive-command pattern this command mirrors.

## Non-goals

- Do NOT auto-open handbook PRs. Emit markdown; operator handles the PR. (Per session-prompt 2026-05-26: "operator review is the point".)
- Do NOT touch `canonicals/{vertical}.yaml`. ICP refinement may eventually warrant canonicals edits (persona carve, sub-segment), but that's a downstream operator decision after the handbook prose lands.
- Do NOT introduce a 5th `discoveries-schema.json` category. The 4-category lock (`title-discovery` / `icp-refinement` / `offer-retirement` / `persona-discovery`) is V3-gated; a 5th would ship as a follow-up BC.
- Do NOT handle `offer-retirement` / `persona-discovery` / `title-discovery` categories. This command targets `icp-refinement` only — sibling categories get sibling review commands when they're prioritized.

---

## Step 0 — Scan for pending signals

Invoke the helper to enumerate pending `icp-refinement` signals across the campaigns tree:

```bash
python3 plugins/marketing/scripts/icp_refinement_review.py \
  --campaigns-dir docs/campaigns \
  scan
```

The helper emits JSON of shape:

```jsonc
{
  "total_pending": 3,
  "groups": {
    "hotels-resorts": [
      {
        "signal_id": "labs/hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02/discoveries.json::0",
        "vertical": "hotels-resorts",
        "persona": "director-of-resort-experience",
        "payload": {
          "vertical": "hotels-resorts",
          "persona": "director-of-resort-experience",
          "current_icp_summary": "Director of Resort Experience at 200+ room luxury resorts",
          "observed_pattern": "Responders skewed to family-resort sub-segment specifically",
          "evidence_metric": "Reply Rate 4.1% on N=120 family-resort vs 0.6% on N=380 non-family",
          "refinement_proposal": "Split persona into director-of-resort-experience-family vs ...-luxury"
        },
        "emitted_at": "2026-05-26T10:00:00Z",
        "emitted_by_skill": "campaign-debrief"
      }
    ]
  }
}
```

If `total_pending == 0`: halt with "No pending icp-refinement signals — nothing to review." Do NOT proceed to Step 1.

If `total_pending > 0`: capture the JSON to a scratch file (e.g., `mktemp`) for use in Steps 1–3.

## Step 1 — Per-signal operator decision

For each `signal_id` in the scan output, invoke `AskUserQuestion` with **one signal at a time** (per `feedback_one_question_at_a_time.md` + `feedback_interview_chunking.md`):

**Question**: `Promote / Reject / Defer this icp-refinement signal? — {vertical} / {persona}`

Include in the question prose:
- `current_icp_summary` from payload
- `observed_pattern` from payload
- `evidence_metric` from payload
- `refinement_proposal` from payload

**Options** (always these three, in this order):

| Label | Meaning |
|---|---|
| `Promote` | `promotion_status` → `promoted`. Emit handbook markdown blob at Step 3. |
| `Reject` | `promotion_status` → `rejected`. No handbook emission. |
| `Defer` | No mutation. Signal stays `pending`; revisit next cycle. |

Process verticals in alphabetical order (Step 0's `groups` is already sorted). Within a vertical, process signals in emitted order. The operator can `Esc` at any prompt to halt mid-loop — already-decided signals stay in the in-memory decision map; the loop resumes Step 2 with whatever was decided.

Build the decision map as a flat dict: `{signal_id: "promoted" | "rejected" | "deferred"}`. Write this dict to a scratch JSON file (e.g., `mktemp` then `Write`) for use in Steps 2–3.

### Non-interactive mode

If invoked with `--non-interactive --decision-map <path>`, skip Step 1 entirely. The supplied JSON is the decision map. Used by `plugins/marketing/scripts/test_icp_refinement_review.sh` and by operators re-driving a partially-completed review.

## Step 2 — Apply decisions

Invoke the helper to mutate `discoveries.json` in place:

```bash
python3 plugins/marketing/scripts/icp_refinement_review.py \
  --campaigns-dir docs/campaigns \
  apply --decision-map <path-to-decision-map.json>
```

The helper:
- Reads each touched `discoveries.json` once, mutates the targeted `signals[]` entries, writes back via `json.dumps(data, indent=2) + "\n"`.
- HARD-FAILS (exit 1) if a decision references a missing file, an out-of-range index, a non-`icp-refinement` signal (defensive — defends against scan/apply race), or an unrecognized decision string.
- Skips signals already in a terminal `promotion_status` (`promoted` or `rejected`) — promotion is one-way per `references/discoveries-promotion.md` § Promotion-status invariants. Such signals count in the `skipped` summary line.
- Prints JSON summary: `{"promoted": N, "rejected": M, "deferred": K, "skipped": S}`.

If exit code is non-zero, surface the helper's stderr to the operator and halt (do NOT proceed to Step 3). Common cause: the operator hand-edited a discoveries.json between Step 0 scan and Step 2 apply — re-invoke from Step 0.

## Step 3 — Emit handbook markdown blobs

For every `promoted` decision, invoke the helper to print a markdown blob:

```bash
python3 plugins/marketing/scripts/icp_refinement_review.py \
  --campaigns-dir docs/campaigns \
  emit-handbook --decision-map <path-to-decision-map.json>
```

The helper prints one blob per `promoted` signal, separated by `---`, each carrying:
- Source-signal provenance HTML comments (`signal_id`, `emitted_by_skill`, `emitted_at`)
- Target file pointers — `handbook/marketing/go-to-market/verticals/{vertical}/README.md` (prose) + companion `plugins/marketing/data/canonicals/{vertical}.yaml` (canonicals)
- The signal's `current_icp_summary` / `observed_pattern` / `evidence_metric` / `refinement_proposal` rendered as readable prose
- A suggested commit message for the handbook PR

Capture the helper's stdout. Print it back to the operator with a header:

```
==============================================================
Handbook PR markdown — paste into handbook/marketing/go-to-market/...
==============================================================

<helper stdout>

==============================================================
Suggested handbook PR title: BC-8726: icp-refinement-review YYYY-MM-DD batch
==============================================================
```

<!-- lint:not-side-effecting this command is a pure-disk review loop — it writes ONLY local docs/campaigns/*/discoveries.json files (a non-external-state mutation, same class as the canonicals/manifest builders) and emits handbook markdown to stdout for operator-driven review. allowed-tools is Read/Write/Bash/AskUserQuestion with NO mcp__ or Skill grant. The R1 heuristic matched the shell tokens in the line below, but they appear inside a Do-NOT prohibition (the command explicitly refuses to auto-PR), not a real grant — so disable-model-invocation is NOT warranted; this override is the honest fix (BC-12943, ADR-028 R1 prose-mention FP). -->
Do NOT `gh pr create` or `git push` to the handbook repo. Operator review of the prose IS the point — auto-PR'd handbook drafts erode the human-in-the-loop guarantee this command exists to provide.

## Step 4 — Print summary

Surface the Step 2 helper's JSON summary alongside touched-file paths:

```
ICP refinement review complete.

  Promoted: <N>  → handbook markdown printed above (Step 3)
  Rejected: <M>
  Deferred: <K>  → signals remain `pending`; surface again next review cycle
  Skipped:  <S>  → already-terminal signals (no-op; pre-existing decisions preserved)

  Touched files:
    - docs/campaigns/<entity>/<slug>/discoveries.json
    - ...

  Next step (if Promoted > 0):
    1. Paste the Step 3 markdown into a handbook PR draft.
    2. Open the PR; tag Sarah Cullen + Kells for review (per discoveries-promotion.md).
    3. Once handbook PR merges, this signal's promotion is fully committed.
```

---

## Idempotence + re-invocation

This command is safe to re-invoke at any time. Already-decided signals (terminal `promotion_status`) are filtered out at Step 0 scan, so a second run never re-asks the operator about them. A run cancelled mid-loop (operator Esc) leaves whichever decisions were already applied via Step 2 intact; re-invoking picks up the remaining pending signals.

## Validation

- `./scripts/validate.sh` exits 0 after this command runs (the discoveries-lint at § 15a-discoveries validates the mutated files).
- `bash plugins/marketing/scripts/test_icp_refinement_review.sh` exercises 5 fixtures non-interactively via `--decision-map` JSON files; sub-command exit codes + summary-line substrings are asserted per the BC-8712 follow-up substring-assertion discipline.

## Plugin version coupling

Per CLAUDE.md plugin-cache gotcha, any edit to this file requires bumping `plugins/marketing/.claude-plugin/plugin.json` AND the marketplace.json marketing entry in the same commit. The `scripts/pre-commit.sh` hook enforces.
