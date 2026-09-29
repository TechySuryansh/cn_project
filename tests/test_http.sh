#!/usr/bin/env bash
# Layer: HTTP application via the edge, by NAME (Task C/D).
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[HTTP]"
detect_trust
body="$(app_curl "$APP_URL/" 2>/dev/null)"
grep -qi "backend" <<<"$body" && t_pass "GET ${APP_URL}/ through the edge" || t_fail "GET ${APP_URL}/ through the edge" "edge could not get a response from any backend"
t_check "GET /api/status returns status ok" "application layer broken" chk_app
hdr="$(app_curl -o /dev/null -D - "$APP_URL/api/status" 2>/dev/null | tr -d '\r')"
grep -qi '^x-backend: [AB]' <<<"$hdr" && t_pass "X-Backend header present ($(grep -i '^x-backend' <<<"$hdr"))" || t_fail "X-Backend header" "backend did not label its response"
grep -qi '^HTTP/2' <<<"$hdr" && t_pass "Client<->edge protocol is HTTP/2" || t_info "client<->edge used HTTP/1.1 (HTTP/2 optional)"
t_finish
