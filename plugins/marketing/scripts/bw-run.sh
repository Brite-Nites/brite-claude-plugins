#!/usr/bin/env bash
# bw-run.sh — Bitwarden credential broker for Brite marketing plugin (BC-6906 prod migration).
# Promotes the BC-6905 spike POC (scripts/spike-bw-run/bw-run.sh, PR #258) to production with
# three adaptations: (a) longest-common-prefix batch fetch via `bw list items --search` when
# prefix >= 3 chars (BC-6905 Q3: 3.21s constant-time vs N sequential calls, 86% saving at N=7);
# (b) macOS bash 3.2 + `set -u` empty-array guard (BC-6905 task-2 precedent); (c) structured
# `jq -e` vault-status check replacing fragile grep (BC-6905 adapt-list item 6).
# Design: docs/designs/BC-6906-bw-run-prod-migration.md § "Wrapper contract".
# License-equivalence: same repo, no external upstream — production promotion of the spike.
# Usage: bw-run.sh KEY=item [KEY=item ...] -- cmd args...
# Non-goals (canon scope discipline — see CONTRIBUTING.md § Plugin secret-config canon):
#   no caching, no file I/O beyond env-export, no logging, no token refresh, no retry.
#   Expansion proposals must update the canon doc first.
set -euo pipefail

# --- Preflight --------------------------------------------------------------
if ! command -v jq >/dev/null; then
  echo "bw-run.sh: jq is required (\`brew install jq\`)" >&2
  exit 1
fi
if [ -z "${BW_SESSION:-}" ]; then
  echo "bw-run.sh: BW_SESSION not set. Run \`bw unlock\` and export BW_SESSION." >&2
  exit 1
fi
if ! bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
  echo "bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again." >&2
  exit 1
fi

# --- Arg parse: collect KEY=item entries until -- separator -----------------
declare -a EXPORTS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  case "$1" in
    *=*)
      _k="${1%%=*}"; _v="${1#*=}"
      if [ -z "$_k" ] || [ -z "$_v" ]; then
        echo "bw-run.sh: unexpected arg \`$1\` (expected KEY=item or --)" >&2
        exit 2
      fi
      EXPORTS+=("$1")
      ;;
    *)
      echo "bw-run.sh: unexpected arg \`$1\` (expected KEY=item or --)" >&2
      exit 2
      ;;
  esac
  shift
done
if [ "${1:-}" != "--" ]; then
  echo "bw-run.sh: missing -- separator before command" >&2
  exit 2
fi
shift  # drop --
if [ $# -eq 0 ]; then
  echo "bw-run.sh: missing command after --" >&2
  exit 2
fi

# --- Longest common prefix of item names (right side of KEY=item) -----------
# Returns the prefix on stdout. Empty string if EXPORTS is empty or no common prefix.
lcp() {
  if [ "${#EXPORTS[@]}" -eq 0 ]; then printf ''; return; fi
  local first="${EXPORTS[0]#*=}"
  local prefix="$first"
  local entry name i
  for entry in "${EXPORTS[@]}"; do
    name="${entry#*=}"
    i=0
    while [ $i -lt "${#prefix}" ] && [ $i -lt "${#name}" ] && [ "${prefix:$i:1}" = "${name:$i:1}" ]; do
      i=$((i+1))
    done
    prefix="${prefix:0:$i}"
    [ -z "$prefix" ] && break
  done
  printf '%s' "$prefix"
}

# --- Fetch values: batch (prefix >= 3) or sequential -----------------------
if [ "${#EXPORTS[@]}" -gt 0 ]; then
  PREFIX="$(lcp)"
  if [ "${#PREFIX}" -ge 3 ]; then
    CACHE="$(bw list items --search "$PREFIX")"
    for entry in "${EXPORTS[@]}"; do
      key="${entry%%=*}"; item="${entry#*=}"
      value="$(printf '%s' "$CACHE" | jq -r --arg n "$item" '[.[] | select(.name==$n) | .login.password] | first // ""')"
      if [ -z "$value" ]; then
        echo "bw-run.sh: item \`$item\` not found in batch search" >&2
        exit 3
      fi
      export "$key=$value"
    done
  else
    for entry in "${EXPORTS[@]}"; do
      key="${entry%%=*}"; item="${entry#*=}"
      if ! value="$(bw get password "$item")" || [ -z "$value" ]; then
        echo "bw-run.sh: bw get password failed for item \`$item\`" >&2
        exit 3
      fi
      export "$key=$value"
    done
  fi
fi

# --- Exec wrapped command (transparent stdio passthrough; BC-6905 Q4) ------
# Drop BW_SESSION before exec so the wrapped MCP/CLI process can't read the
# vault token from its env (defense-in-depth: spider-cloud-mcp + the upstream
# aiark/discolike Node wrappers ship as third-party deps; a compromised
# transitive dep with process.env access could otherwise exfiltrate the
# token. The wrapper itself has finished all bw calls by this point.)
unset BW_SESSION
exec "$@"
