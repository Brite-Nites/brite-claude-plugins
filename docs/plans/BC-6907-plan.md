# BC-6907 — Refactor tier_and_segment.py CLI into in-session Skill

**Linear:** [BC-6907](https://linear.app/brite-nites/issue/BC-6907/refactor-tier-and-segmentpy-cli-into-in-session-skill-eliminate)
**Branch:** `holden/bc-6907-refactor-tier_and_segmentpy-cli-into-in-session-skill`
**Worktree:** `.claude/worktrees/bc-6907/`

## Working assumption

The fold-into-icp-scoring decision is **already executed** in code:

- `plugins/marketing/skills/icp-scoring/SKILL.md` lines 103–111 + 168–176 + Scenario 7 (lines 409–417) implement the `abc` rubric + tam-mapping delegation contract.
- `plugins/marketing/skills/tam-mapping/SKILL.md` Phase 7 (line 367+) already invokes `icp-scoring --rubric abc` — does NOT shell out to `tier_and_segment.py`.
- `plugins/marketing/commands/tam-map.md` Phase 6 (line 457+) renders the same delegation.

Therefore the work is a **cleanup refactor**: delete the dead Python script, drop the `anthropic` dependency, remove `ANTHROPIC_API_KEY` from every doc/probe path, version-bump. No new skill body, no new runtime path.

If validation reveals a hidden runtime caller this assumption breaks — Task 1 is the gate.

## Tasks

### Task 1 — Confirm no live runtime callers (3 min)

**Goal.** Prove `tier_and_segment.py` is dead before deleting.

**Steps.**

1. Grep the active runtime invocations (skills + commands + hooks, excluding refs/docs/examples):
   ```bash
   grep -rn 'tier_and_segment\.py' \
     plugins/marketing/skills/ \
     plugins/marketing/commands/ \
     plugins/marketing/hooks/ \
     plugins/marketing/agents/ 2>/dev/null
   ```
2. Expected matches: only `setup-tam-map.md` (probe script enumeration) and `tam-map.md` Phase 0 + historical changelog. Both are passive — no `python … tier_and_segment.py` invocation lives.
3. Grep neighboring repos (best-effort, no clone):
   ```bash
   gh search code 'tier_and_segment' --owner Brite-Nites --limit 30
   ```
4. Document findings in plan checkpoint. If a live caller exists outside the changelog/probe contexts, **stop and re-plan** (the deprecation-shim branch of the issue's step 6 applies).

**Verification.** Zero live shell invocations of `python … tier_and_segment.py` in skills/commands/hooks/agents. Sole references are doc/probe/changelog.

---

### Task 2 — Delete the Python script + drop anthropic dep (3 min)

**Files.**

- Delete: `plugins/marketing/scripts/tam-map/tier_and_segment.py`
- Edit: `plugins/marketing/scripts/tam-map/requirements.txt`
- Edit: `plugins/marketing/scripts/tam-map/README.md`

**Steps.**

1. `rm plugins/marketing/scripts/tam-map/tier_and_segment.py`
2. `requirements.txt`: remove the line `anthropic>=0.40.0`. Leave the other three dependencies (`aiohttp`, `requests`, `python-dotenv`) — they still serve the four CLI scripts that remain (`icypeas_client.py`, `spider_crawl.py`, `enrich_waterfall.py`, `verify_smtp.py`).
3. `scripts/tam-map/README.md`: remove the table row for `tier_and_segment.py` (line ~18). The deprecation footnote ("BC-6907 will replace this script…") is now stale — remove the whole row, do not retain a tombstone.

**Verification.**

```bash
test ! -f plugins/marketing/scripts/tam-map/tier_and_segment.py && echo OK
grep -c 'anthropic' plugins/marketing/scripts/tam-map/requirements.txt  # → 0
grep -c 'tier_and_segment' plugins/marketing/scripts/tam-map/README.md  # → 0
```

---

### Task 3 — Strip ANTHROPIC_API_KEY + script refs from setup-tam-map.md (4 min)

**File.** `plugins/marketing/commands/setup-tam-map.md`

**Edits.**

- **Line ~10** (key list intro): drop the trailing parenthetical "(Note: `ANTHROPIC_API_KEY` previously belonged…)" — the key has now been eliminated, no historical note needed in active operator docs. Keep the seven-key list as-is.
- **Line ~213** (probe loop): change
  ```
  for s in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py tier_and_segment.py; do
  ```
  to
  ```
  for s in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py; do
  ```
- **Line ~236** (failure mode bullet): change
  ```
  Python CLI scripts (`icypeas_client.py`, `spider_crawl.py`, `enrich_waterfall.py`, `verify_smtp.py`, `tier_and_segment.py`) fail with `ModuleNotFoundError` for `requests` / `aiohttp` / `dotenv` / `anthropic`.
  ```
  to
  ```
  Python CLI scripts (`icypeas_client.py`, `spider_crawl.py`, `enrich_waterfall.py`, `verify_smtp.py`) fail with `ModuleNotFoundError` for `requests` / `aiohttp` / `dotenv`.
  ```

**Coordination note with BC-6906.** BC-6906 is in flight on the same file (different lines — it rewrites the `bw-run.sh` wiring for the OTHER 7 keys). PR description must call out: "Merge order with BC-6906 is order-independent — this PR only touches the script enumeration + ANTHROPIC parenthetical; BC-6906 only touches the bw-run.sh wiring. If a merge conflict surfaces, take both hunks."

**Verification.**

```bash
grep -c 'tier_and_segment\|ANTHROPIC_API_KEY' plugins/marketing/commands/setup-tam-map.md  # → 0
```

---

### Task 4 — Strip script refs from tam-map.md (3 min)

**File.** `plugins/marketing/commands/tam-map.md`

**Edits.**

- **Line ~144** (Phase 0 probe loop): same shape change as Task 3 — drop `tier_and_segment.py` from the script enumeration.
- **Line ~510** (Phase 7 parameterized menu prose): rewrite the trailing parenthetical
  > "(`tier_and_segment.py` is the Labs Phase 7 LLM-scoring step and explicitly cannot be reused for the Nites reshape)."
  to
  > "(the Labs Phase 7 LLM-scoring step lives in the `icp-scoring` skill's `abc` mode and explicitly cannot be reused for the Nites reshape)."
- **Changelog at line ~645**: do NOT edit historical changelog entries — they describe what happened on 2026-04-27. They stay as written for the audit trail.

**Verification.**

```bash
grep -n 'tier_and_segment' plugins/marketing/commands/tam-map.md
# Only the 2026-04-27 changelog entry may remain.
```

---

### Task 5 — Sweep reference docs + tool-integration pages (5 min)

**Files (5).**

1. `plugins/marketing/tools/integrations/spider-cloud.md` line ~91: change "emits crawl output to the fit-scoring prompt via `tier_and_segment.py`" → "emits crawl output to the fit-scoring prompt via the `icp-scoring` skill (`abc` rubric)".
2. `plugins/marketing/tools/integrations/millionverifier.md` lines ~96 + ~103: replace both `tier_and_segment.py` mentions with the same `icp-scoring abc` phrasing. Preserve the "step 7"/"step 8" numbering — only the implementation name changes.
3. `plugins/marketing/references/tam/UPSTREAM.md` line ~35: remove the `tier_and_segment.py` row from the verbatim-port table and add a `### Local deviations` entry below (mirroring the BC-7050 / BC-7051 form) noting: "`scripts/tier_and_segment.py` removed per BC-6907 — the LLM tier-scoring step is now `icp-scoring` skill (`abc` rubric) running inline in the Claude Code session. Eliminates `ANTHROPIC_API_KEY` from the tam-map key set."
4. `plugins/marketing/references/tam/fit-scoring.md` line ~10: change "Claude Haiku uses this prompt (via `scripts/tier_and_segment.py`)…" → "Claude Haiku uses this prompt (via the `icp-scoring` skill's `abc` rubric)…"
5. `plugins/marketing/references/tam/segment-routing.md` lines ~16 + ~62: replace both `tier_and_segment.py emits…` / `writes exactly this shape` mentions with "The `icp-scoring` skill's `abc` rubric emits exactly this shape."
6. `plugins/marketing/references/tam/examples/roofing-contractors-tx.md` line ~68: replace the
   ```
   python scripts/tier_and_segment.py \
     --in verified.jsonl --icp icp.json --out-dir ./output/roofing-tx/segments/
   ```
   block with the in-session invocation:
   ```
   # Invoke icp-scoring abc rubric inline (tam-mapping Phase 7 delegation):
   icp-scoring --rubric abc \
     --criteria-file ./output/roofing-tx/icp.json \
     --output-dir ./output/roofing-tx/segments/ \
     --max-records <N>
   ```

**Verification.**

```bash
grep -rn 'tier_and_segment' plugins/marketing/ \
  --include='*.md' --include='*.py' --include='*.json' \
  | grep -v 'CHANGELOG\|2026-04-27\|node_modules'
# → empty (only the 2026-04-27 changelog entry in tam-map.md remains, which we keep)
```

---

### Task 6 — Plugin + marketplace version bump (1 min)

**Files.**

- `plugins/marketing/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`

**Steps.** Bump marketing plugin version from `0.3.33` → `0.3.34` in both files. Same commit per BC-6000 (24+ consecutive session precedent).

**Verification.**

```bash
grep '"version"' plugins/marketing/.claude-plugin/plugin.json
python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); print([p['version'] for p in m['plugins'] if p['name']=='marketing'])"
```

Both report `0.3.34`.

---

### Task 7 — Final validation (3 min)

**Steps.**

1. `./scripts/validate.sh` — full plugin validator.
2. Zero-references AC checks (the issue's two explicit assertions):
   ```bash
   grep -c 'ANTHROPIC_API_KEY' plugins/marketing/scripts/tam-map/  # recursive — should be 0
   grep -c 'ANTHROPIC_API_KEY' plugins/marketing/commands/setup-tam-map.md  # 0
   ```
3. Soft check that no live runtime path still expects the script:
   ```bash
   grep -rn 'python.*tier_and_segment\|tier_and_segment\.py' \
     plugins/marketing/skills/ plugins/marketing/commands/ plugins/marketing/hooks/ 2>/dev/null \
     | grep -v '2026-04-27'
   # → empty
   ```
4. Smoke test (per AC): the issue calls for `/marketing:tam-map` end-to-end on a Labs vertical with 10-tier-assignment sample. **Deferred** to user-driven post-PR validation — running it now consumes Spider+MillionVerifier+AIArk credits and is not reversible cleanup. Document the deferral in the PR body so review can sign off knowingly. (Identical disposition to BC-7050's smoke test, which the user ran post-merge.)

**Bitwarden admin note for PR body.** The Bitwarden item `tam-map-anthropic-api-key` (created in BC-6906) is now safe to delete from the Engineering collection. Document this in the PR description as an admin step; do NOT delete via script — vault mutations are user-performed.

---

## Acceptance criteria mapping

| AC from BC-6907 | Task |
|---|---|
| Skill consumes same input shape | Already true — icp-scoring `abc` mode (no work) |
| Skill emits identical `tier-{a,b,c}.csv` + `catch-all.csv` | Already true (no work) |
| tam-mapping Phase 7 invokes the skill, not the CLI | Already true (no work) |
| `/marketing:tam-map` Phase 6 invokes the skill, not the CLI | Already true (no work) |
| `tier_and_segment.py` deleted OR shim | Task 2 (deleted — no external callers) |
| Zero `ANTHROPIC_API_KEY` refs in `scripts/tam-map/` | Tasks 2 + 7 |
| Zero `ANTHROPIC_API_KEY` refs in `setup-tam-map.md` | Tasks 3 + 7 |
| Smoke test 10-assignment sample | Task 7 (deferred to post-merge per BC-7050 precedent) |
| Plugin + marketplace version bumped same commit | Task 6 |

## Out of scope (per issue)

- BC-6906's `bw-run.sh` migration of the other 7 keys (independent merge).
- Improving the tier-scoring rubric.
