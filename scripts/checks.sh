#!/usr/bin/env bash
# Layered probes shared by status, tests, doctor and collect-evidence.
# Every function performs a REAL request (not just "is a process alive").
# shellcheck disable=SC2034

DIG="$(command -v dig || true)"

# Which IP would a client use for the app name? Uses the same path a browser
# would (macOS resolver honouring /etc/resolver) unless simulating.
resolve_via_system() {
  dscacheutil -q host -a name "$APP_DOMAIN" 2>/dev/null | awk '/^ip_address:/{print $2; exit}'
}
resolve_via_dig() {  # asks our DNS server directly, bypassing caches
  [ -n "$DIG" ] || return 1
  "$DIG" +short +time=2 +tries=1 -p "$DNS_PORT" "@${DNS_IP}" "$APP_DOMAIN" 2>/dev/null | head -1
}
client_resolved_ip() {
  if [ "${TEST_USE_SYSTEM_RESOLVER:-1}" = 1 ]; then resolve_via_system; else resolve_via_dig; fi
}

detect_trust() {
  CN_TRUST_MODE="system"
  if [ "${TEST_USE_SYSTEM_RESOLVER:-1}" = 0 ]; then
    local resolve=(--resolve "${APP_DOMAIN}:${EDGE_PORT}:${EDGE_IP}")
  else local resolve=(); fi
  local rc=0
  "$CURL" -sS --max-time 6 -o /dev/null ${resolve[@]+"${resolve[@]}"} "$APP_URL/__edge/health" >/dev/null 2>&1 || rc=$?
  if [ $rc -eq 60 ] || [ $rc -eq 35 ] || [ $rc -eq 77 ]; then
    [ -f "$CN_CA_CERT_REPO" ] && CN_TRUST_MODE="cacert"
  fi
}

chk_dns_server()  { [ "$(resolve_via_dig)" = "$EDGE_IP" ]; }
chk_dns_client()  { [ "$(client_resolved_ip)" = "$EDGE_IP" ]; }
chk_edge_tcp()    { port_open "$EDGE_IP" "$EDGE_PORT" 3; }
chk_tls()         { app_curl -o /dev/null "$APP_URL/__edge/health"; }
chk_edge_http()   { [ "$(app_curl "$APP_URL/__edge/health" 2>/dev/null)" = "edge ok" ]; }
chk_probe_a()     { [ "$(app_curl "$APP_URL/__probe/a" 2>/dev/null)" = "ok" ]; }
chk_probe_b()     { [ "$(app_curl "$APP_URL/__probe/b" 2>/dev/null)" = "ok" ]; }
chk_app()         { app_curl "$APP_URL/api/status" 2>/dev/null | grep -q '"status": "ok"'; }

# sample_backends N -> prints one letter per request (A/B/?)
sample_backends() {
  local n="${1:-$LB_SAMPLE_REQUESTS}" i h
  for i in $(seq 1 "$n"); do
    h="$(app_curl -o /dev/null -D - "$APP_URL/api/status" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="x-backend:"{print $2}')"
    printf '%s ' "${h:-?}"
  done
  echo
}

# direct (non-edge) reachability; only meaningful where a route exists
chk_backend_direct() {  # chk_backend_direct A|B
  if [ "$1" = A ]; then port_open "$BACKEND_A_HOST" "$BACKEND_A_PORT" 3; else port_open "$BACKEND_B_HOST" "$BACKEND_B_PORT" 3; fi
}

# Print the headers of the cacheable resource
cache_headers() { app_curl -o /dev/null -D - "$APP_URL/api/cacheable" 2>/dev/null | tr -d '\r'; }
cache_status_with_etag() {
  local etag; etag="$(cache_headers | awk 'tolower($1)=="etag:"{print $2}')"
  [ -n "$etag" ] || return 1
  app_curl -o /dev/null -w '%{http_code}' -H "If-None-Match: $etag" "$APP_URL/api/cacheable"
}

local_ip() { ipconfig getifaddr "$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')" 2>/dev/null; }
