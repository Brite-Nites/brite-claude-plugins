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
#   no caching, no file I/O beyond env-export, no logging, no retry. The ONE
#   sanctioned session acquisition is the opt-in macOS Keychain self-unlock in
#   the preflight below (ADR-010 § 1); no other token refresh.
#   Expansion proposals must update the canon doc first.
set -euo pipefail

# --- Preflight --------------------------------------------------------------
if ! command -v jq >/dev/null; then
  echo "bw-run.sh: jq is required (\`brew install jq\`)" >&2
  exit 1
fi
# Opt-in self-unlock (ADR-010 § 1): when BW_SESSION is absent or stale, mint a
# fresh session from the macOS Keychain item `bw-master`. Machines without the
# item keep the original fail-closed behavior byte-for-byte. The minted session
# lives only in this process's env and is unset before exec like any other.
# Provision once: security add-generic-password -U -a "$USER" -s bw-master -w
#
# This path hands the MASTER password (strictly worse to leak than a session
# token — a session dies on `bw lock`, the master password does not) to two
# subprocesses, so both are resolved to absolute paths in trusted prefixes
# rather than inherited PATH: a shadowed `bw` earlier in PATH would otherwise
# receive it. Override an unusual bw install with BW_RUN_BW_BIN.
# BW_RUN_SECURITY_BIN exists so the test suite can point at its stub; in real
# use the macOS path is fixed and PATH is deliberately not consulted.
_SECURITY_BIN="${BW_RUN_SECURITY_BIN:-/usr/bin/security}"

_resolve_bw_bin() {
  if [ -n "${BW_RUN_BW_BIN:-}" ]; then
    [ -x "$BW_RUN_BW_BIN" ] && printf '%s' "$BW_RUN_BW_BIN" && return 0
    return 1
  fi
  _cand="$(command -v bw 2>/dev/null)" || return 1
  case "$_cand" in
    /opt/homebrew/bin/bw|/usr/local/bin/bw|/usr/bin/bw) printf '%s' "$_cand" ;;
    *) return 1 ;;
  esac
}

# At most ONE mint attempt per process (ADR-010 § 1 contract): the absent-session
# and stale-session branches both call this, and a mint that "succeeds" but still
# fails verification must not trigger a second attempt.
_SELF_UNLOCK_TRIED=0

_self_unlock() {
  [ "$_SELF_UNLOCK_TRIED" = "1" ] && return 1
  _SELF_UNLOCK_TRIED=1
  [ -x "$_SECURITY_BIN" ] || return 1
  _bw_bin="$(_resolve_bw_bin)" || return 1
  _bw_master="$("$_SECURITY_BIN" find-generic-password -s bw-master -w 2>/dev/null)" || return 1
  if [ -z "$_bw_master" ]; then
    return 1
  fi
  if ! BW_SESSION="$(BW_PASSWORD="$_bw_master" "$_bw_bin" unlock --raw --passwordenv BW_PASSWORD 2>/dev/null)"; then
    _bw_master=""
    return 1
  fi
  _bw_master=""
  export BW_SESSION
}

_UNLOCK_HINT="Run \`bw unlock\` and export BW_SESSION, or provision Keychain self-unlock: security add-generic-password -U -a \"\$USER\" -s bw-master -w"

if [ -z "${BW_SESSION:-}" ]; then
  _self_unlock || true
fi
if [ -z "${BW_SESSION:-}" ]; then
  echo "bw-run.sh: BW_SESSION not set. $_UNLOCK_HINT" >&2
  exit 1
fi
if ! bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
  _self_unlock || true
  if ! bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
    echo "bw-run.sh: vault is not unlocked (BW_SESSION may be stale). $_UNLOCK_HINT" >&2
    exit 1
  fi
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
      # Two-pass discrimination via jq (~2N calls at N=7 is still <5% of the
      # 3.2s `bw list items` network round-trip, well within BC-6905 budget).
      # Pass 1: structural status — `absent` / `wrong_type` / `ok`.
      # `wrong_type` covers items present but lacking a `.login` block (e.g.
      # secure-note type), which an in-band `// ""` fallback would have
      # silently misclassified as empty. Pass 2 only runs on `ok` to extract
      # the actual password — no in-band sentinels, no delimiter parsing,
      # no collision risk with values that happen to look like sentinels.
      status="$(printf '%s' "$CACHE" | jq -r --arg n "$item" '
        [.[] | select(.name==$n)] as $m |
        if ($m|length) == 0 then "absent"
        elif ($m[0] | has("login") | not) then "wrong_type"
        else "ok"
        end')"
      case "$status" in
        absent)
          echo "bw-run.sh: item \`$item\` not found in batch search" >&2
          exit 3
          ;;
        wrong_type)
          echo "bw-run.sh: item \`$item\` exists but is not a Bitwarden login type (re-create as Login with a password)" >&2
          exit 3
          ;;
        ok)
          value="$(printf '%s' "$CACHE" | jq -r --arg n "$item" '
            first(.[] | select(.name==$n) | .login.password // "")')"
          if [ -z "$value" ]; then
            echo "bw-run.sh: item \`$item\` exists in batch but has empty password (set the password in Bitwarden)" >&2
            exit 3
          fi
          export "$key=$value"
          ;;
      esac
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
# vault token from its env. Defense-in-depth against compromised transitive
# deps in third-party Node/Python packages (spider-cloud-mcp, aiark-mcp.js,
# discolike-mcp.js, the Python tam-map scripts) — a malicious dep with
# process.env access could otherwise exfiltrate the master vault token.
# The wrapper has finished all bw calls by this point; the wrapped process
# only needs the per-vendor KEY=value exports we already set above.
unset BW_SESSION
exec "$@"
