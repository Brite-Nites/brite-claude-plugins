#!/usr/bin/env bash
# bw-run.sh — POC credential broker for BC-6905 spike.
# Usage: bw-run.sh KEY=item [KEY=item ...] -- cmd args...
# Pre: BW_SESSION exported in parent env, vault unlocked.
set -euo pipefail

if [ -z "${BW_SESSION:-}" ]; then
  echo "bw-run.sh: BW_SESSION not set. Run \`bw unlock\` and export BW_SESSION." >&2
  exit 1
fi
if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
  echo "bw-run.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again." >&2
  exit 1
fi

# Parse KEY=item args until -- separator
declare -a EXPORTS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do
  case "$1" in
    *=*) EXPORTS+=("$1") ;;
    *)   echo "bw-run.sh: unexpected arg \`$1\` (expected KEY=item or --)" >&2; exit 2 ;;
  esac
  shift
done
if [ "${1:-}" != "--" ]; then
  echo "bw-run.sh: missing -- separator before command" >&2
  exit 2
fi
shift  # drop --

# Fetch each key via bw get password (sequential per design decision #3)
# Guard against empty array (macOS bash 3.2 + set -u rejects "${arr[@]}" when arr is empty)
if [ "${#EXPORTS[@]}" -gt 0 ]; then
  for entry in "${EXPORTS[@]}"; do
    key="${entry%%=*}"
    item="${entry#*=}"
    value="$(bw get password "$item")" || {
      echo "bw-run.sh: bw get password failed for item \`$item\`" >&2
      exit 3
    }
    # T8 instrumentation (TEMPORARY — strip in T10 per plan): log first 8
    # hex chars of SHA-256 of the fetched value so Q6 rotation propagation
    # can be observed without exposing the secret.
    sha=$(printf '%s' "$value" | shasum -a 256 | awk '{print substr($1,1,8)}')
    echo "bw-run.sh: $key fetched [sha256=$sha]" >&2
    export "$key=$value"
  done
fi

# Exec the wrapped command with env populated
exec "$@"
