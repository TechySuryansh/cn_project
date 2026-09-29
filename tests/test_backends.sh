#!/usr/bin/env bash
# Layer: backends (Task C) - each backend individually, through the edge probe.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[BACKENDS]"
detect_trust
t_check "Backend A healthy (edge -> ${BACKEND_A_HOST}:${BACKEND_A_PORT})" "Hardik's backend/tunnel is down or blocked" chk_probe_a
t_check "Backend B healthy (edge -> ${BACKEND_B_HOST}:${BACKEND_B_PORT})" "Akshat's backend/tunnel is down or blocked" chk_probe_b
body="$(app_curl "$APP_URL/api/status" 2>/dev/null)"
grep -q '"backend"' <<<"$body" && t_pass "/api/status JSON identifies backend: $body" || t_fail "/api/status JSON" "no backend id in body"
t_finish
