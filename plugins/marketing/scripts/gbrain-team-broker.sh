#!/usr/bin/env bash
# gbrain-team-broker.sh — OAuth credential broker for the team gbrain
# HTTP MCP endpoint (BC-11006, the §5.5 activation of BC-10520).
#
# At MCP spawn time:
#   1. Read client_id + client_secret from the environment. Read mode (default)
#      uses GBRAIN_CLIENT_ID / GBRAIN_CLIENT_SECRET. Write mode (--write,
#      BC-12113) uses the SEPARATE pair GBRAIN_WRITE_CLIENT_ID /
#      GBRAIN_WRITE_CLIENT_SECRET. Neither pair substitutes for the other: a
#      write identity must never silently downgrade to a read identity (the
#      caller's put_page would 403 as working-but-wrong-identity), and the read
#      client must never be asked for a write-scope token.
#   2. POST <serve-host>/token (RFC 6749 client_credentials, client_secret_post
#      auth method, scope=read — or scope=write under --write) — auth method
#      matches gbrain's oauth-provider default (see ~/code/gbrain
#      src/core/oauth-provider.ts).
#   3. Export the resulting access_token as GBRAIN_TEAM_TOKEN, and scrub the
#      client credentials out of the environment (see § Scrub below).
#   4. exec mcp-remote against <mcp-url>, passing the literal string
#      'Authorization: Bearer ${GBRAIN_TEAM_TOKEN}' (single-quoted, so the
#      shell does NOT expand it). mcp-remote then expands ${GBRAIN_TEAM_TOKEN}
#      from its own env, keeping the bearer token out of argv / `ps`.
#
# Credential source (ADR-045): both variables are exported once in the
# developer's shell profile, exactly like BWS_ACCESS_TOKEN (ADR-044). Bitwarden
# still holds the values — the teammate copies them out at onboarding — it just
# no longer sits in the runtime path, so this script needs no `bw`, no
# BW_SESSION, and no `bw unlock`.
#
# Non-goals (canon scope discipline):
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
for cmd in jq curl npx; do
  if ! command -v "$cmd" >/dev/null; then
    echo "gbrain-team-broker.sh: \`$cmd\` is required" >&2
    exit 1
  fi
done

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

# --- Resolve the OAuth client from the environment --------------------------
# Read mode carries whichever client the teammate was issued: their own
# tier-scoped client after the BC-11758 step-2 migration, or the shared
# open-tier Engineering client until theirs lands. This script cannot tell the
# two apart and does not need to — the tier is a server-side property of the
# client itself. The vault-era personal-item → shared-item fallback chain
# existed only because the broker had to *discover* which item was present; an
# exported variable holds exactly one value, so that chain has no analogue here
# and is deliberately gone (ADR-045 § Consequences).
#
# Write mode reads a SEPARATE pair and never falls back to the read pair, by
# design. Absent = the BC-12113 register-client ceremony hasn't run for this
# developer; the server stays down and the save-results prose degrades safely
# (skip + TODO).
if [ "$WRITE_MODE" -eq 1 ]; then
  ID_VAR='GBRAIN_WRITE_CLIENT_ID'
  SECRET_VAR='GBRAIN_WRITE_CLIENT_SECRET'
  CLIENT_ID="${GBRAIN_WRITE_CLIENT_ID:-}"
  CLIENT_SECRET="${GBRAIN_WRITE_CLIENT_SECRET:-}"
  UNSET_HINT="--write needs the dedicated write-scope client, and the read pair is NOT a substitute (it would 403 on put_page). Has the BC-12113 register-client ceremony run for you?"
else
  ID_VAR='GBRAIN_CLIENT_ID'
  SECRET_VAR='GBRAIN_CLIENT_SECRET'
  CLIENT_ID="${GBRAIN_CLIENT_ID:-}"
  CLIENT_SECRET="${GBRAIN_CLIENT_SECRET:-}"
  UNSET_HINT="Copy them out of the Bitwarden item \`Brite team gbrain — my client\` (username=client_id, password=client_secret), export both from your shell profile, and relaunch Claude Code — see CONTRIBUTING.md § Team gbrain credentials."
fi

# --- Scrub the client credentials from the environment ----------------------
# In the vault era client_id/client_secret were shell locals read from `bw` and
# never exported. They now arrive as real environment variables, so without an
# explicit unset mcp-remote and every transitive npm dep it loads would inherit
# the client secret. Scrub all four the moment they are copied into locals, so
# the rest of this script — and everything it execs — runs without them. This
# is the containment property `bws` provides for free via command.env_remove on
# BWS_ACCESS_TOKEN (ADR-044 § Token containment); ADR-045 restates it as an
# obligation this script owns itself.
unset GBRAIN_CLIENT_ID GBRAIN_CLIENT_SECRET GBRAIN_WRITE_CLIENT_ID GBRAIN_WRITE_CLIENT_SECRET
# Defence-in-depth for anyone whose profile still exports a vault session from
# the pre-ADR-044 world. Nothing in this script needs it.
unset BW_SESSION

if [ -z "$CLIENT_ID" ] && [ -z "$CLIENT_SECRET" ]; then
  echo "gbrain-team-broker.sh: neither \$$ID_VAR nor \$$SECRET_VAR is set. $UNSET_HINT" >&2
  exit 3
fi
# A half-set pair is its own loud failure, never a fall-through. The vault-era
# code warned rather than silently proceeding when a retrievable-but-malformed
# item would otherwise have been masked as working-but-wrong-identity; a profile
# exporting the id but not the secret is the same class of half-finished setup
# and gets the same treatment.
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  if [ -z "$CLIENT_ID" ]; then
    MISSING_VAR="$ID_VAR"
    PRESENT_VAR="$SECRET_VAR"
  else
    MISSING_VAR="$SECRET_VAR"
    PRESENT_VAR="$ID_VAR"
  fi
  echo "gbrain-team-broker.sh: \$$MISSING_VAR is empty while \$$PRESENT_VAR is set — refusing to run a half-configured client rather than authenticating as the wrong identity. Fix your shell profile and relaunch." >&2
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

# --- Bridge stdio ↔ HTTP MCP via mcp-remote ---------------------------------
# Single-quoted '${GBRAIN_TEAM_TOKEN}' is intentional: the literal string
# reaches mcp-remote, which expands it from its own env. Token never crosses
# argv, so it doesn't appear in `ps` / process listings.
# shellcheck disable=SC2016  # Literal ${VAR} expanded by mcp-remote, not shell.
exec npx -y mcp-remote@0.1.38 "$MCP_URL" --header 'Authorization: Bearer ${GBRAIN_TEAM_TOKEN}'
