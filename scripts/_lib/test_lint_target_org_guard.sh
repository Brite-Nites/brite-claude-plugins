#!/usr/bin/env bash
# Self-test for scripts/_lib/lint_target_org_guard.py (BC-12638).
#
# lint_target_org_guard.py is the repo-wide CONSOLIDATING guard-precedes-sink
# lint. It SUBSUMES BC-12623's two bespoke per-file σ3 ordering tests with a
# single check covering every command interpolating a non-literal `--target-org`
# into an executable `sf` shell-out — across BOTH plugins — and fires on any
# FUTURE non-literal passthrough.
#
# Rule: a command file with an executable non-literal `--target-org` sink MUST
# place a standalone `<!-- guard:target-org -->` marker BEFORE its earliest such
# sink, with the byte-identical canonical regex ^[a-zA-Z0-9._@-]+$ documented in
# the window BETWEEN the marker and that sink (binding the marker to the real
# guard prose, not a free-floating comment). A bash-fenced non-literal that is
# NOT a real sink (operator copy-paste snippet) declares a sink-scoped
# `<!-- guard:target-org:exempt <reason> -->`.
#
# This harness drives the lint against synthetic FIXTURES covering the mutation
# matrix, asserting exit codes + violation reasons. The fixtures are the spec.
#
# Usage:
#   bash scripts/_lib/test_lint_target_org_guard.sh
#   bash scripts/_lib/test_lint_target_org_guard.sh /path/to/lint_target_org_guard.py

set -u  # NOT set -e — non-zero exits are EXPECTED for the FAIL fixtures.

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${1:-$HERE/lint_target_org_guard.py}"

pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

BOX="$(mktemp -d)"
trap 'rm -rf "$BOX"' EXIT

REGEX='^[a-zA-Z0-9._@-]+$'   # canonical (kept out of heredocs to avoid expansion)
DRIFT='^[a-z0-9._@-]+$'      # drifted (missing A-Z) — must NOT satisfy the bind
MARKER='<!-- guard:target-org -->'

# Fixture builders emit a minimal command .md. $1=path. Body via stdin.
write() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# Run the lint on the given files; echo "<rc>|<stderr+stdout>".
run_lint() {
  local out rc
  out="$(python3 "$LINT" "$@" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "$out"
}

# expect_pass <file> <label>  — lint must exit 0 (clean).
expect_pass() {
  local r; r="$(run_lint "$1")"
  if [ "${r%%|*}" -eq 0 ]; then ok; else bad "$2 expected PASS, got rc=${r%%|*}: ${r#*|}"; fi
}

# expect_fail <file> <label> <msg-regex>  — lint must exit EXACTLY 1 (a clean
# violation, NOT a rc=2 crash) AND the message must match <msg-regex>. The exact
# rc==1 check is load-bearing: a TypeError/crash exits non-zero too, so asserting
# only "non-zero" would false-green a broken violation path.
expect_fail() {
  local r rc body; r="$(run_lint "$1")"; rc="${r%%|*}"; body="${r#*|}"
  if [ "$rc" -eq 1 ]; then ok; else bad "$2 expected FAIL rc=1, got rc=$rc: $body"; fi
  if printf '%s' "$body" | grep -qiE "$3"; then ok; else bad "$2 message should match /$3/: $body"; fi
}

# ── (a) literal-only sink (deploy-prod-shaped) → EXEMPT, PASS ─────────────────
fa="$BOX/a/literal.md"; write "$fa" <<EOF
# literal-only
\`\`\`bash
sf org display --target-org brite-prod --json
sf project deploy start --source-dir force-app --target-org brite-prod --json
\`\`\`
EOF
expect_pass "$fa" "(a) literal-only"

# ── (b) placeholder sink, NO marker → FAIL (missing marker) ───────────────────
fb="$BOX/b/nomarker.md"; write "$fb" <<EOF
# placeholder, no marker
Validated against regex \`$REGEX\`.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_fail "$fb" "(b) no marker" 'no .*marker preceding'

# ── (c) placeholder sink, marker AFTER sink → FAIL (guard-after-sink) ──────────
fc="$BOX/c/marker_after.md"; write "$fc" <<EOF
# marker after sink
Validated against regex \`$REGEX\`.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
$MARKER
EOF
expect_fail "$fc" "(c) marker-after-sink" 'after the earliest|guard-after-sink'

# ── (d) marker BEFORE sink + canonical regex IN the window → PASS ──────────────
fd="$BOX/d/marker_before.md"; write "$fd" <<EOF
# marker before sink, guard bound
$MARKER
First, validate \`--target-org\` against regex \`$REGEX\`.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_pass "$fd" "(d) marker-before + regex-in-window"

# ── (e) placeholder ONLY in a json fence (dry-run preview) → no sink → PASS ────
fe="$BOX/e/preview_json.md"; write "$fe" <<EOF
# preview json only
\`\`\`bash
sf org display --target-org brite-prod --json
\`\`\`
\`\`\`json
{"dry_run":true,"command":"sf data create record --target-org <target-org> --json"}
\`\`\`
EOF
expect_pass "$fe" "(e) json-fence preview placeholder is not a sink"

# ── (f) marker before sink but DRIFTED regex in window (no canonical) → FAIL ───
ff="$BOX/f/regex_drift.md"; write "$ff" <<EOF
# regex drift in the guard window
$MARKER
Validate \`--target-org\` against regex \`$DRIFT\`.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_fail "$ff" "(f) drifted regex" 'not bound|canonical'

# ── (g) frontmatter argument-hint placeholder must NOT count as a sink → PASS ──
fg="$BOX/g/arg_hint.md"; write "$fg" <<EOF
---
argument-hint: --monthly [--target-org <alias>]
---
# arg-hint only
\`\`\`bash
sf org display --target-org brite-sandbox --json
\`\`\`
EOF
expect_pass "$fg" "(g) argument-hint placeholder"

# ── (h) sink-scoped exempt before its snippet → PASS ──────────────────────────
fh="$BOX/h/exempt.md"; write "$fh" <<EOF
# copy-paste runbook snippet
<!-- guard:target-org:exempt operator copy-paste runbook snippet -->
Execute via:
\`\`\`bash
sf apex run --target-org <alias> --file scratch.apex
\`\`\`
EOF
expect_pass "$fh" "(h) documented exempt marker"

# ── (i) plain marker after sink, no exempt token → FAIL (guard-after-sink) ─────
fi_="$BOX/i/fake_exempt.md"; write "$fi_" <<EOF
# no real exemption
\`\`\`bash
sf apex run --target-org <alias> --file scratch.apex
\`\`\`
$MARKER
EOF
expect_fail "$fi_" "(i) plain marker after sink" 'after the earliest|guard-after-sink'

# ── (j) UNIQUENESS LOCK — prose mention of the marker string, no standalone
# marker → FAIL (mirrors BC-12623's "bare regex in the flag table" trap). ──────
fj="$BOX/j/prose_mention.md"; write "$fj" <<EOF
# prose mention only
The lint checks that the \`$MARKER\` marker precedes the sink. Validated against \`$REGEX\`.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_fail "$fj" "(j) prose-mention only" 'no .*marker preceding'

# ── (k) SINK-SCOPED EXEMPT — a real unguarded sink EARLIER than the exempt
# snippet must still FAIL (the later exempt cannot mask the earlier real sink). ─
fk="$BOX/k/exempt_masks_earlier.md"; write "$fk" <<EOF
# exempt cannot mask an earlier real sink
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
<!-- guard:target-org:exempt later copy-paste snippet -->
\`\`\`bash
sf apex run --target-org <alias> --file scratch.apex
\`\`\`
EOF
expect_fail "$fk" "(k) exempt masking earlier real sink" 'no .*marker preceding'

# ── (l) tilde ~~~bash fence sink, no marker → FAIL (caught) ───────────────────
fl="$BOX/l/tilde_fence.md"; write "$fl" <<EOF
# tilde-fence sink
~~~bash
sf org display --target-org "<target-org>" --json
~~~
EOF
expect_fail "$fl" "(l) tilde-fence sink" 'no .*marker preceding'

# ── (m) --target-org=\$VAR equals-form sink, no marker → FAIL (caught) ────────
fm="$BOX/m/equals_form.md"; write "$fm" <<EOF
# equals-form var sink
\`\`\`bash
sf org display --target-org="\$OPERATOR_ORG" --json
\`\`\`
EOF
expect_fail "$fm" "(m) equals-form \$VAR sink" 'no .*marker preceding'

# ── (n) WINDOW BIND — marker before sink but canonical regex appears ONLY before
# the marker (flag table), not in the (marker, sink) window → FAIL. ────────────
fn="$BOX/n/regex_before_marker.md"; write "$fn" <<EOF
# regex only before the marker (flag table), not bound to the guard
| \`--target-org\` | no | Validated against \`$REGEX\`. |
$MARKER
First, validate the org alias.
\`\`\`bash
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_fail "$fn" "(n) regex before marker, not in window" 'not bound|canonical'

# ── (o) unlabeled \`\`\` fence sink, no marker → FAIL (fail-closed) ───────────
fo="$BOX/o/unlabeled_fence.md"; write "$fo" <<EOF
# unlabeled fence sink (fail-closed)
\`\`\`
sf org display --target-org "<target-org>" --json
\`\`\`
EOF
expect_fail "$fo" "(o) unlabeled-fence sink" 'no .*marker preceding'

printf 'RESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
