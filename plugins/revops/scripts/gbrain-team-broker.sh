#!/usr/bin/env bash
# gbrain-team-broker.sh — Bitwarden + OAuth credential broker for the team gbrain
# HTTP MCP endpoint (BC-11006, the §5.5 activation of BC-10520).
#
# At MCP spawn time:
#   1. Read client_id (.login.username) + client_secret (.login.password) from
#      Bitwarden. Read mode (default) resolves the teammate's personal item,
#      falling back to the shared Engineering item "Brite team gbrain — plugin
#      OAuth client". Write mode (--write, BC-12113) resolves ONLY the
#      Engineering item "Brite team gbrain — write OAuth client" — no fallback:
#      a write identity must never silently downgrade to a read identity (the
#      caller's put_page would 403 as working-but-wrong-identity), and the read
#      items must never be asked for write-scope tokens.
#   2. POST <serve-host>/token (RFC 6749 client_credentials, client_secret_post
#      auth method, scope=read — or scope=write under --write) — auth method
#      matches gbrain's oauth-provider default (see ~/code/gbrain
#      src/core/oauth-provider.ts).
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
# Usage: gbrain-team-broker.sh [--write] <mcp-url>
#   e.g. gbrain-team-broker.sh https://brite-team-gbrain-serve-production.up.railway.app/mcp
#   Only the workflows plugin's `gbrain-team-write` server passes --write (the
#   /workflows:{ship,review} save-results path, BC-12113); every `gbrain-team`
#   server entry stays read mode. The flag exists in all broker copies so the
#   six per-plugin copies remain byte-identical.
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
WRITE_MODE=0
if [ "${1:-}" = "--write" ]; then
  WRITE_MODE=1
  shift
fi
if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "gbrain-team-broker.sh: usage: $0 [--write] <mcp-url>" >&2
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
# Resolution order (BC-11758 step 2 — Model-A per-teammate clients):
#   1. "Brite team gbrain — my client" — the teammate's PERSONAL-vault item (fixed
#      name; personal vaults are per-user, so no per-user config or $USER mapping
#      is needed). Holds that teammate's tm-<name> client → tier-scoped reads.
#   2. "Brite team gbrain — plugin OAuth client" — the legacy SHARED Engineering
#      item (open-tier-only since the BC-11758 step-1 shrink). The fallback keeps
#      unmigrated teammates working until their personal client lands; it retires
#      with the shared client's revocation (proofs + 1 quiet week — brite-team-gbrain
#      runbook § federation scoping).
# The two names never collide within one user's view, so `bw get item <name>`
# stays unambiguous in both steps.
BW_ITEM_PERSONAL='Brite team gbrain — my client'
BW_ITEM_SHARED='Brite team gbrain — plugin OAuth client'
# Write mode (BC-12113): the dedicated `write`-scope service client's Engineering
# item — brite-team-gbrain runbook § OAuth clients, "Bitwarden plan (write client)".
BW_ITEM_WRITE='Brite team gbrain — write OAuth client'

# _load_client_from_item <name>: fetch the item and populate CLIENT_ID/CLIENT_SECRET.
# Returns nonzero when the item is absent OR malformed (empty username/password), so a
# retrievable-but-broken personal item falls through to the shared fallback instead of
# hard-failing the spawn (the teammate is still covered by the migration fallback).
_load_client_from_item() {
  local _json
  _json="$(bw get item "$1" 2>/dev/null)" || return 1
  CLIENT_ID="$(printf '%s' "$_json" | jq -r '.login.username // ""')"
  CLIENT_SECRET="$(printf '%s' "$_json" | jq -r '.login.password // ""')"
  [ -n "$CLIENT_ID" ] && [ -n "$CLIENT_SECRET" ]
}

if [ "$WRITE_MODE" -eq 1 ]; then
  # No fallback chain in write mode: the read items must never be handed a
  # write-scope token request, and a silent downgrade to a read identity would
  # surface later as a confusing put_page 403 instead of failing loudly here.
  # Absent item = the BC-12113 ceremony hasn't run yet — the server simply stays
  # down and the save-results prose degrades safely (skip + TODO).
  if ! _load_client_from_item "$BW_ITEM_WRITE"; then
    echo "gbrain-team-broker.sh: --write requires the Engineering-collection item \`$BW_ITEM_WRITE\` (username=client_id + password=client_secret); it is absent or malformed — has the BC-12113 register-client ceremony run?" >&2
    exit 3
  fi
elif _load_client_from_item "$BW_ITEM_PERSONAL"; then
  :  # personal (tier-scoped) identity resolved
elif _load_client_from_item "$BW_ITEM_SHARED"; then
  # If the personal item exists but is malformed, say so — silent fallback would mask a
  # half-finished ceremony (saved item, wrong fields) as working-but-wrong-identity.
  if bw get item "$BW_ITEM_PERSONAL" >/dev/null 2>&1; then
    echo "gbrain-team-broker.sh: WARNING — \`$BW_ITEM_PERSONAL\` exists but is missing username (client_id) or password (client_secret); using the shared fallback \`$BW_ITEM_SHARED\` (open tier only). Fix the personal item and relaunch." >&2
  fi
else
  echo "gbrain-team-broker.sh: no usable gbrain client item — looked for \`$BW_ITEM_PERSONAL\` (personal vault), then \`$BW_ITEM_SHARED\` (Engineering collection); each needs username=client_id + password=client_secret" >&2
  exit 3
fi

# --- /token exchange --------------------------------------------------------
# Use curl's --data-urlencode so client_id/client_secret with special chars
# don't break the form encoding. -sS keeps progress quiet but surfaces errors.
# Body stays off stderr; we parse via jq so a non-JSON response surfaces as
# "unknown" rather than echoing the raw body (which could include error data).
# Scope tracks the mode: the token must carry `write` for put_page
# (gbrain operations.ts put_page requires write scope; read tokens 403 with
# insufficient_scope), and read mode keeps requesting the minimal `read`.
if [ "$WRITE_MODE" -eq 1 ]; then TOKEN_SCOPE="write"; else TOKEN_SCOPE="read"; fi
if ! TOKEN_RESP="$(curl -sS -X POST "$TOKEN_URL" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "scope=$TOKEN_SCOPE" \
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
