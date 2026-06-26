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
story-docs-complete journey-complete journey-front-matter-populated index-complete \
story-doc-exists story-front-matter-populated story-job-story-regex story-ac-gherkin-count \
eng-children-engineering-populated design-children-design-populated docs-children-docs-populated \
qa-children-qa-populated qa-status-signed-off qa-last-signed-off-iso8601 qa-history-row-signed-off \
inventory-story-doc-id-match index-story-doc-status-match cross-domain-deps-bidirectional \
redirect-target-resolvable redirect-front-matter-valid"

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

# COLLAPSED (Q29 amendment 4 / BC-12197) — the per-repo `story_frame` mode was a
# strangler-fig migration device, NOT a permanent feature. Once ALL FDA consumer repos
# (brand-hub, brite-base, brite-labs, brite-roster, brite-sites, brite-supply-commerce,
# lseo-tool) carried `story_frame: strict` in their .flow/config.json, the `<mode>`
# param, the `story_frame_mode` reader, and the `if [ "$mode" != "strict" ]` guard were
# DELETED and the human-only frame hardcoded as the global end-state (this is that
# end-state). See memory/decision_fda_gate_narrowing_per_repo_transient.md.
#
# story_frame_present <doc> — the `story-job-story-regex` gate. Each marker is matched
# as a keyword inside a bold span (not only an exact `**keyword**` span, BC-13751).
# Accepts ONLY the human job-story frame: **When** + **I want** (trailing "to" optional)
# + **so I can**. The retired constraint-spec frame (**Given** + **MUST** + **so that**
# — non-human / infrastructure actors, per rubric D11) is rejected unconditionally:
# BC-12134 retired it from the generators, and BC-12197 retired the lenient floor that
# still accepted it at this gate. A constraint-spec-only doc now FAILs.
#
# The gate is FRAME-AGNOSTIC of line form (T0-4 / BC-11988) and SECTION-SCOPED (markers
# may span multiple lines), not a single self-contained-line regex: the canonical
# brite-base GOLD job story spreads its three clauses across three blockquoted lines
# (`> **When** ..\n> **I want to** ..\n> **so I can** ..`), which a single-line
# `^> .*When.*I want to.*so I can` regex would FAIL — the original gate never matched
# the hand-written gold. The single-line form (one blockquote line carrying all three
# markers) still passes, since all three markers are then present in the section.
# Cosmetic blockquote / capitalization differences are tolerated (grep -i); the gate
# enforces the semantic FRAME, not line breaks. Gate ID unchanged (Q29 gate-stack stability).
# _frame_marker <region> <keyword> — true if <keyword> (word-boundaried) sits inside a
# bold span (`**…**`) in <region>. Extracts each real bold run first (`grep -oE
# '\*\*[^*]+\*\*'`, non-overlapping per line, so the plain text BETWEEN two spans is
# never read as one span — guards the brite-labs false-positive where `**Doc type:**`
# … unbolded `Given … MUST … so that` … `**persona link**` would pair across the gap),
# then matches the keyword inside. Loosens marker matching from the exact `**keyword**`
# span to keyword-in-span, so the "to"-less `**I want**` passes; the bold REQUIREMENT is
# unchanged. Mirrors build_audit_report marker().
_frame_marker() { printf '%s' "$1" | grep -oE '\*\*[^*]+\*\*' | grep -qiE "\b$2\b"; }
# A doc opting out of flow enumeration (flow_index: skip) is an overview/index doc, not
# a sub-flow story doc — mirrors build_audit_report._flow_index_skipped (BC-13805).
_flow_index_skip() { grep -qiE "^flow_index:[[:space:]]*[\"']?skip[\"']?[[:space:]]*\$" "$1"; }
story_frame_present() {
  local doc="$1" region
  # The frame always sits between the title and `## Acceptance criteria` — under a
  # `## Job story` heading in brite-base / brite-sites docs, or directly beneath
  # the `# Title` blockquote in the leaner audit fixtures. Scope to that region
  # (everything up to the first `## Acceptance` heading) so the check is robust to
  # both structures; if there is no `## Acceptance` heading, fall back to the whole
  # doc. The frame markers never appear in the front-matter, summary, or ACs.
  region="$(awk '/^## Acceptance/{exit} {print}' "$doc")"
  # Human job-story frame: all three markers present (each a keyword inside a bold
  # span) in the region. The canonical human-anchored JTBD frame is the ONLY accepted
  # frame (BC-12197: the per-repo `story_frame` strangler-fig collapsed to this
  # hardcoded human-only end-state once every FDA consumer reached `story_frame: strict`;
  # the retired constraint-spec frame `Given` + `MUST` + `so that` is now rejected
  # unconditionally — a constraint-spec-only doc must be re-anchored on the human the
  # mechanism serves). `I want` (not `I want to`) so the "to"-less near-miss passes;
  # `so I can` keeps its full phrase (bare `**so**` is deferred to the brite-base epic).
  if _frame_marker "$region" 'When' \
     && _frame_marker "$region" 'I want' \
     && _frame_marker "$region" 'so I can'; then
    return 0
  fi
  return 1
}

# story_frontmatter_populated <doc> — the story-front-matter-populated gate. Requires
# the FULL canonical story frontmatter (presence, NEVER non-emptiness — honest-empty
# `personas: []` passes), delegated to the WS-A frontmatter lint
# (scripts/lib/flow_frontmatter_lint.py) so the canon is single-sourced, not re-listed
# a third time. PASS iff zero MISSING_KEY. A drift key (sub_flow_id …) fails here only
# via the canonical key it displaces going MISSING — naming the drift is the standalone
# lint's job, not this completeness gate.
#
# COLLAPSED (BC-13915) — the per-repo `frontmatter_schema` mode was a strangler-fig
# migration device (BC-12572), the structural twin of the story_frame flag. Once ALL FDA
# consumer repos (brand-hub, brite-base, brite-labs, brite-roster, brite-sites,
# brite-supply-commerce, lseo-tool) carried `frontmatter_schema: strict`, the `<mode>`
# param, the `frontmatter_schema_mode` reader, and the lenient 4-key floor were DELETED
# and the full-canon check hardcoded as the global end-state (this is that end-state),
# mirroring the story_frame collapse (BC-12197).
story_frontmatter_populated() {
  local doc="$1" missing
  missing="$(python3 - "$SCRIPT_DIR/../scripts/lib" "$doc" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
print(len(m.lint_doc(sys.argv[2], "story")["missing"]))
PY
)"
  [ "$missing" = "0" ]
}

# === Phase B-equivalent gate runner (filesystem-only checks) =================
# Mirrors `commands/audit.md` § Phase B for the gates that don't require Linear
# MCP. Per-flow + per-domain + cross-cutting filesystem checks only.
run_phase_b_gates() {
  local fixture="$1"
  : > "$GATE_REPORT"

  # Both per-flow frontmatter/story-frame gates are now unconditional: the
  # story-job-story-regex gate (human-only frame, BC-12197 / Q29 amendment 4) and the
  # story-front-matter-populated gate (full canon, BC-13915) — no per-repo story_frame or
  # frontmatter_schema mode to resolve any more.

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
      for _d in "$fixture/docs/product/flows/$domain"/*.md; do
        [ -f "$_d" ] || continue
        _flow_index_skip "$_d" && continue   # overview/index docs aren't sub-flows (BC-13805)
        doc_count=$((doc_count + 1))
      done
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
        _flow_index_skip "$doc" && continue   # skip overview/index docs (BC-13805)
        local fid scope
        fid="$(basename "$doc" .md)"
        scope="flow:$fid"

        emit_gate PASS story-doc-exists "$scope"

        if grep -qE '^doc_type:[[:space:]]*redirect[[:space:]]*$' "$doc"; then
          # Redirect stub (BC-12907): validate AS a redirect (resolvable pointer +
          # valid redirect front-matter); skip the story-frame / populated / gherkin /
          # children / qa gates. Mirrors build_audit_report.evaluate()'s redirect branch.
          local rt
          rt="$(awk -F':[[:space:]]*' '/^redirect_to:/ {print $2; exit}' "$doc")"
          # Mirror _redirect_to_resolvable's normalization (build_audit_report.py): strip
          # surrounding backticks/quotes + trailing whitespace, so a hand-authored
          # `redirect_to: \`ACL-06\`` resolves identically on this twin and in evaluate().
          rt="$(printf '%s' "$rt" | sed -e 's/[[:space:]]*$//' -e 's/^[`"'"'"']*//' -e 's/[`"'"'"']*$//')"
          # Self-pointer ($rt == this doc's own flow_id) is a no-op loop → not resolvable
          # (parity with _redirect_to_resolvable's self_fid guard).
          if [ -n "$rt" ] && [ "$rt" != "$fid" ] && ls "$fixture"/docs/product/flows/*/"$rt".md >/dev/null 2>&1; then
            emit_gate PASS redirect-target-resolvable "$scope" "redirect_to=$rt"
          else
            emit_gate FAIL redirect-target-resolvable "$scope" "redirect_to=${rt:-∅}"
          fi
          # redirect-front-matter-valid is now unconditional (BC-13915): the redirect
          # canon is enforced everywhere, no longer gated on `frontmatter_schema: strict`.
          # Single-sourced through flow_frontmatter_lint (redirect mode) so this twin
          # fails on BOTH a MISSING canon key AND a DRIFT key — byte-for-byte the
          # predicate build_audit_report.evaluate() / run_fda_ci_audit use (BC-13148
          # two-impl lockstep; a presence-only loop here would silently pass a redirect
          # carrying a drift key like `sub_flow_id` that the Python gates reject).
          local rdefects
          rdefects="$(python3 - "$SCRIPT_DIR/../scripts/lib" "$doc" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
r = m.lint_doc(sys.argv[2], "redirect")
print(len(r["missing"]) + len(r["drift"]))
PY
)"
          if [ "$rdefects" = "0" ]; then
            emit_gate PASS redirect-front-matter-valid "$scope"
          else
            emit_gate FAIL redirect-front-matter-valid "$scope" "canon defects=$rdefects"
          fi
          continue
        fi

        if story_frontmatter_populated "$doc"; then
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

  # --- journey-front-matter-populated (Q29.1 / Q29 amendment 6, BC-13935) ---
  # Journey frontmatter against the ADR-033 canon over ALL journeys/*.md (the
  # all-journeys model — the same _journey_docs set build_audit_report.evaluate() and
  # run_fda_ci_audit iterate), NOT just the per-domain journeys/{domain}.md that
  # journey-complete checks. Single-sourced through flow_frontmatter_lint(journey) so
  # this twin fails on BOTH a MISSING canon key AND a DRIFT key — byte-for-byte the
  # predicate the Python gates use (BC-13148 two-impl lockstep; a presence-only loop
  # here would silently pass a journey carrying a drift key the Python gates reject).
  if [ -d "$fixture/docs/product/journeys" ]; then
    for jdoc in "$fixture/docs/product/journeys"/*.md; do
      [ -f "$jdoc" ] || continue
      _flow_index_skip "$jdoc" && continue   # skip overview/index docs (BC-13819)
      local jstem jdefects
      jstem="$(basename "$jdoc" .md)"
      jdefects="$(python3 - "$SCRIPT_DIR/../scripts/lib" "$jdoc" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
r = m.lint_doc(sys.argv[2], "journey")
print(len(r["missing"]) + len(r["drift"]))
PY
)"
      if [ "$jdefects" = "0" ]; then
        emit_gate PASS journey-front-matter-populated "journey:$jstem"
      else
        emit_gate FAIL journey-front-matter-populated "journey:$jstem" "canon defects=$jdefects"
      fi
    done
  fi

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
      _flow_index_skip "$doc" && continue   # skip overview/index docs (BC-13805)
      fid="$(awk '/^flow_id:/ {print $2; exit}' "$doc")"
      stat="$(awk '/^status:/ {print $2; exit}' "$doc")"
      # Guard emptiness to mirror evaluate()'s `if fid and ...` / `if fid and stat and ...`
      # (build_audit_report.py): a redirect stub (BC-12907) has a flow_id but NO status, so
      # it must be SKIPPED by the status-match (not matched against an INDEX row it has no
      # status for) — else an empty $stat spuriously trips status_mismatch on every redirect.
      if [ -n "$fid" ] && ! grep -qE "^\| $fid \|" "$fixture/docs/product/master-flow-inventory.md"; then
        id_mismatch=1
      fi
      if [ -n "$fid" ] && [ -n "$stat" ] && ! grep -qE "^\| $fid \| $stat " "$fixture/docs/product/flows/INDEX.md"; then
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

# ── Section 2-redirect: redirect-stub gate (BC-12907) ────────────────────────
# A doc_type:redirect stub is validated AS a redirect (resolvable pointer; story gates
# skipped) — mirrors build_audit_report.evaluate(). Dedicated temp repo so the clean /
# broken fixtures stay redirect-free (the eval oracle cross-checks only those two).
section "2-redirect" "redirect-stub gate: valid alias skips story-frame; dangling fails"
RDIR="$(mktemp -d)"; cp -R "$CLEAN_FIXTURE/." "$RDIR/"
RALIAS="$(ls "$RDIR"/docs/product/flows/*/*.md | head -1)"
RTGT="$(basename "$(ls "$RDIR"/docs/product/flows/*/*.md | tail -1)" .md)"
RAFID="$(basename "$RALIAS" .md)"; RADOM="$(basename "$(dirname "$RALIAS")")"
printf -- '---\nflow_id: %s\ndomain: %s\ndoc_type: redirect\nredirect_to: %s\nintent: x\nlast_reviewed: y\n---\n# %s (redirect)\n' "$RAFID" "$RADOM" "$RTGT" "$RAFID" > "$RALIAS"
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="PASS" && $2=="redirect-target-resolvable" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "valid redirect → redirect-target-resolvable PASS at flow:$RAFID"
else
  fail "valid redirect: redirect-target-resolvable not PASS at flow:$RAFID"
fi
if awk -F'\t' -v s="flow:$RAFID" '$2=="story-job-story-regex" && $3==s{seen=1} END{exit seen}' "$GATE_REPORT"; then
  pass "redirect doc SKIPS story-job-story-regex (no story gate emitted)"
else
  fail "redirect doc still emitted story-job-story-regex"
fi
# Cross-cutting parity (BC-12907 review-fix): a redirect stub has NO status field, so the
# project-scope index-story-doc-status-match gate must SKIP it (Python guards `fid and stat`)
# rather than emit a spurious FAIL. This section previously asserted only redirect gates,
# never all-pass — which hid the bash twin's missing `[ -n "$stat" ]` guard (Greptile #487).
if awk -F'\t' '$1=="FAIL" && $2=="index-story-doc-status-match"{bad=1} END{exit bad}' "$GATE_REPORT"; then
  pass "redirect stub (no status) does NOT trip index-story-doc-status-match (Python↔bash parity)"
else
  fail "redirect stub spuriously FAILs index-story-doc-status-match (bash twin missing \$stat guard)"
fi
if awk -F'\t' '$1=="FAIL" && $2=="inventory-story-doc-id-match"{bad=1} END{exit bad}' "$GATE_REPORT"; then
  pass "redirect stub does NOT trip inventory-story-doc-id-match (fid is in inventory)"
else
  fail "redirect stub spuriously FAILs inventory-story-doc-id-match"
fi
python3 - "$RALIAS" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r'^redirect_to:.*$', 'redirect_to: NOPE-99', s, count=1, flags=re.M))
PY
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="FAIL" && $2=="redirect-target-resolvable" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "dangling redirect_to → redirect-target-resolvable FAIL"
else
  fail "dangling redirect not caught"
fi
# Backtick/quote parity (BC-12907 review-fix): a hand-authored `redirect_to: `TGT`` must
# normalize + resolve on this twin exactly as _redirect_to_resolvable does in evaluate().
python3 - "$RALIAS" "$RTGT" <<'PY'
import re, sys
p, tgt = sys.argv[1], sys.argv[2]; s = open(p).read()
open(p, "w").write(re.sub(r'^redirect_to:.*$', 'redirect_to: `%s`' % tgt, s, count=1, flags=re.M))
PY
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="PASS" && $2=="redirect-target-resolvable" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "backticked redirect_to normalizes + resolves (Python↔bash parity)"
else
  fail "backticked redirect_to not resolved on bash twin (parity gap)"
fi
# Self-pointer (BC-12907 review-fix): redirect_to == own flow_id is a no-op loop → FAIL.
python3 - "$RALIAS" "$RAFID" <<'PY'
import re, sys
p, fid = sys.argv[1], sys.argv[2]; s = open(p).read()
open(p, "w").write(re.sub(r'^redirect_to:.*$', 'redirect_to: %s' % fid, s, count=1, flags=re.M))
PY
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="FAIL" && $2=="redirect-target-resolvable" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "self-pointer redirect_to (== own flow_id) → redirect-target-resolvable FAIL"
else
  fail "self-pointer redirect not caught (no-op loop slipped through)"
fi
# Redirect front-matter (BC-12907; unconditional since BC-13915): a redirect missing a
# REDIRECT_CANON key hard-fails redirect-front-matter-valid everywhere (mirrors
# evaluate()/CI-runner — no longer gated on `frontmatter_schema: strict`).
printf -- '---\nflow_id: %s\ndomain: %s\ndoc_type: redirect\nredirect_to: %s\nlast_reviewed: y\n---\n# %s (redirect, missing intent)\n' "$RAFID" "$RADOM" "$RTGT" "$RAFID" > "$RALIAS"
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="FAIL" && $2=="redirect-front-matter-valid" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "redirect missing canon key (intent) → redirect-front-matter-valid FAIL"
else
  fail "redirect missing-key not caught on bash twin"
fi
# DRIFT parity (BC-13148): a redirect with ALL canon keys present PLUS a drift key
# (sub_flow_id) must FAIL — the bash twin checks DRIFT, not just presence, so it can't
# silently pass a doc the Python evaluate()/CI-runner reject (Greptile #496 P2).
printf -- '---\nflow_id: %s\ndomain: %s\ndoc_type: redirect\nredirect_to: %s\nsub_flow_id: %s\nintent: x\nlast_reviewed: y\n---\n# %s (redirect, drift key)\n' "$RAFID" "$RADOM" "$RTGT" "$RAFID" "$RAFID" > "$RALIAS"
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="FAIL" && $2=="redirect-front-matter-valid" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "redirect with drift key (sub_flow_id) → redirect-front-matter-valid FAIL (drift parity w/ Python)"
else
  fail "redirect drift key slipped through the bash twin (presence-only regression)"
fi
rm -rf "$RDIR"

# ── Section 2-skip: flow_index:skip excludes overview docs (BC-13805) ─────────
# Bash-twin parity with build_audit_report._story_docs: a doc with `flow_index: skip`
# is an overview/index, not a sub-flow — the twin must NOT emit per-flow gates for it
# (even with content that would otherwise fail).
section "2-skip" "flow_index:skip doc excluded from per-flow gates (Python↔bash parity)"
SDIR="$(mktemp -d)"; cp -R "$CLEAN_FIXTURE/." "$SDIR/"
SDOM="$(basename "$(dirname "$(ls "$SDIR"/docs/product/flows/*/*.md | head -1)")")"
printf -- '---\ndomain: %s\nflow_index: skip\n---\n# Overview (not a sub-flow)\nNo job story.\n' "$SDOM" \
  > "$SDIR/docs/product/flows/$SDOM/overview.md"
run_phase_b_gates "$SDIR"
if awk -F'\t' '$3=="flow:overview"{seen=1} END{exit seen}' "$GATE_REPORT"; then
  pass "no per-flow gates emitted for the flow_index:skip doc"
else
  fail "bash twin audited a flow_index:skip doc (parity gap)"
fi
rm -rf "$SDIR"

# ── Section 2-journey: journey-front-matter-populated gate (BC-13935) ─────────
# The all-journeys journey-frontmatter gate (Q29 amendment 6) lints EVERY journeys/*.md
# against the ADR-033 canon — bringing the Phase-B twin up to parity with
# run_fda_ci_audit's journey lint (CI↔/flow:audit lockstep, BC-13148). Dedicated temp
# repo so the clean/broken fixtures (the eval oracle's only two) stay full-canon.
# Single-sourced through flow_frontmatter_lint(journey) → fails on MISSING and DRIFT.
section "2-journey" "journey-front-matter-populated: full-canon passes; missing/drift key fails"
JDIR="$(mktemp -d)"; cp -R "$CLEAN_FIXTURE/." "$JDIR/"
JRNY="$JDIR/docs/product/journeys/TEAM.md"
# Positive control: the unmutated clean journey passes the gate.
run_phase_b_gates "$JDIR"
if awk -F'\t' '$1=="PASS" && $2=="journey-front-matter-populated" && $3=="journey:TEAM"{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "full-canon journey → journey-front-matter-populated PASS at journey:TEAM"
else
  fail "full-canon journey did not PASS journey-front-matter-populated"
fi
# MISSING parity: drop an ADR-033 canon key (display_name) → FAIL.
python3 - "$JRNY" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r'^display_name:.*\n', '', s, count=1, flags=re.M))
PY
run_phase_b_gates "$JDIR"
if awk -F'\t' '$1=="FAIL" && $2=="journey-front-matter-populated" && $3=="journey:TEAM"{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "journey missing canon key (display_name) → journey-front-matter-populated FAIL"
else
  fail "journey missing-key not caught on bash twin"
fi
# DRIFT parity (BC-13148): restore full canon + inject a drift key (linear_project_id,
# dropped by ADR-033) INSIDE the frontmatter → FAIL. The twin checks DRIFT, not just
# presence, so it can't silently pass a journey the Python evaluate()/CI-runner reject
# (the Greptile #496 P2 lesson, journey side).
cp -f "$CLEAN_FIXTURE/docs/product/journeys/TEAM.md" "$JRNY"
python3 - "$JRNY" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r'^(---\n)', r'\1linear_project_id: dead-beef\n', s, count=1, flags=re.M))
PY
run_phase_b_gates "$JDIR"
if awk -F'\t' '$1=="FAIL" && $2=="journey-front-matter-populated" && $3=="journey:TEAM"{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "journey with drift key (linear_project_id) → journey-front-matter-populated FAIL (drift parity w/ Python)"
else
  fail "journey drift key slipped through the bash twin (presence-only regression)"
fi
rm -rf "$JDIR"

# ── Section 3: broken fixture — Phase B gate runner ─────────────────────────
section "3/5" "Phase B gates against broken fixture (expect 4 named fails, 0 UNCATEGORIZED-GATE-FAIL)"
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
# SHIP-01's missing children.engineering is a STORY_CANON key, so since BC-13915
# hardcoded the full-canon floor it trips story-front-matter-populated too (one
# structural omission, two gates). The other broken docs are full canon.
assert_failed story-front-matter-populated flow:SHIP-01

if [ "$BROKEN_UNCAT" -eq 0 ]; then
  pass "broken fixture: 0 UNCATEGORIZED-GATE-FAIL (gate-registry coverage holds)"
else
  fail "broken fixture: $BROKEN_UNCAT UNCATEGORIZED-GATE-FAIL — gate registry drifted"
  grep UNCATEGORIZED-GATE-FAIL "$GATE_REPORT" | sed 's/^/    | /'
fi

BROKEN_FAIL_COUNT="$(awk -F'\t' '$1 == "FAIL"' "$GATE_REPORT" | wc -l | tr -d ' ')"
# Strict count match — broken fixture is pinned to exactly 4 hard-gate FAILs: the 3
# deliberate structural violations per the audit-broken-shape README PLUS the
# story-front-matter-populated FAIL that SHIP-01's missing children.engineering now
# also trips (BC-13915 hardcoded full-canon — children.engineering is a STORY_CANON
# key). A 5th unintended FAIL would pass the per-gate assert_failed checks but break
# this tight count. Update this number iff the fixture mutation table changes (and
# update the README).
EXPECTED_BROKEN_FAILS=4
if [ "$BROKEN_FAIL_COUNT" -eq "$EXPECTED_BROKEN_FAILS" ]; then
  pass "broken fixture: $BROKEN_FAIL_COUNT hard-gate FAIL(s) (== $EXPECTED_BROKEN_FAILS expected) → /flow:audit would exit 1 (Q38 sub-decision 6)"
else
  fail "broken fixture: $BROKEN_FAIL_COUNT FAIL(s) (expected $EXPECTED_BROKEN_FAILS) — fixture mutations or harness drifted"
  awk -F'\t' '$1 == "FAIL" {printf "    | %s\t%s\t%s\n",$2,$3,$4}' "$GATE_REPORT"
fi

# ── Section 4: story-job-story-regex gate is human-frame-only + line-form-agnostic ──
# The gate must PASS the human job-story frame in BOTH the single-line and the
# canonical brite-base GOLD multi-line blockquoted form, and FAIL both the retired
# constraint-spec frame (BC-12197 collapsed the per-repo lenient floor that once
# accepted it — the hardcoded human-only end-state) and a doc carrying neither frame.
# Locks the human-only end-state + the T0-4 line-form broadening so a future edit
# cannot silently (a) re-accept the constraint-spec frame, or (b) narrow to
# single-line-only — which would fail the multi-line GOLD format every brite-base /
# brite-sites story doc actually uses.
section "4/5" "story-job-story-regex gate accepts the human frame (both line forms), rejects constraint-spec + frameless"
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

# Human job-story frame PASSes in both line forms.
for variant in jobstory-1line jobstory-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md"; then
    pass "gate accepts the human job-story frame ($variant)"
  else
    fail "gate rejected a valid human frame: $variant"
  fi
done
# Retired constraint-spec frame FAILs in both line forms (human-only end-state).
for variant in constraint-1line constraint-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md"; then
    fail "gate accepted the retired constraint-spec frame ($variant) — human-only end-state not enforced"
  else
    pass "gate rejects the retired constraint-spec frame ($variant)"
  fi
done
if story_frame_present "$FRAME_TMP/frameless.md"; then
  fail "gate accepted a doc with neither frame (gate is now vacuous)"
else
  pass "gate still rejects a doc carrying neither frame (decoy crawler mention ignored)"
fi

# ── Section 4b: marker-form brittleness — core keyword INSIDE a bold span ──────
# BC-13751. story_frame_present matches a marker's keyword inside a bold span, not
# only as the exact `**keyword**` span — so the "to"-less `**I want**` human near-miss
# is recognized (valid human frames previously flagged as false-negatives across
# supply/roster). The bold REQUIREMENT is unchanged (unbolded prose never passes) and
# keywords are word-boundaried. The negative controls confirm the keyword-in-span
# loosening does NOT over-widen: a phrase-bolded constraint marker (`**the system
# MUST**`) carries no human frame and is rejected (BC-12197 human-only end-state), as
# are the bold-requirement, truncated-`so`, and word-boundary near-misses. Mirror of
# test_build_audit_report.sh § 2b.
section "4b/5" "marker-form brittleness: keyword-in-bold-span (BC-13751)"
printf '## Job story\n\n%s\n' '> **Given** a req, **the system MUST** serve, **so that** crawlable.' > "$FRAME_TMP/phrase-must.md"
printf '## Job story\n\n%s\n' '> **When** x, **I want** y, **so I can** z.' > "$FRAME_TMP/iwant-no-to.md"
printf '## Job story\n\n%s\n' '> Given a crawler requests the page, the system MUST serve a sitemap, so that pages rank.' > "$FRAME_TMP/unbolded.md"
printf '## Job story\n\n%s\n' '> **When** x, **I want to** y, **so** z.' > "$FRAME_TMP/so-trunc.md"
printf '## Job story\n\n%s\n' '> **Given** a req, **mustard glaze** is applied, **so that** it works.' > "$FRAME_TMP/mustard.md"
printf '## Job story\n\n%s\n' '> **When** x, **I wanted to** y, **so I can** z.' > "$FRAME_TMP/iwanted.md"
# GAP control (the real brite-labs false-positive): two unrelated bold spans with
# unbolded Given/MUST/so-that prose BETWEEN them must NOT read as one bold span.
printf '## Job story\n\n%s\n' '> **Doc type:** Constraint spec. Given a req, the system MUST serve, so that crawlable. Beneficiary: **[Persona](p.md)**' > "$FRAME_TMP/gap.md"
# Positive: the human "to"-less near-miss is accepted (keyword-in-bold-span, BC-13751).
if story_frame_present "$FRAME_TMP/iwant-no-to.md"; then pass "accepts **I want** human near-miss (BC-13751 keyword-in-span)"; else fail "rejected **I want** human near-miss"; fi
# Negatives: none carry the human frame, so all must FAIL — the phrase-bolded constraint
# marker (no human frame), the unbolded prose (bold required), the truncated **so**, the
# word-boundary near-misses (mustard ≠ MUST, iwanted ≠ I want), and the brite-labs
# cross-span false-positive (gap).
for v in phrase-must unbolded so-trunc mustard iwanted gap; do
  if story_frame_present "$FRAME_TMP/$v.md"; then fail "WRONGLY accepted $v (no human frame present)"; else pass "rejects $v"; fi
done

# ── Section 4c: constraint-spec frame FAILs story-job-story-regex through run_phase_b_gates ─
# The unit assertions above pin the function; this pins the WIRING — that a
# constraint-spec doc actually FAILs the gate via run_phase_b_gates (guards against a
# "function correct but never wired" silent no-op). Copy the clean fixture, swap ONE
# doc's human frame for a constraint-spec frame (only the frame line changes → only
# story-job-story-regex can flip), then assert that doc FAILs the gate. No config to set
# — story_frame is hardcoded human-only (BC-12197), so the constraint-spec doc FAILs
# unconditionally.
section "4c/5" "constraint-spec frame FAILs story-job-story-regex through run_phase_b_gates"
CONSTRAINT_FIX="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$CONSTRAINT_FIX"' EXIT
cp -R "$CLEAN_FIXTURE/." "$CONSTRAINT_FIX/"
CONSTRAINT_DOC="$CONSTRAINT_FIX/docs/product/flows/TEAM/TEAM-01.md"
python3 - "$CONSTRAINT_DOC" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
new, _ = re.subn(
    r'^> \*\*When\*\*.*$',
    '> **Given** a team admin signs in, the system **MUST** walk through setup, **so that** teammates can be invited.',
    s, count=1, flags=re.M)
open(p, 'w').write(new)
PY
# Guard: confirm the swap produced a PURE constraint-spec doc — the `**MUST**`
# marker present AND zero residual human markers (`**When**` / `**I want to**` /
# `**so I can**`). TEAM-01's frame is a single line, so the `^> **When**.*$` subn
# replaces the whole line and leaves no orphans; this guard makes that explicit AND
# fails LOUDLY if the fixture ever becomes multi-line (then the single-line subn
# would strand the I-want-to / so-I-can lines → hybrid doc). Defeats both a vacuous
# pass (swap no-op) and a mixed-marker fixture. (Human markers are bold-wrapped only in
# the frame; Gherkin `When` in scenarios is unbolded, so a whole-doc scan is safe.)
if grep -q 'the system \*\*MUST\*\*' "$CONSTRAINT_DOC" \
   && ! grep -qiE '\*\*When\*\*|\*\*I want to\*\*|\*\*so I can\*\*' "$CONSTRAINT_DOC"; then
  pass "e2e setup: TEAM-01 swapped to a pure constraint-spec doc (no residual human markers)"
else
  fail "e2e setup: swap left residual human markers or didn't take — e2e assertion is invalid"
fi

# The constraint-spec doc FAILs story-job-story-regex end-to-end (no config needed —
# the gate is hardcoded human-only).
run_phase_b_gates "$CONSTRAINT_FIX"
assert_failed story-job-story-regex flow:TEAM-01

# ── Section 4e: story-front-matter-populated requires full canon (unconditional) ─
# BC-13915: story-front-matter-populated now requires the FULL canonical story
# frontmatter UNCONDITIONALLY (presence, not non-emptiness) — the per-repo
# `frontmatter_schema` flag + its lenient 4-key floor were collapsed once every consumer
# converged (the structural twin of the story_frame collapse). The clean fixture's docs
# are now full canon (so Section 2 already pins the PASS path end-to-end); this section
# pins the FAIL path: a doc stripped back to the lean 4-key shape FAILs the gate, while a
# full-canon sibling PASSes. No config to set — the gate is hardcoded full-canon.
section "4e/5" "story-front-matter-populated requires full canon (a lean doc FAILs)"
SCHEMA_FIX="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$CONSTRAINT_FIX" "$SCHEMA_FIX"' EXIT
cp -R "$CLEAN_FIXTURE/." "$SCHEMA_FIX/"
# Downgrade TEAM-02 to the lean 4-key floor by stripping the canon keys the full fixture
# now carries — making it incomplete frontmatter.
SCHEMA_DOC="$SCHEMA_FIX/docs/product/flows/TEAM/TEAM-02.md"
python3 - "$SCHEMA_DOC" <<'PY'
import sys, re
p = sys.argv[1]
strip = {"domain","parent_issue","personas","related_flows","sandbox_url","staging_url",
         "real_app_url","e2e_test","eng_status","design_status","docs_status","intent"}
out = []
for l in open(p):
    m = re.match(r'^([a-z_]+):', l)
    if m and m.group(1) in strip:
        continue
    out.append(l)
open(p, "w").write("".join(out))
PY
# Guard: confirm the downgraded doc now FAILs the full canon while the untouched sibling
# (full canon) still passes — defeats a vacuous pass if the strip no-ops.
if ! story_frontmatter_populated "$SCHEMA_DOC" \
   && story_frontmatter_populated "$SCHEMA_FIX/docs/product/flows/TEAM/TEAM-01.md"; then
  pass "e2e setup: TEAM-02 downgraded to lean; TEAM-01 still full canon (separable)"
else
  fail "e2e setup: strip no-op or TEAM-01 already lean — e2e assertions invalid"
fi

run_phase_b_gates "$SCHEMA_FIX"
if awk -F'\t' '$1=="FAIL" && $2=="story-front-matter-populated" && $3=="flow:TEAM-02"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "lean TEAM-02 FAILs story-front-matter-populated (4-key floor insufficient — full canon required)"
else
  fail "lean TEAM-02 did not FAIL — full-canon enforcement not wired"
fi
if awk -F'\t' '$1=="PASS" && $2=="story-front-matter-populated" && $3=="flow:TEAM-01"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "full-canon TEAM-01 PASSes story-front-matter-populated"
else
  fail "full-canon TEAM-01 did not PASS — gate rejects a complete doc"
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
