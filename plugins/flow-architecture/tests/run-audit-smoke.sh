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

# TRANSIENT (Q29 amendment 3 / BC-11983) — the per-repo `story_frame` mode below is
# a strangler-fig migration device, NOT a permanent feature. Once ALL 7 WS-E consumer
# repos (brite-sites, brite-roster, brand-hub, brite-labs-site, brite-supply-react,
# brite-pim, brite-lseo) carry `story_frame: strict` in their .flow/config.json, DELETE
# the `<mode>` param + `story_frame_mode` + the `if [ "$mode" != "strict" ]` guard and
# hardcode the human-only frame (the global end-state). Tracked on a BC-11983 child;
# see memory/decision_fda_gate_narrowing_per_repo_transient.md. Do not let it ossify.
#
# story_frame_present <doc> [<mode>] — the `story-job-story-regex` gate. Each marker
# is matched as a keyword inside a bold span (not only an exact `**keyword**` span,
# BC-13751). Always accepts the human job-story frame: **When** + **I want** (trailing
# "to" optional) + **so I can**. The retired constraint-spec frame (**Given** +
# **MUST** + **so that** — **MUST** also matches inside e.g. **the system MUST** —
# non-human / infrastructure actors, per rubric D11) is accepted ONLY under the LENIENT floor
# (BC-12134) — the default. When <mode> is `strict` (per-repo gate-narrowing, the
# consumer repo's .flow/config.json `story_frame: strict`, Q29 amendment 3) the
# constraint-spec frame NO LONGER satisfies the gate, so a constraint-spec-only doc
# FAILs. <mode> defaults to `lenient`, so every existing caller is unchanged.
#
# Lenient is FRAME-AGNOSTIC and LINE-FORM-AGNOSTIC (T0-4 / BC-11988); strict is
# frame-narrowing but still LINE-FORM-AGNOSTIC. The check is SECTION-SCOPED
# (markers may span multiple lines), not a single self-contained-line regex: the
# canonical brite-base GOLD job story spreads its three clauses across three
# blockquoted lines (`> **When** ..\n> **I want to** ..\n> **so I can** ..`), which
# a single-line `^> .*When.*I want to.*so I can` regex would FAIL — the original
# gate never matched the hand-written gold. The single-line form (one blockquote
# line carrying all three markers) still passes, since all three markers are then
# present in the section. Cosmetic blockquote / capitalization differences are
# tolerated (grep -i); the gate enforces the semantic FRAME, not line breaks. Gate
# ID unchanged across both modes (Q29 gate-stack stability).
# _frame_marker <region> <keyword> — true if <keyword> (word-boundaried) sits inside a
# bold span (`**…**`) in <region>. Extracts each real bold run first (`grep -oE
# '\*\*[^*]+\*\*'`, non-overlapping per line, so the plain text BETWEEN two spans is
# never read as one span — guards the brite-labs false-positive where `**Doc type:**`
# … unbolded `Given … MUST … so that` … `**persona link**` would pair across the gap),
# then matches the keyword inside. Loosens marker matching from the exact `**keyword**`
# span to keyword-in-span, so phrase-bolded `**the system MUST**` / the "to"-less
# `**I want**` pass; the bold REQUIREMENT is unchanged. Mirrors build_audit_report marker().
_frame_marker() { printf '%s' "$1" | grep -oE '\*\*[^*]+\*\*' | grep -qiE "\b$2\b"; }
story_frame_present() {
  local doc="$1" mode region
  # Normalize <mode> to lowercase (bash-3.2-safe via tr, NOT ${2,,}) so the function
  # is self-consistent with the case-insensitive `story_frame` contract and safe to
  # call independently: a caller passing `STRICT`/`Strict` narrows correctly instead
  # of silently falling through to lenient (a fail-OPEN footgun on a frame-enforcement
  # gate). Only the literal lowercase `strict` narrows; everything else → lenient,
  # mirroring story_frame_mode's fail-safe. Default (no arg) = lenient.
  mode="$(printf '%s' "${2:-lenient}" | tr '[:upper:]' '[:lower:]')"
  # The frame always sits between the title and `## Acceptance criteria` — under a
  # `## Job story` heading in brite-base / brite-sites docs, or directly beneath
  # the `# Title` blockquote in the leaner audit fixtures. Scope to that region
  # (everything up to the first `## Acceptance` heading) so the check is robust to
  # both structures; if there is no `## Acceptance` heading, fall back to the whole
  # doc. The frame markers never appear in the front-matter, summary, or ACs.
  region="$(awk '/^## Acceptance/{exit} {print}' "$doc")"
  # Human job-story frame: all three markers present (each a keyword inside a bold
  # span) in the region. The canonical human-anchored JTBD frame — always accepted, in
  # either mode. `I want` (not `I want to`) so the "to"-less near-miss passes; `so I can`
  # keeps its full phrase (bare `**so**` is deferred to the brite-base epic).
  if _frame_marker "$region" 'When' \
     && _frame_marker "$region" 'I want' \
     && _frame_marker "$region" 'so I can'; then
    return 0
  fi
  # Constraint-spec frame: Given + MUST + so that. The RETIRED non-human / system
  # frame — accepted only under the lenient floor so not-yet-reframed consumer
  # repos keep passing mid-migration. Under `strict` it is rejected (the doc must
  # be re-anchored on the human the mechanism serves). `MUST` matched inside its bold
  # span recognizes phrase-bolded `**the system MUST**`.
  if [ "$mode" != "strict" ]; then
    if _frame_marker "$region" 'Given' \
       && _frame_marker "$region" 'MUST' \
       && _frame_marker "$region" 'so that'; then
      return 0
    fi
  fi
  return 1
}

# story_frame_mode <fixture> — resolve a consumer repo's story-frame strictness
# from .flow/config.json `story_frame` (Q29 amendment 3 / BC-11983). Returns
# `strict` ONLY for an explicit string `story_frame: "strict"` (case-insensitive);
# every other state — file absent, field absent, unrecognized value, parse error —
# resolves to `lenient`. Fail-safe by construction: the gate can only ever
# accidentally STAY permissive, never accidentally narrow. python3 is required
# (checked at top); the try/except always prints + exits 0, so `set -e` is safe.
story_frame_mode() {
  local fixture="$1" mode="lenient"
  [ -f "$fixture/.flow/config.json" ] || { printf 'lenient'; return 0; }
  mode="$(python3 - "$fixture/.flow/config.json" <<'PY'
import json, sys
try:
    v = json.load(open(sys.argv[1])).get('story_frame')
    print('strict' if isinstance(v, str) and v.lower() == 'strict' else 'lenient')
except Exception:
    print('lenient')
PY
)"
  printf '%s' "$mode"
}

# frontmatter_schema_mode <fixture> — resolve a consumer repo's frontmatter-schema
# strictness from .flow/config.json `frontmatter_schema` (BC-12572). Returns
# `strict` ONLY for an explicit string `frontmatter_schema: "strict"`
# (case-insensitive); every other state — file absent, field absent, unrecognized
# value, parse error — resolves to `lenient`. Same fail-safe construction as
# story_frame_mode (the gate can only ever STAY permissive, never accidentally
# narrow). Per-repo strangler-fig: repos flip to `strict` as their story docs are
# migrated to full canon; once all WS-E repos converge, `strict` becomes the
# hardcoded default + this flag is deleted (tracked on a BC-11983 child).
frontmatter_schema_mode() {
  local fixture="$1" mode="lenient"
  [ -f "$fixture/.flow/config.json" ] || { printf 'lenient'; return 0; }
  mode="$(python3 - "$fixture/.flow/config.json" <<'PY'
import json, sys
try:
    v = json.load(open(sys.argv[1])).get('frontmatter_schema')
    print('strict' if isinstance(v, str) and v.lower() == 'strict' else 'lenient')
except Exception:
    print('lenient')
PY
)"
  printf '%s' "$mode"
}

# story_frontmatter_populated <doc> [<mode>] — the story-front-matter-populated gate
# (BC-12572 config-gated widening). LENIENT (default): the 4-key presence floor
# (flow_id/status/figma/user_docs_url) — today's behavior, byte-unchanged. STRICT:
# the FULL 20-key story canon must be present (presence, NEVER non-emptiness —
# honest-empty `personas: []` passes), delegated to the WS-A frontmatter lint
# (scripts/lib/flow_frontmatter_lint.py) so the canon is single-sourced, not
# re-listed a third time. PASS iff zero MISSING_KEY. A drift key (sub_flow_id …)
# fails here only via the canonical key it displaces going MISSING — naming the
# drift is the standalone lint's job, not this completeness gate. <mode> defaults
# to lenient so every existing caller is unchanged.
story_frontmatter_populated() {
  local doc="$1" mode
  mode="$(printf '%s' "${2:-lenient}" | tr '[:upper:]' '[:lower:]')"
  if [ "$mode" = "strict" ]; then
    local missing
    missing="$(python3 - "$SCRIPT_DIR/../scripts/lib" "$doc" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import flow_frontmatter_lint as m
print(len(m.lint_doc(sys.argv[2], "story")["missing"]))
PY
)"
    [ "$missing" = "0" ]
    return
  fi
  grep -q '^flow_id:' "$doc" && grep -q '^status:' "$doc" \
    && grep -q '^figma:' "$doc" && grep -q '^user_docs_url:' "$doc"
}

# === Phase B-equivalent gate runner (filesystem-only checks) =================
# Mirrors `commands/audit.md` § Phase B for the gates that don't require Linear
# MCP. Per-flow + per-domain + cross-cutting filesystem checks only.
run_phase_b_gates() {
  local fixture="$1"
  : > "$GATE_REPORT"

  # Per-repo story-frame strictness (Q29 amendment 3): lenient unless the consumer
  # repo's .flow/config.json sets `story_frame: strict`. Threaded into the
  # story-job-story-regex gate below.
  local frame_mode
  frame_mode="$(story_frame_mode "$fixture")"
  # Per-repo frontmatter-schema strictness (BC-12572): lenient unless the consumer
  # repo's .flow/config.json sets `frontmatter_schema: strict`. Threaded into the
  # story-front-matter-populated gate below.
  local fm_schema_mode
  fm_schema_mode="$(frontmatter_schema_mode "$fixture")"

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
          if [ "$fm_schema_mode" = "strict" ]; then
            local rmiss=""
            for k in flow_id domain doc_type redirect_to intent last_reviewed; do
              grep -qE "^$k:" "$doc" || rmiss="$rmiss $k"
            done
            if [ -z "$rmiss" ]; then
              emit_gate PASS redirect-front-matter-valid "$scope"
            else
              emit_gate FAIL redirect-front-matter-valid "$scope" "missing=$rmiss"
            fi
          else
            emit_gate PASS redirect-front-matter-valid "$scope"
          fi
          continue
        fi

        if story_frontmatter_populated "$doc" "$fm_schema_mode"; then
          emit_gate PASS story-front-matter-populated "$scope"
        else
          emit_gate FAIL story-front-matter-populated "$scope"
        fi

        if story_frame_present "$doc" "$frame_mode"; then
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
# Strict-mode redirect front-matter (BC-12907 review-fix): under frontmatter_schema:strict a
# redirect missing a REDIRECT_CANON key hard-fails redirect-front-matter-valid (config-gated
# path — mirrors evaluate()/CI-runner; the lenient default leaves it a pass).
mkdir -p "$RDIR/.flow"; printf '{"frontmatter_schema": "strict"}\n' > "$RDIR/.flow/config.json"
printf -- '---\nflow_id: %s\ndomain: %s\ndoc_type: redirect\nredirect_to: %s\nlast_reviewed: y\n---\n# %s (redirect, missing intent)\n' "$RAFID" "$RADOM" "$RTGT" "$RAFID" > "$RALIAS"
run_phase_b_gates "$RDIR"
if awk -F'\t' -v s="flow:$RAFID" '$1=="FAIL" && $2=="redirect-front-matter-valid" && $3==s{ok=1} END{exit !ok}' "$GATE_REPORT"; then
  pass "strict: redirect missing canon key (intent) → redirect-front-matter-valid FAIL"
else
  fail "strict redirect missing-key not caught on bash twin"
fi
rm -rf "$RDIR"

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

# ── Section 4b: story_frame:strict gate-narrowing (BC-11983 / Q29 amendment 3) ─
# Per-repo gate-narrowing: when the consumer repo's .flow/config.json sets
# `story_frame: strict`, the retired constraint-spec frame (Given + MUST + so that)
# no longer satisfies story-job-story-regex — only the human job-story frame does.
# Lenient (default / field absent) is byte-identical to Section 4 above. THREE
# states locked (BC-12134 lenient floor → per-repo strict narrowing):
#   (1) human-frame doc PASS under strict,
#   (2) constraint-spec doc FAIL under strict,
#   (3) constraint-spec doc STILL PASS under lenient (proves the flag GATES the
#       behavior — it is not a blanket removal; the floor survives for un-reframed
#       consumer repos mid-migration).
section "4b/5" "story_frame:strict narrows story-job-story-regex to the human frame"
for variant in jobstory-1line jobstory-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md" strict; then
    pass "strict: gate accepts the human job-story frame ($variant)"
  else
    fail "strict: gate rejected a valid human frame ($variant)"
  fi
done
for variant in constraint-1line constraint-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md" strict; then
    fail "strict: gate accepted the retired constraint-spec frame ($variant) — narrowing not enforced"
  else
    pass "strict: gate rejects the retired constraint-spec frame ($variant)"
  fi
done
for variant in constraint-1line constraint-multi; do
  if story_frame_present "$FRAME_TMP/$variant.md" lenient; then
    pass "lenient: gate still accepts the constraint-spec frame ($variant) — floor preserved"
  else
    fail "lenient: gate rejected the constraint-spec frame ($variant) — lenient floor broken"
  fi
done
# <mode> arg is case-insensitive (locks the tr-normalization in story_frame_present
# against a fail-OPEN regression): an uppercase `STRICT` must narrow (reject the
# constraint-spec frame), and a mixed-case `Strict` must still accept the human frame.
if story_frame_present "$FRAME_TMP/constraint-1line.md" STRICT; then
  fail "strict (uppercase mode 'STRICT'): gate accepted the constraint-spec frame — case-sensitive fail-open"
else
  pass "strict (uppercase mode 'STRICT'): gate rejects the constraint-spec frame"
fi
if story_frame_present "$FRAME_TMP/jobstory-1line.md" Strict; then
  pass "strict (mixed-case mode 'Strict'): gate accepts the human job-story frame"
else
  fail "strict (mixed-case mode 'Strict'): gate rejected a valid human frame"
fi

# ── Section 4b-bis: marker-form brittleness — core keyword INSIDE a bold span ──
# BC-13751. story_frame_present matches a marker's keyword inside a bold span, not
# only as the exact `**keyword**` span — so phrase-bolded `**the system MUST**` and
# the "to"-less `**I want**` are recognized (valid frames previously flagged as false-
# negatives across supply/roster). The bold REQUIREMENT is unchanged (unbolded prose
# never passes) and keywords are word-boundaried. Mirror of test_build_audit_report.sh § 2b.
section "4b-bis/5" "marker-form brittleness: keyword-in-bold-span (BC-13751)"
printf '## Job story\n\n%s\n' '> **Given** a req, **the system MUST** serve, **so that** crawlable.' > "$FRAME_TMP/phrase-must.md"
printf '## Job story\n\n%s\n' '> **When** x, **I want** y, **so I can** z.' > "$FRAME_TMP/iwant-no-to.md"
printf '## Job story\n\n%s\n' '> Given a crawler requests the page, the system MUST serve a sitemap, so that pages rank.' > "$FRAME_TMP/unbolded.md"
printf '## Job story\n\n%s\n' '> **When** x, **I want to** y, **so** z.' > "$FRAME_TMP/so-trunc.md"
printf '## Job story\n\n%s\n' '> **Given** a req, **mustard glaze** is applied, **so that** it works.' > "$FRAME_TMP/mustard.md"
printf '## Job story\n\n%s\n' '> **When** x, **I wanted to** y, **so I can** z.' > "$FRAME_TMP/iwanted.md"
# Positives (lenient): the two real fan-out near-miss shapes are now accepted.
for v in phrase-must iwant-no-to; do
  if story_frame_present "$FRAME_TMP/$v.md"; then pass "lenient accepts near-miss $v"; else fail "lenient rejected valid near-miss $v"; fi
done
# **I want** (human) is strict-ready; **the system MUST** (constraint) stays strict-rejected.
if story_frame_present "$FRAME_TMP/iwant-no-to.md" strict; then pass "strict accepts **I want** human near-miss (strict-ready)"; else fail "strict rejected **I want** human near-miss"; fi
if story_frame_present "$FRAME_TMP/phrase-must.md" strict; then fail "strict accepted phrase-bolded constraint (mode guard broken)"; else pass "strict still rejects phrase-bolded constraint"; fi
# GAP control (the real brite-labs false-positive): two unrelated bold spans with
# unbolded Given/MUST/so-that prose BETWEEN them must NOT read as one bold span.
printf '## Job story\n\n%s\n' '> **Doc type:** Constraint spec. Given a req, the system MUST serve, so that crawlable. Beneficiary: **[Persona](p.md)**' > "$FRAME_TMP/gap.md"
# Negative controls (lenient): the loosening must NOT widen any of these.
for v in unbolded so-trunc mustard iwanted gap; do
  if story_frame_present "$FRAME_TMP/$v.md"; then fail "lenient WRONGLY accepted $v (over-loosened)"; else pass "lenient still rejects $v"; fi
done

# ── Section 4c: story_frame:strict threads through run_phase_b_gates end-to-end ─
# The unit assertions above pin the function; this pins the WIRING — that
# .flow/config.json `story_frame: strict` actually reaches the gate via
# run_phase_b_gates (guards against a "function correct but never wired" silent
# no-op). Copy the clean fixture, swap ONE doc's human frame for a constraint-spec
# frame (only the frame line changes → only story-job-story-regex can flip), then
# assert that doc FAILs the gate under strict and PASSes under lenient.
section "4c/5" "story_frame:strict threads through run_phase_b_gates (config → gate)"
STRICT_FIX="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$STRICT_FIX"' EXIT
cp -R "$CLEAN_FIXTURE/." "$STRICT_FIX/"
STRICT_DOC="$STRICT_FIX/docs/product/flows/TEAM/TEAM-01.md"
python3 - "$STRICT_DOC" <<'PY'
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
# pass (swap no-op) and the mixed-marker fixture Greptile flagged. (Human markers
# are bold-wrapped only in the frame; Gherkin `When` in scenarios is unbolded, so a
# whole-doc scan is safe.)
if grep -q 'the system \*\*MUST\*\*' "$STRICT_DOC" \
   && ! grep -qiE '\*\*When\*\*|\*\*I want to\*\*|\*\*so I can\*\*' "$STRICT_DOC"; then
  pass "e2e setup: TEAM-01 swapped to a pure constraint-spec doc (no residual human markers)"
else
  fail "e2e setup: swap left residual human markers or didn't take — e2e assertions are invalid"
fi

# strict config → the constraint-spec doc FAILs story-job-story-regex end-to-end.
python3 - "$STRICT_FIX/.flow/config.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d['story_frame'] = 'strict'
json.dump(d, open(p, 'w'))
PY
run_phase_b_gates "$STRICT_FIX"
assert_failed story-job-story-regex flow:TEAM-01

# lenient config (field removed) → the same doc PASSes (control: proves the flag,
# not the doc, drives the verdict).
python3 - "$STRICT_FIX/.flow/config.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d.pop('story_frame', None)
json.dump(d, open(p, 'w'))
PY
run_phase_b_gates "$STRICT_FIX"
if awk -F'\t' '$1=="PASS" && $2=="story-job-story-regex" && $3=="flow:TEAM-01"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "lenient (control): TEAM-01 constraint-spec doc PASSes story-job-story-regex"
else
  fail "lenient (control): TEAM-01 constraint-spec doc did not PASS — lenient floor broken end-to-end"
fi

# ── Section 4d: story_frame_mode config reader (default-resolution edge cases) ─
# Pins the fail-safe default-resolution the e2e path can't see: only an explicit
# `story_frame: "strict"` narrows; everything else stays lenient.
section "4d/5" "story_frame_mode resolves .flow/config.json story_frame (fail-safe lenient)"
MODE_TMP="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$STRICT_FIX" "$MODE_TMP"' EXIT
mkdir -p "$MODE_TMP/.flow"
[ "$(story_frame_mode "$MODE_TMP/absent")" = "lenient" ] \
  && pass "absent .flow/config.json → lenient" || fail "absent config did not resolve lenient"
printf '%s' '{"version":"1"}' > "$MODE_TMP/.flow/config.json"
[ "$(story_frame_mode "$MODE_TMP")" = "lenient" ] \
  && pass "config present, story_frame field absent → lenient" || fail "field-absent did not resolve lenient"
printf '%s' '{"version":"1","story_frame":"strict"}' > "$MODE_TMP/.flow/config.json"
[ "$(story_frame_mode "$MODE_TMP")" = "strict" ] \
  && pass "story_frame:strict → strict" || fail "story_frame:strict did not resolve strict"
printf '%s' '{"version":"1","story_frame":"STRICT"}' > "$MODE_TMP/.flow/config.json"
[ "$(story_frame_mode "$MODE_TMP")" = "strict" ] \
  && pass "story_frame:STRICT (uppercase) → strict (case-insensitive contract)" || fail "uppercase STRICT did not resolve strict — case-insensitive contract broken"
printf '%s' '{"version":"1","story_frame":"lenient"}' > "$MODE_TMP/.flow/config.json"
[ "$(story_frame_mode "$MODE_TMP")" = "lenient" ] \
  && pass "story_frame:lenient → lenient" || fail "story_frame:lenient did not resolve lenient"
printf '%s' '{"version":"1","story_frame":"banana"}' > "$MODE_TMP/.flow/config.json"
[ "$(story_frame_mode "$MODE_TMP")" = "lenient" ] \
  && pass "unrecognized story_frame value → lenient (fail-safe: never accidentally narrow)" || fail "unrecognized value did not resolve lenient"

# ── Section 4e: frontmatter_schema:strict widens story-front-matter-populated ─
# BC-12572: .flow/config.json `frontmatter_schema: strict` widens the
# story-front-matter-populated gate from the 4-key floor to the full 20-key story
# canon (presence, not non-emptiness). Default/absent = the 4-key floor (Sections
# 2/3 above already pin lenient). Mirrors Section 4c's copy-and-mutate wiring: the
# clean fixture's docs carry only the 4 floor keys (+ children/qa), so under strict
# they FAIL until upgraded to full canon. Proves (1) a full-canon doc PASSes strict,
# (2) a still-lean doc FAILs strict, (3) BOTH PASS lenient (the flag GATES it).
section "4e/5" "frontmatter_schema:strict widens story-front-matter-populated to full canon"
SCHEMA_FIX="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$STRICT_FIX" "$MODE_TMP" "$SCHEMA_FIX"' EXIT
cp -R "$CLEAN_FIXTURE/." "$SCHEMA_FIX/"
# Upgrade TEAM-01 to the FULL 20-key canon by inserting the keys the lean fixture
# lacks before the closing front-matter `---`.
SCHEMA_DOC="$SCHEMA_FIX/docs/product/flows/TEAM/TEAM-01.md"
python3 - "$SCHEMA_DOC" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines(keepends=True)
add = ("domain: TEAM\nparent_issue: BC-1\npersonas: []\nrelated_flows: []\n"
       "sandbox_url: TBD\nstaging_url: TBD\nreal_app_url: TBD\ne2e_test: TBD\n"
       "eng_status: not-started\ndesign_status: not-started\ndocs_status: not-started\n"
       "intent: ../../intent.md\n")
idx = [i for i, l in enumerate(lines) if l.strip() == "---"]
lines.insert(idx[1], add)  # before the front-matter close
open(p, "w").write("".join(lines))
PY
# Guard: confirm the upgraded doc now satisfies the full canon (zero MISSING_KEY)
# while a sibling lean doc does not — defeats a vacuous pass if the insert no-ops.
if story_frontmatter_populated "$SCHEMA_DOC" strict \
   && ! story_frontmatter_populated "$SCHEMA_FIX/docs/product/flows/TEAM/TEAM-02.md" strict; then
  pass "e2e setup: TEAM-01 upgraded to full canon; TEAM-02 still lean (strict-separable)"
else
  fail "e2e setup: upgrade no-op or TEAM-02 already full — e2e assertions invalid"
fi

python3 - "$SCHEMA_FIX/.flow/config.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d['frontmatter_schema'] = 'strict'
json.dump(d, open(p, 'w'))
PY
run_phase_b_gates "$SCHEMA_FIX"
if awk -F'\t' '$1=="FAIL" && $2=="story-front-matter-populated" && $3=="flow:TEAM-02"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "strict: lean TEAM-02 FAILs story-front-matter-populated (4-key floor insufficient)"
else
  fail "strict: lean TEAM-02 did not FAIL — widening not enforced"
fi
if awk -F'\t' '$1=="PASS" && $2=="story-front-matter-populated" && $3=="flow:TEAM-01"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "strict: full-canon TEAM-01 PASSes story-front-matter-populated"
else
  fail "strict: full-canon TEAM-01 did not PASS — widening rejects a complete doc"
fi

# lenient control (field removed) → the lean TEAM-02 PASSes the 4-key floor again
# (proves the flag, not the doc, drives the verdict).
python3 - "$SCHEMA_FIX/.flow/config.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d.pop('frontmatter_schema', None)
json.dump(d, open(p, 'w'))
PY
run_phase_b_gates "$SCHEMA_FIX"
if awk -F'\t' '$1=="PASS" && $2=="story-front-matter-populated" && $3=="flow:TEAM-02"{f=1} END{exit !f}' "$GATE_REPORT"; then
  pass "lenient (control): lean TEAM-02 still PASSes the 4-key floor"
else
  fail "lenient (control): lean TEAM-02 FAILed the floor — lenient floor broken end-to-end"
fi

# ── Section 4f: frontmatter_schema_mode config reader (fail-safe lenient) ─────
section "4f/5" "frontmatter_schema_mode resolves .flow/config.json (fail-safe lenient)"
SCHEMA_MODE_TMP="$(mktemp -d)"
trap 'rm -f "$GATE_REPORT"; rm -rf "$FRAME_TMP" "$STRICT_FIX" "$MODE_TMP" "$SCHEMA_FIX" "$SCHEMA_MODE_TMP"' EXIT
mkdir -p "$SCHEMA_MODE_TMP/.flow"
[ "$(frontmatter_schema_mode "$SCHEMA_MODE_TMP/absent")" = "lenient" ] \
  && pass "absent .flow/config.json → lenient" || fail "absent config did not resolve lenient"
printf '%s' '{"version":"1"}' > "$SCHEMA_MODE_TMP/.flow/config.json"
[ "$(frontmatter_schema_mode "$SCHEMA_MODE_TMP")" = "lenient" ] \
  && pass "field absent → lenient" || fail "field-absent did not resolve lenient"
printf '%s' '{"version":"1","frontmatter_schema":"strict"}' > "$SCHEMA_MODE_TMP/.flow/config.json"
[ "$(frontmatter_schema_mode "$SCHEMA_MODE_TMP")" = "strict" ] \
  && pass "frontmatter_schema:strict → strict" || fail "strict did not resolve strict"
printf '%s' '{"version":"1","frontmatter_schema":"STRICT"}' > "$SCHEMA_MODE_TMP/.flow/config.json"
[ "$(frontmatter_schema_mode "$SCHEMA_MODE_TMP")" = "strict" ] \
  && pass "frontmatter_schema:STRICT (uppercase) → strict" || fail "uppercase STRICT did not resolve strict"
printf '%s' '{"version":"1","frontmatter_schema":"banana"}' > "$SCHEMA_MODE_TMP/.flow/config.json"
[ "$(frontmatter_schema_mode "$SCHEMA_MODE_TMP")" = "lenient" ] \
  && pass "unrecognized value → lenient (fail-safe)" || fail "unrecognized value did not resolve lenient"

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
