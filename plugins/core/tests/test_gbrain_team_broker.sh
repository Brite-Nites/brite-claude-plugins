#!/usr/bin/env bash
# test_gbrain_team_broker.sh — behavioural lock for scripts/gbrain-team-broker.sh
# (ADR-045). Two jobs:
#
#   1. Six-copy identity. The broker is duplicated verbatim into six plugins
#      because each plugin's .mcp.json execs its own ${CLAUDE_PLUGIN_ROOT} copy.
#      Nothing enforced that before BC-11757 lands the plugins/_shared/ move, so
#      a security fix could land in one copy and silently miss five (the
#      docs/audits/002 DEBT-1 hazard). This asserts byte-identity.
#   2. The credential contract. Read and write modes resolve SEPARATE variable
#      pairs, a write request never falls back to the read pair, a half-set pair
#      fails loudly instead of authenticating as the wrong identity, and the
#      client secret never reaches the exec'd child.
#
# Error-path cases are fully offline — the broker exits before it touches the
# network. The happy-path cases need a local /token stub and are skipped when
# python3 or curl is missing.
#
# Contract: prints `RESULT pass=N fail=N`; exit 0 iff fail=0.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BROKER="$REPO_ROOT/plugins/core/scripts/gbrain-team-broker.sh"
PLUGINS="cadence core flow-architecture marketing revops workflows"

TMP="$(mktemp -d)"
SRV_PID=""
cleanup() {
  [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

pass=0
fail=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
rc_is() { # label want_rc got_rc
  if [ "$2" = "$3" ]; then ok "$1 (rc=$3)"; else bad "$1 — want rc=$2, got rc=$3"; fi
}
has() { # label haystack needle
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 — output lacks \`$3\`" ;; esac
}
lacks() { # label haystack needle
  case "$2" in *"$3"*) bad "$1 — output leaked \`$3\`" ;; *) ok "$1" ;; esac
}

# ── 1. Six-copy identity ───────────────────────────────────────────────
echo "== six-copy identity =="
if [ ! -f "$BROKER" ]; then
  bad "canonical copy plugins/core/scripts/gbrain-team-broker.sh is missing"
else
  for p in $PLUGINS; do
    copy="$REPO_ROOT/plugins/$p/scripts/gbrain-team-broker.sh"
    if [ ! -f "$copy" ]; then
      bad "plugins/$p/scripts/gbrain-team-broker.sh is missing"
    elif cmp -s "$BROKER" "$copy"; then
      ok "plugins/$p copy is byte-identical to core"
    else
      bad "plugins/$p copy has drifted from core — all six must change together"
    fi
    if [ -f "$copy" ] && [ ! -x "$copy" ]; then
      bad "plugins/$p copy is not executable"
    fi
  done
fi

[ -f "$BROKER" ] || { printf '\nRESULT pass=%s fail=%s\n' "$pass" "$fail"; exit 1; }

# ── 2. Offline contract: args + credential resolution ──────────────────
# A stub npx keeps a misconfigured case from ever reaching the real one.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/npx" <<'STUB'
#!/usr/bin/env bash
echo "NPX_ARGV: $*"
env | sort
STUB
chmod +x "$TMP/bin/npx"
export PATH="$TMP/bin:$PATH"

# Unreachable but well-formed: these cases must exit before any network call.
URL_OFFLINE="https://gbrain.invalid/mcp"

echo "== argument handling =="
out=$(bash "$BROKER" 2>&1); rc_is "no arguments" 2 "$?"
has "usage line" "$out" "usage: "
out=$(bash "$BROKER" "not-a-url" 2>&1); rc_is "unparseable MCP URL" 2 "$?"
has "names the bad URL" "$out" "could not derive /token URL"

echo "== read mode credential resolution =="
out=$(env -u GBRAIN_CLIENT_ID -u GBRAIN_CLIENT_SECRET bash "$BROKER" "$URL_OFFLINE" 2>&1)
rc_is "read: both variables unset" 3 "$?"
has "read: names the id variable" "$out" 'GBRAIN_CLIENT_ID'
has "read: names the secret variable" "$out" 'GBRAIN_CLIENT_SECRET'
has "read: points at the vault item" "$out" 'Brite team gbrain'

out=$(env -u GBRAIN_CLIENT_SECRET GBRAIN_CLIENT_ID=id bash "$BROKER" "$URL_OFFLINE" 2>&1)
rc_is "read: secret missing, id set" 3 "$?"
has "read: refuses a half-configured client" "$out" "half-configured"
# shellcheck disable=SC2016  # Needle is literal text the broker prints, not an expansion.
has "read: names the missing half" "$out" '$GBRAIN_CLIENT_SECRET is empty'

out=$(env -u GBRAIN_CLIENT_ID GBRAIN_CLIENT_SECRET=sec bash "$BROKER" "$URL_OFFLINE" 2>&1)
rc_is "read: id missing, secret set" 3 "$?"
# shellcheck disable=SC2016  # Needle is literal text the broker prints, not an expansion.
has "read: names the missing id" "$out" '$GBRAIN_CLIENT_ID is empty'

out=$(env GBRAIN_CLIENT_ID=id GBRAIN_CLIENT_SECRET= bash "$BROKER" "$URL_OFFLINE" 2>&1)
rc_is "read: empty-string secret is treated as unset" 3 "$?"

echo "== write mode never falls back to the read pair =="
out=$(env -u GBRAIN_WRITE_CLIENT_ID -u GBRAIN_WRITE_CLIENT_SECRET \
       GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
       bash "$BROKER" --write "$URL_OFFLINE" 2>&1)
rc_is "write: fails when only the read pair is set" 3 "$?"
has "write: names the write id variable" "$out" 'GBRAIN_WRITE_CLIENT_ID'
has "write: says the read pair is no substitute" "$out" "NOT a substitute"
has "write: points at the register-client ceremony" "$out" "BC-12113"
lacks "write: does not use the read secret" "$out" "read-secret"

out=$(env -u GBRAIN_WRITE_CLIENT_SECRET GBRAIN_WRITE_CLIENT_ID=wid \
       bash "$BROKER" --write "$URL_OFFLINE" 2>&1)
rc_is "write: half-set pair fails loudly" 3 "$?"
has "write: refuses a half-configured write client" "$out" "half-configured"

echo "== no vault dependency =="
lacks "broker no longer requires bw" "$(grep -c 'command -v' "$BROKER"; grep 'for cmd in' "$BROKER")" " bw "
if grep -q 'BW_SESSION not set' "$BROKER"; then
  bad "broker still gates on BW_SESSION"
else
  ok "broker no longer gates on BW_SESSION"
fi
if grep -q 'bw get item' "$BROKER"; then
  bad "broker still reads items from the vault"
else
  ok "broker no longer reads items from the vault"
fi

# ── 3. Happy path against a local /token stub ──────────────────────────
if ! command -v python3 >/dev/null || ! command -v curl >/dev/null; then
  echo "== happy path == SKIP (python3 or curl unavailable)"
else
  echo "== happy path: scope selection and credential scrub =="
  cat > "$TMP/srv.py" <<'SRV'
import http.server, json, sys, urllib.parse
port_file, log_file = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        form = urllib.parse.parse_qs(self.rfile.read(n).decode())
        with open(log_file, 'a') as f:
            f.write(json.dumps({k: v[0] for k, v in form.items()}) + "\n")
        cid = form.get("client_id", [""])[0]
        if cid == "html-client":
            body, code, ctype = b"<html>gateway error</html>", 502, 'text/html'
        elif cid == "denied-client":
            body = json.dumps({"error": "invalid_client",
                               "error_description": "client authentication failed"}).encode()
            code, ctype = 401, 'application/json'
        else:
            body = json.dumps({"access_token": "TOK-" + form.get("scope", ["?"])[0]}).encode()
            code, ctype = 200, 'application/json'
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
srv = http.server.HTTPServer(('127.0.0.1', 0), H)
with open(port_file, 'w') as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
SRV
  python3 "$TMP/srv.py" "$TMP/port" "$TMP/posts.jsonl" &
  SRV_PID=$!
  PORT=""
  for _ in $(seq 1 100); do
    [ -s "$TMP/port" ] && PORT="$(cat "$TMP/port")" && break
    sleep 0.1
  done

  if [ -z "$PORT" ]; then
    bad "local /token stub did not start"
  else
    URL="http://127.0.0.1:$PORT/mcp"

    : > "$TMP/posts.jsonl"
    out=$(env GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
           GBRAIN_WRITE_CLIENT_ID=write-id GBRAIN_WRITE_CLIENT_SECRET=write-secret \
           BW_SESSION=stale-vault-session \
           bash "$BROKER" "$URL" 2>&1)
    rc_is "read mode reaches exec" 0 "$?"
    posted="$(cat "$TMP/posts.jsonl")"
    has "read mode requests scope=read" "$posted" '"scope": "read"'
    has "read mode sends the read client_id" "$posted" '"client_id": "read-id"'
    has "exports the minted token" "$out" "GBRAIN_TEAM_TOKEN=TOK-read"
    # shellcheck disable=SC2016  # The literal ${VAR} is the point — mcp-remote expands it.
    has "bearer stays a literal in argv" "$out" 'Bearer ${GBRAIN_TEAM_TOKEN}'
    lacks "token value never enters argv" "${out%%$'\n'*}" "TOK-read"
    lacks "child env has no GBRAIN_CLIENT_ID" "$out" "GBRAIN_CLIENT_ID="
    lacks "child env has no GBRAIN_CLIENT_SECRET" "$out" "GBRAIN_CLIENT_SECRET="
    lacks "child env has no GBRAIN_WRITE_CLIENT_ID" "$out" "GBRAIN_WRITE_CLIENT_ID="
    lacks "child env has no GBRAIN_WRITE_CLIENT_SECRET" "$out" "GBRAIN_WRITE_CLIENT_SECRET="
    lacks "child env has no read secret value" "$out" "read-secret"
    lacks "child env has no write secret value" "$out" "write-secret"
    lacks "child env has no BW_SESSION" "$out" "BW_SESSION="

    : > "$TMP/posts.jsonl"
    out=$(env GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
           GBRAIN_WRITE_CLIENT_ID=write-id GBRAIN_WRITE_CLIENT_SECRET=write-secret \
           bash "$BROKER" --write "$URL" 2>&1)
    rc_is "write mode reaches exec" 0 "$?"
    posted="$(cat "$TMP/posts.jsonl")"
    has "write mode requests scope=write" "$posted" '"scope": "write"'
    has "write mode sends the write client_id" "$posted" '"client_id": "write-id"'
    lacks "write mode never sends the read client_id" "$posted" '"client_id": "read-id"'

    out=$(env -u BW_SESSION GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
           bash "$BROKER" "$URL" 2>&1)
    rc_is "runs with no BW_SESSION in the environment" 0 "$?"

    echo "== curl argv hygiene (BC-17946) =="
    # Shim curl through a logging wrapper: record the argv exactly as
    # /proc/<pid>/cmdline would show it, then run the real curl unchanged.
    # The broker must keep client_secret out of that argv on both paths.
    REAL_CURL="$(command -v curl)"
    mkdir -p "$TMP/curlwrap"
    cat > "$TMP/curlwrap/curl" <<SHIM
#!/usr/bin/env bash
printf 'CURL_ARGV: %s\n' "\$*" >> "$TMP/curl-argv.log"
exec "$REAL_CURL" "\$@"
SHIM
    chmod +x "$TMP/curlwrap/curl"

    : > "$TMP/curl-argv.log"; : > "$TMP/posts.jsonl"
    out=$(env PATH="$TMP/curlwrap:$PATH" \
           GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
           bash "$BROKER" "$URL" 2>&1)
    rc_is "read: exchange succeeds under the argv shim" 0 "$?"
    argv_log="$(cat "$TMP/curl-argv.log")"
    has   "read: shim captured a curl invocation" "$argv_log" "CURL_ARGV: "
    lacks "read: client_secret never enters curl argv" "$argv_log" "read-secret"
    has   "read: secret still reaches /token" "$(cat "$TMP/posts.jsonl")" '"client_secret": "read-secret"'

    : > "$TMP/curl-argv.log"; : > "$TMP/posts.jsonl"
    out=$(env PATH="$TMP/curlwrap:$PATH" \
           GBRAIN_WRITE_CLIENT_ID=write-id GBRAIN_WRITE_CLIENT_SECRET=write-secret \
           bash "$BROKER" --write "$URL" 2>&1)
    rc_is "write: exchange succeeds under the argv shim" 0 "$?"
    argv_log="$(cat "$TMP/curl-argv.log")"
    has   "write: shim captured a curl invocation" "$argv_log" "CURL_ARGV: "
    lacks "write: client_secret never enters curl argv" "$argv_log" "write-secret"
    has   "write: secret still reaches /token" "$(cat "$TMP/posts.jsonl")" '"client_secret": "write-secret"'

    echo "== exit 4: token-exchange failure paths (BC-17946) =="
    out=$(env GBRAIN_CLIENT_ID=read-id GBRAIN_CLIENT_SECRET=read-secret \
           bash "$BROKER" "http://127.0.0.1:9/mcp" 2>&1)
    rc_is "curl network failure exits 4" 4 "$?"
    has "names the failed POST target" "$out" "curl POST http://127.0.0.1:9/token failed"

    out=$(env GBRAIN_CLIENT_ID=html-client GBRAIN_CLIENT_SECRET=irrelevant \
           bash "$BROKER" "$URL" 2>&1)
    rc_is "non-JSON /token response exits 4" 4 "$?"
    has   "reports unknown for a non-JSON body" "$out" "failed: unknown"
    lacks "raw non-JSON body stays out of stderr (TOKEN_RESP scrub)" "$out" "gateway error"

    out=$(env GBRAIN_CLIENT_ID=denied-client GBRAIN_CLIENT_SECRET=irrelevant \
           bash "$BROKER" "$URL" 2>&1)
    rc_is "OAuth error response exits 4" 4 "$?"
    has "surfaces error_description to the operator" "$out" "client authentication failed"
  fi
fi

printf '\nRESULT pass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
