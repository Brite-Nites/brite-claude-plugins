#!/usr/bin/env bash
# ── Cross-PR ADR-number collision guard — the thin gh ADAPTER (BC-12698) ──────
#
# CI-ONLY (it needs `gh` + a live PR context). The DETERMINISTIC half — given the
# {self, others[]} model, find collisions — lives in the unit-tested core
# scripts/_lib/lint_cross_pr_adr_numbers.py (mutation-locked, validate.sh
# §15a-bc-12698). This adapter is the NON-deterministic half the core can't be:
# it gathers the live open-PR set from GitHub, drops THIS PR, scopes each PR to
# the docs/decisions/*.md files it ADDS, builds the model, and pipes it in. It is
# validated by reading the workflow + a manual `gh pr list` dry-run, NOT by a
# fixture harness (the open-PR set is non-deterministic).
#
# WHAT IT CLOSES: the within-repo guard (lint_adr_numbers.py, BC-12617) catches a
# duplicate ADR number within one PR's tree, post-merge on main, and vs-main at PR
# time (the merge-ref tree scan). It does NOT catch two concurrently-open PRs that
# each ADD the same NNN with different slugs before either merges. This surfaces
# that cross-PR collision earlier, as an advisory red naming the colliding PR, so
# the author renumbers before the cascade.
#
# ADVISORY + SKIP-WITH-REASON: the signal is racy (each PR's run only sees what's
# open at that instant; BOTH colliding PRs may red on their own runs — there is no
# reliable "only the later one fails" ordering). The CI job runs continue-on-error,
# and this adapter EXITS 0 with a printed reason whenever it cannot do its job
# (no gh / no PR context / can't read the open-PR set) rather than false-red. A
# real collision still exits 1 (advisory red via the job). The within-repo guard +
# the claim-first convention remain the real guards; this is the earlier-surface.
#
# Inputs (CI supplies these; all overridable for a manual dry-run):
#   GITHUB_REPOSITORY / REPO   owner/name (else derived via `gh repo view`)
#   PR_NUMBER                  this PR's number (else resolved for the current branch)
#   PR_URL                     this PR's URL (else synthesized from REPO + PR_NUMBER)
#   GH_TOKEN                   token with pull-requests:read (CI: ${{ github.token }})
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail  # NOT -e: gh failures must skip-with-reason (exit 0), not abort.

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CORE="$REPO_ROOT/scripts/_lib/lint_cross_pr_adr_numbers.py"

skip() { printf 'cross-PR ADR-number guard: skipped — %s\n' "$1"; exit 0; }
note() { printf 'cross-PR ADR-number guard: %s\n' "$1"; }

command -v gh      >/dev/null 2>&1 || skip "gh CLI not available"
command -v python3 >/dev/null 2>&1 || skip "python3 not available"
[ -f "$CORE" ] || skip "core not found at $CORE"

# ── 1. Resolve PR context ────────────────────────────────────────────────────
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"
[ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
[ -n "$REPO" ] || skip "could not determine repository (set GITHUB_REPOSITORY)"

SELF_PR="${PR_NUMBER:-}"
[ -n "$SELF_PR" ] || SELF_PR="$(gh pr view --json number -q .number 2>/dev/null || true)"
[ -n "$SELF_PR" ] || skip "no PR context (not a pull_request run, and no open PR for HEAD)"

SELF_URL="${PR_URL:-}"
[ -n "$SELF_URL" ] || SELF_URL="https://github.com/$REPO/pull/$SELF_PR"

# Print the added docs/decisions/*.md files for a PR (one per line). Returns 1 if
# the GitHub API call itself failed (auth/scope/rate-limit) — distinct from "no
# added ADRs" (success, empty output) so callers can tell the two apart.
added_decisions() {
  local pr="$1" out rc
  out="$(gh api "repos/$REPO/pulls/$pr/files" --paginate \
           --jq '.[] | select(.status=="added") | .filename' 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || return 1
  # Flat ADRs only: docs/decisions/<name>.md (the core ignores non-ADR basenames,
  # but scoping here keeps the model tight and the API payload honest).
  printf '%s\n' "$out" | grep -E '^docs/decisions/[^/]+\.md$' || true
}

# ── 2. This PR's added ADRs (skip the whole check if unreadable) ──────────────
self_files="$(added_decisions "$SELF_PR")" \
  || skip "could not read this PR's files (token scope? rate limit?) — needs pull-requests:read"

if [ -z "$self_files" ]; then
  note "this PR (#$SELF_PR) adds no docs/decisions/*.md ADR — nothing to check"
  exit 0
fi

# ── 3. Other open PRs against main ────────────────────────────────────────────
open_pr_limit=200
others_json="$(gh pr list --state open --base main --json number,url --limit "$open_pr_limit" 2>/dev/null)" \
  || skip "could not list open PRs (token scope? gh auth?) — needs pull-requests:read"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
printf '%s\n' "$self_files" > "$TMP_DIR/self.files"

# Flatten the open-PR list to "<number>\t<url>" lines, via a temp file with an
# explicit error check — NOT a process substitution: a crash in the parser there
# would be invisible (the loop would read nothing and the guard would falsely
# report "0 other PRs / OK"). The python uses only double-quoted literals so it is
# safe inside bash single-quotes (no backslash-escaped quotes).
pr_lines="$TMP_DIR/open-prs.tsv"
if ! printf '%s' "$others_json" | python3 -c 'import sys, json
for o in json.load(sys.stdin):
    print(str(o["number"]) + "\t" + (o.get("url") or ""))' > "$pr_lines"; then
  skip "could not parse the open-PR list from gh"
fi

# Don't let a silent cap masquerade as "all clear": if the open-PR list filled the
# --limit, PRs beyond it went unseen — say so (the guard is best-effort/advisory).
open_count="$(wc -l < "$pr_lines" | tr -d ' ')"
if [ "${open_count:-0}" -ge "$open_pr_limit" ]; then
  note "open-PR list hit the --limit $open_pr_limit cap — any open PR beyond it is NOT checked this run"
fi

# Walk the open PRs, dropping THIS PR (self-exclusion — the core defends too). A
# per-PR files failure is logged and that PR is skipped (best-effort: one weird PR
# must not blank the whole advisory check), not fatal.
checked=0
while IFS=$'\t' read -r num url; do
  [ -n "$num" ] || continue
  [ "$num" = "$SELF_PR" ] && continue
  if of="$(added_decisions "$num")"; then
    printf '%s\n' "$of"  > "$TMP_DIR/o.$num.files"
    printf '%s'   "$url" > "$TMP_DIR/o.$num.url"
    checked=$((checked + 1))
  else
    note "could not read files for PR #$num — skipping it (token scope/rate limit)"
  fi
done < "$pr_lines"

note "checking this PR (#$SELF_PR) added ADR number(s) against $checked other open PR(s)"

# ── 4. Assemble the {self, others[]} model and run the deterministic core ─────
# The assembler runs under the same skip-with-reason contract as every other step:
# if it can't build the model (an adapter bug), skip cleanly rather than feed the
# core garbage and surface a bug as a collision-shaped advisory red.
model="$TMP_DIR/model.json"
if ! TMP_DIR="$TMP_DIR" SELF_PR="$SELF_PR" SELF_URL="$SELF_URL" python3 - > "$model" <<'PY'
import json, os, glob, pathlib

tmp = os.environ["TMP_DIR"]

def read_lines(path):
    try:
        return [ln for ln in pathlib.Path(path).read_text().splitlines() if ln.strip()]
    except FileNotFoundError:
        return []

self_obj = {
    "pr": int(os.environ["SELF_PR"]),
    "url": os.environ.get("SELF_URL", ""),
    "added": read_lines(os.path.join(tmp, "self.files")),
}
others = []
for fp in sorted(glob.glob(os.path.join(tmp, "o.*.files"))):
    num = os.path.basename(fp)[2:-len(".files")]   # o.<num>.files → <num>
    url_path = os.path.join(tmp, f"o.{num}.url")
    url = pathlib.Path(url_path).read_text().strip() if os.path.exists(url_path) else ""
    others.append({"pr": int(num), "url": url, "added": read_lines(fp)})

print(json.dumps({"self": self_obj, "others": others}))
PY
then
  skip "could not assemble the cross-PR model"
fi

# The core exits 1 on a real collision (advisory red via the job's
# continue-on-error), 0 when clean, 2 on a malformed model (a bug here). Propagate.
python3 "$CORE" --github "$model"
exit $?
