#!/usr/bin/env bash
# Run after npm ci and ./mvnw package. Uses the demo H2 profile, not an external DB.
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob
jars=(petclinic-rest/target/spring-petclinic-rest-*.jar)
[[ ${#jars[@]} == 1 && -x petclinic-angular/node_modules/.bin/ng ]] || {
  echo 'Install Angular dependencies and build exactly one REST jar first.' >&2; exit 1;
}
# Refuse to test against an unrelated service already listening on these ports.
python3 - <<'PY'
import socket
for port in (4200, 9966):
    with socket.socket() as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(('127.0.0.1', port))
PY
work=$(mktemp -d); api_pid=; web_pid=
cleanup() {
  if [[ -n $web_pid ]]; then kill "$web_pid" 2>/dev/null || :; wait "$web_pid" 2>/dev/null || :; fi
  if [[ -n $api_pid ]]; then kill "$api_pid" 2>/dev/null || :; wait "$api_pid" 2>/dev/null || :; fi
  rm -rf -- "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
java -jar "${jars[0]}" --spring.profiles.active=h2,spring-data-jpa --server.address=127.0.0.1 --server.port=9966 >"$work/api.log" 2>&1 & api_pid=$!
(cd petclinic-angular && export NG_CLI_ANALYTICS=false && exec ./node_modules/.bin/ng serve --host 127.0.0.1 --port 4200) >"$work/web.log" 2>&1 & web_pid=$!
wait_http() {
  local url=$1 out=$2 pid=$3 log=$4
  for ((i=0; i<90; i++)); do
    kill -0 "$pid" 2>/dev/null || break
    if curl -fsS --max-time 3 "$url" >"$out" 2>/dev/null; then return 0; fi
    sleep 1
  done
  echo "Service did not become ready: $url" >&2; tail -20 "$log" >&2; return 1
}
wait_http http://127.0.0.1:9966/petclinic/actuator/health/readiness "$work/health" "$api_pid" "$work/api.log"
wait_http http://127.0.0.1:4200/ "$work/ui" "$web_pid" "$work/web.log"
grep -q '<app-root' "$work/ui"
curl -fsS --max-time 10 'http://127.0.0.1:4200/petclinic/api/v2/owners?page=0&size=1' >"$work/page"
python3 - "$work" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); page = json.loads((p / 'page').read_text())
assert json.loads((p / 'health').read_text())['status'] == 'UP'
assert page['page'] == 0 and page['size'] == 1 and len(page['content']) == 1 and page['totalElements'] > 0
print('OK: Spring readiness UP; Angular UI and proxied H2 owners page returned successfully.')
PY
