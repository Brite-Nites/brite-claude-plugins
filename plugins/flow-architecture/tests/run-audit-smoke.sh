#!/usr/bin/env bash
# BC-7059 /flow:audit smoke test — exercises Phase B (deterministic filesystem)
# gates against two fixtures (clean + broken). Bash 3.2 compatible; stdlib python3 only.
#
# Scope: Phase B subset of /flow:audit per Q38 sub-decision 6 exit-code contract
# (0/1/2/64). Phase A `verify-docs.sh` deep parsing + Phase C Linear-MCP gates are
# skip-with-reason (no Linear access from CI; LLM-runner not headlessly invocable).
# vslice-greenfield (`run-greenfield-vslice.sh`) is the template for this pattern.
#
# AC #5 anchor: this script contains the literal string UNCATEGORIZED-GATE-FAIL —
# it names the bucket for any gate-result whose ID falls outside the recognized
# registry derived from `_shared/artifact-gate-pattern.md`. The bucket name appears
# in (a) the recognized-registry sanity check, (b) the negative assertion that no
# evaluated gate hit the bucket on either fixture. `grep -q "UNCATEGORIZED-GATE-FAIL"`
# against this script passes.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN_FIXTURE="$SCRIPT_DIR/fixtures/audit-clean-shape"
BROKEN_FIXTURE="$SCRIPT_DIR/fixtures/audit-broken-shape"

command -v python3 >/dev/null 2>&1 || { echo "fatal: python3 required" >&2; exit 127; }

PASS=0
FAIL=0
SKIP=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP  %s — %s\n' "$1" "$2"; SKIP=$((SKIP + 1)); }
section() { printf '\n[%s] %s\n' "$1" "$2"; }

# Recognized-gate registry (canonical from `_shared/artifact-gate-pattern.md`
# § Discipline-child-completion gates + § Cross-cutting consistency gates and
# `commands/audit.md` § Phase B + `--gate=<id>` table). Any gate result whose
# ID falls outside this registry routes to the UNCATEGORIZED-GATE-FAIL bucket,
# which fails the test. Keeps the gate-registry coverage honest as the manifest
# evolves.
#
# Drift-detection caveat (parking-lot v1.1 candidate, alongside #52-#55): this
# bucket catches drift in EMITTED-gate-ID space only. If `audit.md` adds a new
# canonical gate that this harness never emits, the registry silently stays
# stale and the test still passes. v1.1 candidate: consolidate the registry
# into a single canonical JSON manifest at `skills/_shared/gates.json`
# consumed by both audit.md's table generator and this script via stdlib
# python3.
#
# Coverage scope (per BC-7059 § Out of scope): the broken fixture exercises
# 3 of ~19 enumerated FAIL paths by design (issue spec § Out of scope:
# "Exhaustive per-gate coverage of all 35 Q29 gates" — parking-lot #52-#55).
# Expanding to a `(file, mutation, expected-fail-gate)` table or a second
# broken fixture (`audit-broken-shape-2`) is v1.1 territory.
#
# Phase B subset: `scaffold-complete` and `env-ready` are intentionally
# absent — neither is reachable from filesystem alone (scaffold-log
# integration + Linear MCP / gh auth respectively).
RECOGNIZED_GATES="preflight-complete intent-exists inventory-complete \
story-docs-complete journey-complete index-complete \
story-doc-exists story-front-matter-populated story-job-story-regex story-ac-gherkin-count \
eng-children-engineering-populated design-children-design-populated docs-children-docs-populated \
qa-children-qa-populated qa-status-signed-off qa-last-signed-off-iso8601 qa-history-row-signed-off \
inventory-story-doc-id-match index-story-doc-status-match cross-domain-deps-bidirectional"

is_recognized_gate() {
  case " $RECOGNIZED_GATES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# emit_gate <status> <gate-id> <scope> [<detail>]
# Appends one TSV line to $GATE_REPORT. If <gate-id> is unrecognized, the status
# is replaced with UNCATEGORIZED-GATE-FAIL so an outdated registry surfaces as a
# loud failure rather than silently bypassing the recognized-registry sanity check.
emit_gate() {
  local status="$1" gate="$2" scope="$3" detail="${4:-}"
  is_recognized_gate "$gate" || status="UNCATEGORIZED-GATE-FAIL"
  printf '%s\t%s\t%s\t%s\n' "$status" "$gate" "$scope" "$detail" >> "$GATE_REPORT"
}

# Check children.<field> appears in a YAML frontmatter children: block. Resets
# on the next top-level key (^[a-z]) or the closing `---` line. awk's END exit
# status is the sole match signal — no trailing grep needed.
children_field_present() {
  local doc="$1" field="$2"
  awk -v f="$field" '
    /^children:/ { in_children = 1; next }
    in_children && (/^[a-z]/ || /^---$/) { in_children = 0 }
    in_children && $0 ~ "^  "f": " { found = 1; exit }
    END { exit !found }
  ' "$doc"
}

# story_frame_present <doc> — the `story-job-story-regex` gate is FRAME-AGNOSTIC
# and LINE-FORM-AGNOSTIC (T0-4 / BC-11988). A story doc satisfies it when its
# `## Job story` section carries EITHER the human job-story frame markers
# (**When** + **I want to** + **so I can**) OR the constraint-spec frame markers
# used for non-human / infrastructure actors (**Given** + **MUST** + **so that**),
# per rubric dimension D11.
#
# The check is SECTION-SCOPED (markers may span multiple lines), not a single
# self-contained-line regex: the canonical brite-base GOLD job story spreads its
# three clauses across three blockquoted lines (`> **When** ..\n> **I want to**
# ..\n> **so I can** ..`), which a single-line `^> .*When.*I want to.*so I can`
# regex would FAIL — the original gate never matched the hand-written gold. The
# single-line form (one blockquote line carrying all three markers) still passes,
# since all three markers are then present in the section. Cosmetic blockquote /
# capitalization differences are tolerated (grep -i); the gate enforces the
# semantic FRAME, not line breaks. Gate ID unchanged (Q29 gate-stack stability).
story_frame_present() {
  local doc="$1" region
  # The frame always sits between the title and `## Acceptance criteria` — under a
  # `## Job story` heading in brite-base / brite-sites docs, or directly beneath
  # the `# Title` blockquote in the leaner audit fixtures. Scope to that region
  # (everything up to the first `## Acceptance` heading) so the check is robust to
  # both structures; if there is no `## Acceptance` heading, fall back to the whole
  # doc. The frame markers never appear in the front-matter, summary, or ACs.
  region="$(awk '/^## Acceptance/{exit} {print}' "$doc")"
  # Human job-story frame: all three bold markers present in the region.
  if printf '%s' "$region" | grep -qiE '\*\*When\*\*' \
     && printf '%s' "$region" | grep -qiE '\*\*I want to\*\*' \
     && printf '%s' "$region" | grep -qiE '\*\*so I can\*\*'; then
    return 0
  fi
  # Constraint-spec frame: Given + MUST + so that.
  if printf '%s' "$region" | grep -qiE '\*\*Given\*\*' \
     && printf '%s' "$region" | grep -qiE '\*\*MUST\*\*' \
     && printf '%s' "$region" | grep -qiE '\*\*so that\*\*'; then
    return 0
  fi
  return 1
}

# === Phase B-equivalent gate runner (filesystem-only checks) =================
# Mirrors `commands/audit.md` § Phase B for the gates that don't require Linear
# MCP. Per-flow + per-domain + cross-cutting filesystem checks only.
run_phase_b_gates() {
  local fixture="$1"
  : > "$GATE_REPORT"

  # --- preflight-complete (Q29.1) ---
  if [ -f "$fixture/.flow/config.json" ] && python3 - "$fixture" <<'PY' >/dev/null 2>&1
import json, sys
required = ('version', 'linear_project_id', 'linear_project_name',
            'linear_team_key', 'fda_first_setup_at', 'fda_plugin_version')
d = json.load(open(sys.argv[1] + '/.flow/config.json'))
sys.exit(0 if all(k in d for k in required) else 1)
PY
  then
    emit_gate PASS preflight-complete project
  else
    emit_gate FAIL preflight-complete project
  fi

  # --- intent-exists (Q29.1) ---
  if [ -f "$fixture/docs/product/intent.md" ] && \
     grep -q '^## Mission' "$fixture/docs/product/intent.md" && \
     grep -q '^## L1 review summary' "$fixture/docs/product/intent.md"; then
    emit_gate PASS intent-exists project
  else
    emit_gate FAIL intent-exists project
  fi

  # --- inventory-complete (Q29.1; section-count half only — verify-docs.sh is
  #     responsible for the orphan-flow-IDs half in real /flow:audit) ---
  local inv_domains=0
  if [ -f "$fixture/docs/product/master-flow-inventory.md" ]; then
    # awk-over-grep-c per BC-7060 (grep -c exit-1 on zero matches trips set -e).
    inv_domains="$(awk '/^## Domain:/ {n++} END {print n+0}' "$fixture/docs/product/master-flow-inventory.md")"
  fi
  if [ "$inv_domains" -ge 1 ]; then
    emit_gate PASS inventory-complete project
  else
    emit_gate FAIL inventory-complete project "domains=$inv_domains"
  fi

  # --- Per-domain + per-flow gates ---
  for domain in TEAM SHIP; do
    # journey-complete (Q29.1)
    if [ -f "$fixture/docs/product/journeys/$domain.md" ]; then
      emit_gate PASS journey-complete "domain:$domain"
    else
      emit_gate FAIL journey-complete "domain:$domain"
    fi

    # story-docs-complete (Q29.1): inventory rows count = story-doc file count
    local inv_count doc_count
    inv_count="$(awk -v dom="$domain" '
      /^## Domain:/ { in_section = ($3 == dom) ? 1 : 0; next }
      in_section && /^\| [A-Z]+-[0-9]+ \|/ { count++ }
      END { print count + 0 }
    ' "$fixture/docs/product/master-flow-inventory.md")"
    doc_count=0
    if [ -d "$fixture/docs/product/flows/$domain" ]; then
      doc_count="$(find "$fixture/docs/product/flows/$domain" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if [ "$inv_count" -gt 0 ] && [ "$inv_count" = "$doc_count" ]; then
      emit_gate PASS story-docs-complete "domain:$domain" "inventory=$inv_count docs=$doc_count"
    else
      emit_gate FAIL story-docs-complete "domain:$domain" "inventory=$inv_count docs=$doc_count"
    fi

    # Per-flow gates against story docs that exist (Q29.2 [Story] subset +
    # `children.*` populated checks for [Eng] / [Design] / [QA] / [Docs]).
    if [ -d "$fixture/docs/product/flows/$domain" ]; then
      for doc in "$fixture/docs/product/flows/$domain"/*.md; do
        [ -f "$doc" ] || continue
        local fid scope
        fid="$(basename "$doc" .md)"
        scope="flow:$fid"

        emit_gate PASS story-doc-exists "$scope"

        if grep -q '^flow_id:' "$doc" && grep -q '^status:' "$doc" && \
           grep -q '^figma:' "$doc" && grep -q '^user_docs_url:' "$doc"; then
          emit_gate PASS story-front-matter-populated "$scope"
        else
          emit_gate FAIL story-front-matter-populated "$scope"
        fi

        if story_frame_present "$doc"; then
          emit_gate PASS story-job-story-regex "$scope"
        else
          emit_gate FAIL story-job-story-regex "$scope"
        fi

        local scn
        scn="$(awk '/^Scenario:/ {n++} END {print n+0}' "$doc")"
        if [ "$scn" -ge 3 ] && [ "$scn" -le 5 ]; then
          emit_gate PASS story-ac-gherkin-count "$scope" "count=$scn"
        else
          emit_gate FAIL story-ac-gherkin-count "$scope" "count=$scn"
        fi

        # children.<discipline> populated — filesystem half of Q29.2 child gates.
        # Gate prefix matches the yaml key except for engineering → eng.
        for field in engineering design docs qa; do
          local prefix="$field"
          [ "$field" = "engineering" ] && prefix="eng"
          local gate_id="${prefix}-children-${field}-populated"
          if children_field_present "$doc" "$field"; then
            emit_gate PASS "$gate_id" "$scope"
          else
            emit_gate FAIL "$gate_id" "$scope"
          fi
        done

        # [QA] front-matter half of Q29.2 [QA] checks.
        if grep -q '^qa_status: signed-off' "$doc"; then
          emit_gate PASS qa-status-signed-off "$scope"
        else
          emit_gate FAIL qa-status-signed-off "$scope"
        fi
        if grep -qE '^qa_last_signed_off: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$doc"; then
          emit_gate PASS qa-last-signed-off-iso8601 "$scope"
        else
          emit_gate FAIL qa-last-signed-off-iso8601 "$scope"
        fi
        if grep -q '| signed-off |' "$doc"; then
          emit_gate PASS qa-history-row-signed-off "$scope"
        else
          emit_gate FAIL qa-history-row-signed-off "$scope"
        fi
      done
    fi
  done

  # --- index-complete (Q29.1): INDEX generated_at >= breadcrumb run_started_at ---
  local index_at brk_at
  index_at=""
  brk_at=""
  if [ -f "$fixture/docs/product/flows/INDEX.md" ]; then
    index_at="$(awk '/^generated_at:/ {print $2; exit}' "$fixture/docs/product/flows/INDEX.md")"
  fi
  if [ -f "$fixture/docs/plans/.flow-phase-state.json" ]; then
    brk_at="$(python3 -c "
import json, sys
try:
    print(json.load(open(sys.argv[1])).get('run_started_at', ''))
except Exception:
    print('')
" "$fixture/docs/plans/.flow-phase-state.json")"
  fi
  # Lexicographic compare is correct for ISO-8601 YYYY-MM-DDTHH:MM:SSZ format.
  if [ -n "$index_at" ] && [ -n "$brk_at" ] && [[ "$index_at" > "$brk_at" || "$index_at" == "$brk_at" ]]; then
    emit_gate PASS index-complete project "index=$index_at breadcrumb=$brk_at"
  else
    emit_gate FAIL index-complete project "index=$index_at breadcrumb=$brk_at"
  fi

  # --- Cross-cutting: inventory-story-doc-id-match + index-story-doc-status-match
  # (Q29.3, filesystem halves). Single per-doc pass parses flow_id + status once
  # and updates both mismatch flags; gates emitted in canonical order at the end. ---
  local id_mismatch=0 status_mismatch=0 fid stat
  for domain in TEAM SHIP; do
    [ -d "$fixture/docs/product/flows/$domain" ] || continue
    for doc in "$fixture/docs/product/flows/$domain"/*.md; do
      [ -f "$doc" ] || continue
      fid="$(awk '/^flow_id:/ {print $2; exit}' "$doc")"
      stat="$(awk '/^status:/ {print $2; exit}' "$doc")"
      if ! grep -qE "^\| $fid \|" "$fixture/docs/product/master-flow-inventory.md"; then
        id_mismatch=1
      fi
      if ! grep -qE "^\| $fid \| $stat " "$fixture/docs/product/flows/INDEX.md"; then
        status_mismatch=1
      fi
    done
  done
  if [ "$id_mismatch" -eq 0 ]; then
    emit_gate PASS inventory-story-doc-id-match project
  else
    emit_gate FAIL inventory-story-doc-id-match project
  fi
  if [ "$status_mismatch" -eq 0 ]; then
    emit_gate PASS index-story-doc-status-match project
  else
    emit_gate FAIL index-story-doc-status-match project
  fi
}

# === Tests ====================================================================

# ── Section 1: fixture shape preflight ──────────────────────────────────────
section "1/5" "Fixture shape preflight"
if [ -d "$CLEAN_FIXTURE" ]; then pass "clean fixture directory present"; else fail "clean fixture missing: $CLEAN_FIXTURE"; fi
if [ -d "$BROKEN_FIXTURE" ]; then pass "broken fixture directory present"; else fail "broken fixture missing: $BROKEN_FIXTURE"; fi
if [ -f "$SCRIPT_DIR/run-audit-smoke.sh" ]; then pass "run-audit-smoke.sh present (AC #2)"; else fail "run-audit-smoke.sh missing"; fi

# Required path subset on the clean fixture (AC #1: full FDA shape on disk)
for path in \
  ".flow/config.json" \
  "docs/product/intent.md" \
  "docs/product/master-flow-inventory.md" \
  "docs/product/flows/INDEX.md" \
  "docs/product/flows/TEAM/TEAM-01.md" \
  "docs/product/flows/TEAM/TEAM-02.md" \
  "docs/product/flows/TEAM/TEAM-03.md" \
  "docs/product/flows/SHIP/SHIP-01.md" \
  "docs/product/flows/SHIP/SHIP-02.md" \
  "docs/product/flows/SHIP/SHIP-03.md" \
  "docs/product/journeys/TEAM.md" \
  "docs/product/journeys/SHIP.md" \
  "docs/plans/.flow-phase-state.json" \
  "scripts/verify-docs.sh"
do
  if [ -e "$CLEAN_FIXTURE/$path" ]; then
    pass "clean fixture: $path"
  else
    fail "clean fixture missing: $path"
  fi
done

# ── Section 2: clean fixture — Phase B gate runner ─────────────────────────
section "2/5" "Phase B gates against clean fixture (expect ALL pass, 0 UNCATEGORIZED-GATE-FAIL)"
GATE_REPORT="$(mktemp)"
trap 'rm -f "$GATE_REPORT"' EXIT
# $GATE_REPORT is intentionally reused across both fixture runs (Sections 2 + 3);
# run_phase_b_gates truncates with `: >` at entry so each run starts fresh.
run_phase_b_gates "$CLEAN_FIXTURE"
CLEAN_TOTAL="$(wc -l < "$GATE_REPORT" | tr -d ' ')"
CLEAN_FAILS="$(awk -F'\t' '$1 == "FAIL"' "$GATE_REPORT" | wc -l | tr -d ' ')"
# Use awk over `grep -c` for zero-match counting: `grep -c` exits 1 on zero
# matches and would otherwise need a fragile `|| true` (BC-7060 gotcha).
CLEAN_UNCAT="$(awk -F'\t' '$1 == "UNCATEGORIZED-GATE-FAIL"' "$GATE_REPORT" | wc -l | tr -d ' ')"
if [ "$CLEAN_FAILS" -eq 0 ] && [ "$CLEAN_UNCAT" -eq 0 ]; then
  pass "clean fixture: $CLEAN_TOTAL gates, all PASS, 0 UNCATEGORIZED-GATE-FAIL → /flow:audit would exit 0"
else
  fail "clean fixture: $CLEAN_FAILS FAIL, $CLEAN_UNCAT UNCATEGORIZED-GATE-FAIL (expected 0/0)"
  awk -F'\t' '$1 != "PASS" {printf "    | %s\t%s\t%s\t%s\n",$1,$2,$3,$4}' "$GATE_REPORT"
fi

# ── Section 3: broken fixture — Phase B gate runner ─────────────────────────
section "3/5" "Phase B gates against broken fixture (expect 3 named fails, 0 UNCATEGORIZED-GATE-FAIL)"
run_phase_b_gates "$BROKEN_FIXTURE"
BROKEN_UNCAT="$(awk -F'\t' '$1 == "UNCATEGORIZED-GATE-FAIL"' "$GATE_REPORT" | wc -l | tr -d ' ')"

assert_failed() {
  local gate="$1" scope="$2"
  if awk -F'\t' -v g="$gate" -v s="$scope" '$1 == "FAIL" && $2 == g && $3 == s {found=1} END {exit !found}' "$GATE_REPORT"; then
    pass "broken fixture: gate '$gate' FAIL at scope '$scope'"
  else
    fail "broken fixture: expected '$gate' FAIL at '$scope' — not found"
  fi
}

assert_failed story-docs-complete domain:TEAM
assert_failed index-complete project
assert_failed eng-children-engineering-populated flow:SHIP-01

if [ "$BROKEN_UNCAT" -eq 0 ]; then
  pass "broken fixture: 0 UNCATEGORIZED-GATE-FAIL (gate-registry coverage holds)"
else
  fail "broken fixture: $BROKEN_UNCAT UNCATEGORIZED-GATE-FAIL — gate registry drifted"
  grep UNCATEGORIZED-GATE-FAIL "$GATE_REPORT" | sed 's/^/    | /'
fi

BROKEN_FAIL_COUNT="$(awk -F'\t' '$1 == "FAIL"' "$GATE_REPORT" | wc -l | tr -d ' ')"
# Strict count match — broken fixture is pinned to exactly 3 deliberate
# violations per the audit-broken-shape README; a 4th unintended FAIL would
# pass the per-gate assert_failed checks but break this tight count. Update
# this number iff the fixture mutation table changes (and update the README).
EXPECTED_BROKEN_FAILS=3
if [ "$BROKEN_FAIL_COUNT" -eq "$EXPECTED_BROKEN_FAILS" ]; then
  pass "broken fixture: $BROKEN_FAIL_COUNT hard-gate FAIL(s) (== $EXPECTED_BROKEN_FAILS expected) → /flow:audit would exit 1 (Q38 sub-decision 6)"
else
  fail "broken fixture: $BROKEN_FAIL_COUNT FAIL(s) (expected $EXPECTED_BROKEN_FAILS) — fixture mutations or harness drifted"
  awk -F'\t' '$1 == "FAIL" {printf "    | %s\t%s\t%s\n",$2,$3,$4}' "$GATE_REPORT"
fi

# ── Section 4: story-job-story-regex gate is frame- + line-form-agnostic ──────
# The gate must PASS the human job-story frame AND the non-human constraint-spec
# frame, in BOTH the single-line and the canonical brite-base GOLD multi-line
# blockquoted form, and FAIL a doc carrying neither. Locks the T0-4 broadening so
# a future edit cannot silently narrow it back to (a) job-story-only — which
# would fail every crawler/sitemap/cron/CDN flow authored per D11 — or (b)
# single-line-only — which would fail the multi-line GOLD format every brite-base
# / brite-sites story doc actually uses.
section "4/5" "story-job-story-regex gate accepts both frames in single- and multi-line form"
FRAME_TMP="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP"' EXIT

# Single-line forms.
printf '## Job story\n\n%s\n' '> **When** an admin opens the page, **I want to** edit it, **so I can** publish.' > "$FRAME_TMP/jobstory-1line.md"
printf '## Job story\n\n%s\n' '> **Given** a request resolves to a domain, the system **MUST** serve a sitemap, **so that** the page set is crawl-discoverable.' > "$FRAME_TMP/constraint-1line.md"
# Canonical GOLD multi-line blockquoted forms.
printf '## Job story\n\n%s\n%s\n%s\n' '> **When** an admin opens the page,' '> **I want to** edit its content blocks,' '> **so I can** publish the change before the next crawl.' > "$FRAME_TMP/jobstory-multi.md"
printf '## Job story\n\n%s\n%s\n%s\n' '> **Given** a request resolves to a published domain,' '> the system **MUST** serve a sitemap enumerating that domain'"'"'s pages,' '> **so that** the page set is crawl-discoverable per domain.' > "$FRAME_TMP/constraint-multi.md"
# Neither frame — and a decoy crawler mention OUTSIDE any frame marker.
printf '## Job story\n\n%s\n' '> This sub-flow renders a page for a crawler. No frame sentence here.' > "$FRAME_TMP/frameless.md"

for variant in jobstory-1line constraint-1line jobstory-multi constraint-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md"; then
    pass "gate accepts $variant"
  else
    fail "gate rejected a valid frame: $variant"
  fi
done
if story_frame_present "$FRAME_TMP/frameless.md"; then
  fail "gate accepted a doc with neither frame (gate is now vacuous)"
else
  pass "gate still rejects a doc carrying neither frame (decoy crawler mention ignored)"
fi

# ── Section 5: skip-with-reason for Phase A / C / LLM-runner ────────────────
section "5/5" "Phase A / C / LLM-runner gates (skipped per vslice-greenfield precedent)"
skip "Phase A verify-docs.sh per-doc stdout parsing" \
     "fixture ships a stub verifier exit-0; deep parsing belongs to verify-docs.sh's own harness"
skip "Phase C Linear MCP state checks" \
     "no Linear access from CI; covered by BC-6998 dogfood + future v1.1 headless runner"
skip "Phase C parent-l3-summary-populated cross-cutting gate" \
     "Linear-side; same reason as Phase C"
skip "Phase C linear-children-match cross-cutting gate" \
     "Linear-side; the story-doc children.* checks above are the filesystem half"
skip "Phase C milestone-subflows-table-match cross-cutting gate" \
     "Linear-side; no filesystem proxy"
skip "Phase C cross-domain-deps-bidirectional cross-cutting gate" \
     "Linear-side; doc-side parse + set-comparison exercised by run-cross-domain-deps-vslice.sh per Q29 amendment 2 / BC-10729"
skip "Phase C [Eng] sandbox HTTP smoke-test gate" \
     "network-bound; no live sandbox URL in fixture"
skip "Phase C [QA] list_comments structured-signature match" \
     "Linear-side; no comment fixture"
skip "Full /flow:audit LLM invocation (end-to-end exit-code round-trip)" \
     "/flow:audit is an LLM slash command — not directly bash-invocable; vslice-greenfield precedent"

# ── Summary ─────────────────────────────────────────────────────────────────
# Use '%s\n' format for leading-dash separator — bash 3.2 (macOS) printf treats
# a format starting with `-` as a flag and rejects it.
printf '\n%s\n' '------------------------------------------'
printf 'BC-7059 /flow:audit smoke: %d pass / %d fail / %d skip (%d hard assertions)\n' \
       "$PASS" "$FAIL" "$SKIP" "$((PASS + FAIL))"
printf '%s\n' '------------------------------------------'

if [ "$FAIL" -gt 0 ]; then
  printf '\nHarness failed.\n'
  exit 1
fi
exit 0
