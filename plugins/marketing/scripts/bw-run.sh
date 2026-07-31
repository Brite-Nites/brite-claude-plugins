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
# subprocesses, so neither is taken from PATH on trust: a shadowed `bw` earlier
# in PATH would otherwise receive it. Both must pass _bin_is_trusted, and that
# check applies to the BW_RUN_BW_BIN / BW_RUN_SECURITY_BIN overrides as well —
# an env var an attacker can set is not an exemption from the check it would
# otherwise defeat.
_SECURITY_BIN="${BW_RUN_SECURITY_BIN:-/usr/bin/security}"
# System directories only. `ls`, `find` and `readlink` all live here on both
# macOS and Linux; if these are attacker-writable the machine is already lost.
_TRUSTED_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
# find-generic-password matches on service name alone unless an account is
# given, so it must be scoped to the same -a the provisioning hint uses;
# otherwise a same-service item for another account can win the lookup.
_KEYCHAIN_ACCOUNT="${USER:-$(id -un)}"

# A subprocess that touches the master password must be one an attacker cannot
# have written. Naming a path does not make it safe, so the known-install list
# is a NARROWING filter, never a pass: an allowlisted path still has to survive
# the same directory checks as any other. An earlier cut returned success on a
# bare string match, which meant the one branch meant to represent "known good"
# was the only branch that verified nothing — and on macOS, Homebrew makes
# /usr/local/bin and /opt/homebrew/bin user-owned (commonly group-writable),
# precisely the shape these checks exist to reject. Corrected 2026-07-31.
# The check must not be steerable by the thing it defends against. Everything
# below leans on external helpers, and an attacker who can seed PATH — the
# exact attacker this exists to stop — could otherwise substitute `ls` and have
# the check report success for any binary, making every rule above decorative.
# Two defences, because one is not enough on its own:
#   - `_self_unlock` pins PATH to the system directories for its whole
#     duration, the same move as sudo's secure_path. This is what actually
#     protects `ls`, `find` and `readlink`.
#   - dirname, basename and cut are gone, replaced by bash parameter
#     expansion, which cannot be substituted at all. Shrinking the external
#     surface to three is what makes pinning a claim worth trusting.
_mode_of() {
  _ml="$(ls -ld "$1" 2>/dev/null)" || return 1
  printf '%s' "${_ml:0:10}"
}

# dirname, without dirname.
_dirname_of() {
  case "$1" in
    */*) _dn="${1%/*}"; [ -n "$_dn" ] || _dn="/" ;;
    *)   _dn="." ;;
  esac
  printf '%s' "$_dn"
}

# Follow a symlinked binary to the thing that will actually run. Checking the
# link's directory says nothing about where the link points: /usr/local/bin/bw
# can be a symlink to anywhere, and Homebrew genuinely does symlink its bin
# entries into ../Cellar. Both ends are checked, since either being writable is
# enough to swap what executes. `readlink` without flags is portable; `-f` is
# not (BSD lacks it), hence the manual loop and the hop cap for link cycles.
_resolve_symlinks() {
  _rp="$1"
  _hops=0
  while [ -L "$_rp" ]; do
    _hops=$((_hops + 1))
    [ "$_hops" -gt 40 ] && return 1
    _target="$(readlink "$_rp" 2>/dev/null)" || return 1
    [ -n "$_target" ] || return 1
    case "$_target" in
      /*) _rp="$_target" ;;
      *)  _rp="$(_dirname_of "$_rp")/$_target" ;;
    esac
  done
  _rdir="$(cd "$(_dirname_of "$_rp")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "${_rdir%/}" "${_rp##*/}"
}

# Every ancestor must be un-swappable by anyone but us or root.
#
# Mode 0700 on a directory stops a co-tenant writing INTO it; it does nothing
# about renaming the directory itself, which needs only write on ITS parent.
# One attacker-writable ancestor and the whole thing goes.
#
# The sticky exemption is what keeps a shared parent like /tmp usable: sticky
# means only an entry's own owner may rename or delete it, so a co-tenant with
# write access to /tmp still cannot swap our directory. It exempts the write-bit
# test ONLY — a sticky directory's OWNER can still rename entries inside it, so
# the ownership test applies regardless.
_ancestors_ok() {
  _d="$1"
  while [ "$_d" != "/" ]; do
    _d="$(_dirname_of "$_d")"
    _m="$(_mode_of "$_d")"
    [ -n "$_m" ] || return 1
    if [ ! -O "$_d" ] && [ -z "$(find "$_d" -maxdepth 0 -user root 2>/dev/null)" ]; then
      return 1
    fi
    case "$_m" in
      *t|*T) continue ;;
    esac
    case "$_m" in
      ?????w????|????????w?) return 1 ;;
    esac
  done
  return 0
}

# Ownership is CHECKED, not inferred. An earlier cut reasoned that a mode-0700
# directory can only be traversed by its owner, so reaching the binary proved we
# were that owner. That fails silently for root, which bypasses permission
# checks entirely. `[ -O ]` asks directly and is right for root too (euid 0 owns
# only uid-0 paths).
#
# Two policies, because the two kinds of directory legitimately differ:
#   private — mode 0700 and ours. Required of any path we were not told about.
#             Excludes package directories, which are the realistic plant site:
#             node_modules/.bin is 0755 and owned by us, so it passes an
#             ownership test and must be caught on mode.
#   system  — ours or root's, and not group/other-writable. Applied to
#             known-install paths, which are 0755 by design and cannot be asked
#             for 0700. A group-writable /usr/local/bin fails here, which is
#             the Homebrew-on-macOS case worth failing on.
# `ls -ld` mode strings and `[ -O ]` are portable across macOS and Linux;
# `stat` format flags are not.
_dir_is_private() {
  [ -O "$1" ] || return 1
  [ "$(_mode_of "$1")" = "drwx------" ] || return 1
  _ancestors_ok "$1"
}

_dir_is_system() {
  if [ ! -O "$1" ] && [ -z "$(find "$1" -maxdepth 0 -user root 2>/dev/null)" ]; then
    return 1
  fi
  case "$(_mode_of "$1")" in
    ?????w????|????????w?) return 1 ;;
  esac
  _ancestors_ok "$1"
}

_bin_is_trusted() {
  _p="$1"; shift
  # Relative paths are rejected outright: the walks are only meaningful against
  # a rooted path, and nothing legitimate needs one here.
  case "$_p" in
    /*) ;;
    *) return 1 ;;
  esac
  _real="$(_resolve_symlinks "$_p")" || return 1
  _pdir="$(cd "$(_dirname_of "$_p")" 2>/dev/null && pwd -P)" || return 1
  _rdir="$(_dirname_of "$_real")"

  # Known-install match is checked against BOTH ends: Homebrew's allowlisted
  # /usr/local/bin/bw is a symlink into ../Cellar, so requiring the resolved
  # path to be listed would reject every Homebrew install.
  _listed=1
  for _ok in "$@"; do
    if [ "$_p" = "$_ok" ] || [ "$_real" = "$_ok" ]; then _listed=0; break; fi
  done

  if [ "$_listed" = "0" ]; then
    _dir_is_system "$_pdir" || return 1
    _dir_is_system "$_rdir" || return 1
    return 0
  fi
  _dir_is_private "$_pdir" || return 1
  _dir_is_private "$_rdir" || return 1
  return 0
}

# Known install locations, preference order. This doubles as the DISCOVERY
# list: PATH is not consulted for bw at all.
#
# It has to work that way now that PATH is pinned during the attempt. A pinned
# PATH cannot include the Homebrew prefixes — they are commonly group-writable,
# which is exactly what _dir_is_system rejects — so `command -v bw` under the
# pin would miss /opt/homebrew/bin/bw and silently decline to mint on the most
# common setup there is. Searching the known list directly fixes that and is
# better besides: a PATH good enough to search is a PATH good enough to poison,
# and discovery now cannot name anything the trust check would not accept.
#
# An install somewhere else is still reachable, just deliberately rather than
# by accident: point BW_RUN_BW_BIN at it and it goes through the private-path
# rules like any other override.
_BW_KNOWN_INSTALLS="/opt/homebrew/bin/bw /usr/local/bin/bw /usr/bin/bw"

_resolve_bw_bin() {
  # An explicit override is used or refused on its own merits — never quietly
  # swapped for something else. Being told which binary to use and then picking
  # a different one would be worse than failing.
  if [ -n "${BW_RUN_BW_BIN:-}" ]; then
    [ -x "$BW_RUN_BW_BIN" ] || return 1
    # Word splitting is the point: the list is passed as separate arguments.
    # shellcheck disable=SC2086
    _bin_is_trusted "$BW_RUN_BW_BIN" $_BW_KNOWN_INSTALLS || return 1
    printf '%s' "$BW_RUN_BW_BIN"
    return 0
  fi
  # Discovery takes the first install that is both present AND trusted, rather
  # than the first present one. On a Mac with a group-writable /opt/homebrew/bin
  # and a sound /usr/local/bin, stopping at the first present entry would refuse
  # to mint on a machine that has a perfectly good bw one line further down.
  for _k in $_BW_KNOWN_INSTALLS; do
    [ -x "$_k" ] || continue
    # shellcheck disable=SC2086
    _bin_is_trusted "$_k" $_BW_KNOWN_INSTALLS || continue
    printf '%s' "$_k"
    return 0
  done
  return 1
}

# At most ONE mint attempt per process (ADR-010 § 1 contract): the absent-session
# and stale-session branches both call this, and a mint that "succeeds" but still
# fails verification must not trigger a second attempt.
_SELF_UNLOCK_TRIED=0
# A self-minted session is held in these two rather than exported — see _bw.
_MINTED_SESSION=""
_MINTED_BW_BIN=""

_self_unlock() {
  [ "$_SELF_UNLOCK_TRIED" = "1" ] && return 1
  _SELF_UNLOCK_TRIED=1
  # Pin PATH for the whole attempt — see the note above _mode_of. The trust
  # check's own helpers must not be drawn from the PATH it exists to defend
  # against, or an attacker steers the verdict rather than the binary.
  #
  # Restored before returning, deliberately. The wrapper's later bare `bw` and
  # `jq` calls stay on the caller's PATH exactly as before: that is ADR-010's
  # deferred scope line, and quietly narrowing it here would be a different
  # change wearing this one's clothes.
  _saved_path="$PATH"
  PATH="$_TRUSTED_PATH"
  _rc=0
  _self_unlock_attempt || _rc=$?
  PATH="$_saved_path"
  return "$_rc"
}

_self_unlock_attempt() {
  [ -x "$_SECURITY_BIN" ] || return 1
  _bin_is_trusted "$_SECURITY_BIN" /usr/bin/security || return 1
  # Resolve bw BEFORE reading the password: if we would have nowhere trusted to
  # send it, it must never leave the Keychain in the first place.
  _bw_bin="$(_resolve_bw_bin)" || return 1
  _bw_master="$("$_SECURITY_BIN" find-generic-password -a "$_KEYCHAIN_ACCOUNT" -s bw-master -w 2>/dev/null)" || return 1
  if [ -z "$_bw_master" ]; then
    return 1
  fi
  if ! _minted="$(BW_PASSWORD="$_bw_master" "$_bw_bin" unlock --raw --passwordenv BW_PASSWORD 2>/dev/null)"; then
    _bw_master=""
    return 1
  fi
  _bw_master=""
  [ -n "$_minted" ] || return 1
  _MINTED_SESSION="$_minted"
  _MINTED_BW_BIN="$_bw_bin"
}

# Do we hold a usable session, from either source?
_have_session() {
  [ -n "${BW_SESSION:-}" ] || [ -n "$_MINTED_SESSION" ]
}

# Run bw. A self-minted session is deliberately NOT exported: it is handed to
# the already-trusted binary one invocation at a time, so neither a
# PATH-substituted `bw` nor a PATH-substituted `jq` further down the pipe ever
# has a live vault token in its environment. Minting is the case where the
# wrapper creates a token that would not otherwise exist, so it is the case
# that must not leak one.
#
# A caller-supplied BW_SESSION keeps the pre-existing behavior untouched: it is
# already exported in our environment by whoever launched us, PATH-resolved bw
# has always inherited it, and narrowing that is ADR-010's deferred separate
# proposal — not something to smuggle in here.
_bw() {
  if [ -n "$_MINTED_SESSION" ]; then
    BW_SESSION="$_MINTED_SESSION" "$_MINTED_BW_BIN" "$@"
  else
    bw "$@"
  fi
}

_UNLOCK_HINT="Run \`bw unlock\` and export BW_SESSION, or provision Keychain self-unlock: security add-generic-password -U -a \"\$USER\" -s bw-master -w"

if ! _have_session; then
  _self_unlock || true
fi
if ! _have_session; then
  echo "bw-run.sh: BW_SESSION not set. $_UNLOCK_HINT" >&2
  exit 1
fi
if ! _bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
  _self_unlock || true
  if ! _bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
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
    CACHE="$(_bw list items --search "$PREFIX")"
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
      if ! value="$(_bw get password "$item")" || [ -z "$value" ]; then
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
# This covers the caller-supplied session. A self-minted one was never exported
# in the first place (see _bw), so there is nothing here for it to drop.
unset BW_SESSION
exec "$@"
