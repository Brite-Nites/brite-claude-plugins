# BC-5938 Plan — Preset library ship readiness

**Issue:** [BC-5938](https://linear.app/brite-nites/issue/BC-5938/preset-library-ship-readiness-readme-manifest-anti-slop-validation)
**Branch:** `holden/bc-5938-preset-library-ship-readiness`
**Worktree:** `.claude/worktrees/bc-5938/`
**Role:** R-16 of the email-copywriting preset roadmap — single "preset library is ready to ship" gate after R-10..R-15 all shipped.

## State summary (verified on disk)

- **28 preset files on disk** under `plugins/marketing/skills/email-copywriting/presets/` (+ README).
- **Per vertical:**
  - municipalities — 2 files (list + risk)
  - aquariums — 4 files (list + risk + list-production-finance + risk-production-finance)
  - casinos — 6 files (list + risk + list-pilot-zone + risk-pilot-zone + list-retention-subscription + risk-retention-subscription)
  - hotels-resorts — 4 files (list + risk + list-rate-premium + risk-rate-premium)
  - ski-resorts — 4 files (list + risk + list-pilot-zone + risk-pilot-zone)
  - sports-stadiums — 4 files (list + risk + list-plaza-pilot-zone + risk-plaza-pilot-zone)
  - zoos — 4 files (list + risk + list-pilot-zone + risk-pilot-zone)
- **Manifest (README.md) is stale:** still uses the pre-pivot 3-tier (Active/Exploring/Future) layout with "Pending BC-5879" cells for displaced Active-tier Nites, and "Pending BC-5880/5881" cells for verticals that actually shipped under the 2026-04-21 roadmap pivot.

## Tasks (atomic, 2–5 min each)

### Task 1 — Enumerate preset files (confirm baseline)
- **What:** `ls plugins/marketing/skills/email-copywriting/presets/*.md | grep -v README.md | wc -l`
- **Expect:** `28`
- **If wrong:** Halt and reconcile with the issue scope (each R-10..R-15 owns its own file set; deviation means one vertical under- or over-shipped).

### Task 2 — Rewrite manifest (README.md) to match 2026-04-21 pivot
- **File:** `plugins/marketing/skills/email-copywriting/presets/README.md`
- **Change plan:**
  1. Update the "46 files" target count in the `## Preset manifest` header — replace with accurate on-disk count + displaced-rows note.
  2. Add a `## 2026-04-21 scope pivot` subsection at the top of `## Preset manifest` that explains: original BC-5879 Active-tier Nites scope (HOAs / Landscape Lighting / Landscape Architects / Builders / Universities) was displaced; replaced with 6 Labs-tier verticals (zoos / aquariums / casinos / hotels-resorts / ski-resorts / sports-stadiums) shipped by R-10..R-15 per `docs/designs/email-copywriting-preset-roadmap.md`. Reference the displaced-Nites follow-up issue (filed in Task 7).
  3. Restructure tables to two tables:
     - **Shipped — 6 Labs verticals (R-10..R-15) + seed (BC-5825)** — rows for municipalities, zoos, aquariums, casinos, hotels-resorts, ski-resorts, sports-stadiums. Each row lists primary list + risk files ✅ and any variants in a "variants" column.
     - **Displaced / deferred** — Active-tier Nites (5 verticals) with "Displaced — see BC-NEWID" status; keep Exploring-tier and Future-tier rollups with fan-out pointer (BC-5880 / BC-5881).
  4. Keep the `## Usage`, `## Preset file shape`, `## Seeding status` sections unchanged except: update the "45 files stay on disk" number in `## Usage` to match the new on-disk count (28 at time of write; framed as "N-1 stays on disk" with N = total).

### Task 3 — Anti-slop grep: curly-brace merge tokens
- **Command:** `grep -l '{{' plugins/marketing/skills/email-copywriting/presets/*.md`
- **Expect:** No files returned.
- **If any:** Halt; fix belongs in originating R-10..R-15, not this issue (per Non-Goals).

### Task 4 — Anti-slop grep: raw `<p>` HTML leakage
- **Command:** `grep -l '<p>' plugins/marketing/skills/email-copywriting/presets/*.md`
- **Expect:** No files returned.
- **If any:** Halt and flag.

### Task 5 — Anti-slop grep: em-dash
- **Command:** `grep -l '—' plugins/marketing/skills/email-copywriting/presets/*.md`
- **Expect:** No files returned.
- **If any:** Halt and flag. (Precedent: BC-5936 task-1 em-dash AC enforcement applies file-wide per preset, not just subject line.)

### Task 6 — Subject-line merge-variable check
- **Command:** `grep -E '^\*\*Subject:\*\*' plugins/marketing/skills/email-copywriting/presets/*.md | grep -E '\{[A-Z_]+\}|\{\{'`
- **Expect:** No matches. (Only spintax `{opt1|opt2}` allowed, no `{FIRST_NAME}` merge vars.)
- **If any:** Halt; originating R-10..R-15 owns the fix.

### Task 7 — File Active-tier Nites follow-up issue (if not exists)
- **Check:** Query Linear `list_issues` with `query: "Active-tier Nites preset"` or similar to confirm no existing issue covers the displaced work.
- **If missing:** `save_issue` with title "Fan out Active-tier Nites preset library (displaced from BC-5879)", project "Brite Plugin Marketplace", team "Brite Company", priority Medium, labels `skill`, milestone "Marketing Plugin: GTM Workflows", description referencing the 2026-04-21 pivot + the 5 Nites verticals (HOAs, Landscape Lighting, Landscape Architects, Builders & Developers, Universities) + 10 target files (5 × 2 preset types). Capture the new issue ID for the manifest reference.
- **If exists:** Use its ID for the manifest reference.

### Task 8 — `./scripts/validate.sh`
- **Command:** `./scripts/validate.sh`
- **Expect:** Exit 0. Warning count ≤ baseline (16 per memory).

### Task 9 — `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- **Command:** `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- **Expect:** Exit 0.

### Task 10 — Commit + verify Linear description intact post-save
- Commit: `BC-5938: preset library ship readiness (R-16)` with Co-Authored-By trailer.
- If the manifest pivot note is added via `save_issue` anywhere, follow up with `get_issue` per auto-memory gotcha on Linear Prosemirror mangling.

## Verification checklist (from issue AC, objective pass/fail)

- [ ] `grep -c 'Pending BC-5879' README.md` returns 0 OR only the Active-tier Nites row pointing to the displaced-follow-up issue
- [ ] All R-10..R-15 preset files appear in manifest with ✅ and correct filename
- [ ] `grep -l '{{' presets/*.md` returns no files
- [ ] `grep -l '<p>' presets/*.md` returns no files
- [ ] `grep -l '—' presets/*.md` returns no files
- [ ] No `{FIRST_NAME}` or other merge variable in any subject line
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
- [ ] Active-tier Nites follow-up Linear issue exists and is referenced from the manifest

## Non-goals (explicitly excluded)

- Do NOT modify individual preset files (fixes belong in originating R-10..R-15 or a follow-up).
- Do NOT modify `SKILL.md`.
- Do NOT re-run R-10..R-15 verification.
- Do NOT expand scope to BC-5880 / BC-5881 fan-outs.

## Risks

- **Low**. Pure manifest edit + verification. If any anti-slop grep fails, the issue halts and delegates the fix to the originating R-issue — this issue stays atomic.
- Manifest table structure pivot is the only judgment call; two-table shape (Shipped + Displaced/Deferred) is proposed to make roadmap state legible at a glance.
