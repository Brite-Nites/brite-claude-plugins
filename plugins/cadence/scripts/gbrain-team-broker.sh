#!/usr/bin/env bash
# gbrain-team-broker.sh — Bitwarden + OAuth credential broker for the team gbrain
# HTTP MCP endpoint (BC-11006, the §5.5 activation of BC-10520).
#
# At MCP spawn time:
#   1. Read client_id (.login.username) + client_secret (.login.password) from
#      the Bitwarden Engineering item "Brite team gbrain — plugin OAuth client".
#   2. POST <serve-host>/token (RFC 6749 client_credentials, client_secret_post
#      auth method, scope=read) — auth method matches gbrain's oauth-provider
#      default (see ~/code/gbrain src/core/oauth-provider.ts).
#   3. Export the resulting access_token as GBRAIN_TEAM_TOKEN, drop BW_SESSION
#      (defense-in-depth — mirrors plugins/marketing/scripts/bw-run.sh § exec).
#   4. exec mcp-remote against <mcp-url>, passing the literal string
#      'Authorization: Bearer ${GBRAIN_TEAM_TOKEN}' (single-quoted, so the
#      shell does NOT expand it). mcp-remote then expands ${GBRAIN_TEAM_TOKEN}
#      from its own env, keeping the bearer token out of argv / `ps`.
#
# Non-goals (canon scope discipline, mirrors plugins/marketing/scripts/bw-run.sh):
#   no token caching   (fresh /token per spawn; matches plugin OAuth rotation
#                      semantics — runbook.md § OAuth client_secret rotation)
#   no token refresh   (token TTL > typical session length; refresh on next spawn)
#   no file I/O        (token lives in env only; never on disk)
#   no retry           (failure surfaces early in the workflow log)
#
# Usage: gbrain-team-broker.sh <mcp-url>
#   e.g. gbrain-team-broker.sh https://brite-team-gbrain-serve-production.up.railway.app/mcp
#
# Pinned versions:
#   mcp-remote@0.1.38 (latest as of 2026-05-22). Bump deliberately + record in
#   brite-team-gbrain runbook when bumping.
set -euo pipefail

# --- Preflight --------------------------------------------------------------
for cmd in jq bw curl npx; do
  if ! command -v "$cmd" >/dev/null; then
    echo "gbrain-team-broker.sh: \`$cmd\` is required" >&2
    exit 1
  fi
done
if [ -z "${BW_SESSION:-}" ]; then
  echo "gbrain-team-broker.sh: BW_SESSION not set. Run \`bw unlock\` and export BW_SESSION." >&2
  exit 1
fi
if ! bw status 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null; then
  echo "gbrain-team-broker.sh: vault is not unlocked (BW_SESSION may be stale). Run \`bw unlock\` again." >&2
  exit 1
fi

# --- Arg parse --------------------------------------------------------------
if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "gbrain-team-broker.sh: usage: $0 <mcp-url>" >&2
  exit 2
fi
MCP_URL="$1"

# Derive the OAuth /token URL from the MCP URL's scheme+host (strip path).
# Fail fast if the input doesn't parse as a normal https://host/... URL — we
# don't want to silently POST credentials to a malformed endpoint.
TOKEN_URL="$(printf '%s' "$MCP_URL" \
  | sed -nE 's#^(https?://[^/]+)(/.*)?$#\1/token#p')"
if [ -z "$TOKEN_URL" ]; then
  echo "gbrain-team-broker.sh: could not derive /token URL from MCP URL \`$MCP_URL\`" >&2
  exit 2
fi

# --- Fetch OAuth client from Bitwarden --------------------------------------
BW_ITEM='Brite team gbrain — plugin OAuth client'
if ! ITEM_JSON="$(bw get item "$BW_ITEM" 2>/dev/null)"; then
  echo "gbrain-team-broker.sh: \`bw get item\` failed for \`$BW_ITEM\` (Engineering collection)" >&2
  exit 3
fi

CLIENT_ID="$(printf '%s' "$ITEM_JSON" | jq -r '.login.username // ""')"
CLIENT_SECRET="$(printf '%s' "$ITEM_JSON" | jq -r '.login.password // ""')"
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "gbrain-team-broker.sh: \`$BW_ITEM\` missing username (client_id) or password (client_secret)" >&2
  exit 3
fi
unset ITEM_JSON

# --- /token exchange --------------------------------------------------------
# Use curl's --data-urlencode so client_id/client_secret with special chars
# don't break the form encoding. -sS keeps progress quiet but surfaces errors.
# Body stays off stderr; we parse via jq so a non-JSON response surfaces as
# "unknown" rather than echoing the raw body (which could include error data).
if ! TOKEN_RESP="$(curl -sS -X POST "$TOKEN_URL" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "scope=read" \
      --data-urlencode "client_id=$CLIENT_ID" \
      --data-urlencode "client_secret=$CLIENT_SECRET")"; then
  echo "gbrain-team-broker.sh: curl POST $TOKEN_URL failed (network / DNS)" >&2
  unset CLIENT_ID CLIENT_SECRET
  exit 4
fi
unset CLIENT_ID CLIENT_SECRET

ACCESS_TOKEN="$(printf '%s' "$TOKEN_RESP" | jq -r '.access_token // empty' 2>/dev/null || true)"
if [ -z "$ACCESS_TOKEN" ]; then
  ERR_DESC="$(printf '%s' "$TOKEN_RESP" | jq -r '.error_description // .error // "unknown"' 2>/dev/null || echo "unknown")"
  echo "gbrain-team-broker.sh: /token exchange at $TOKEN_URL failed: $ERR_DESC" >&2
  unset TOKEN_RESP
  exit 4
fi
unset TOKEN_RESP

export GBRAIN_TEAM_TOKEN="$ACCESS_TOKEN"
unset ACCESS_TOKEN

# --- Defense-in-depth: drop vault session before exec -----------------------
# The wrapped mcp-remote process (and any transitive npm dep it loads) should
# never have BW_SESSION in its env — same rationale as bw-run.sh's BW_SESSION
# unset before exec.
unset BW_SESSION

# --- Bridge stdio ↔ HTTP MCP via mcp-remote ---------------------------------
# Single-quoted '${GBRAIN_TEAM_TOKEN}' is intentional: the literal string
# reaches mcp-remote, which expands it from its own env. Token never crosses
# argv, so it doesn't appear in `ps` / process listings.
# shellcheck disable=SC2016  # Literal ${VAR} expanded by mcp-remote, not shell.
exec npx -y mcp-remote@0.1.38 "$MCP_URL" --header 'Authorization: Bearer ${GBRAIN_TEAM_TOKEN}'
