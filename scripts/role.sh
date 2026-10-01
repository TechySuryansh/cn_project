#!/usr/bin/env bash
# Usage: role.sh <suryansh|pranjal|ajeesh|sarvajeet> <setup|start|stop|status|teardown> [args]
# The macs/*/ scripts are thin wrappers around this file.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/common.sh"
. "$here/checks.sh"
load_config
. "$here/roles.sh"

role="${1:?role}"; action="${2:?action}"; shift 2 || true
ROLE="$role"

for arg in "$@"; do
  case "$arg" in
    --reconfigure|-r) export CN_RECONFIGURE=1 ;;
  esac
done

need_python() {
  python3 -c 'import sys; assert sys.version_info >= (3,8)' 2>/dev/null && { ok "python3 $(python3 -V 2>&1 | cut -d' ' -f2)"; return; }
  ensure_formula python@3.12 python3.12
  find_brew && eval "$("$BREW_BIN" shellenv)"
  have_cmd python3 || die "python3 unavailable after install"
}

common_prompts() {
  prompt_var TEAM "Team name (used in app.<team>.test)" team1
  prompt_var NETWORK_MODE "Network mode (lan|tunnel)" lan
  case "$NETWORK_MODE" in lan|tunnel) ;; *) die "NETWORK_MODE must be lan or tunnel";; esac
  load_config
}

detect_my_ip() { "$here/macos-network-info.sh" --env 2>/dev/null | awk -F= '$1=="NET_IP"{print $2}'; }

show_net_info() {
  info "Task A record (copy into your architecture doc):"
  "$here/macos-network-info.sh" | sed 's/^/    /' || warn "could not read network info"
}

# ------------------------------------------------------------------- SURYANSH
suryansh_setup() {
  banner "MAC 1 - SURYANSH - DNS + CONTROLLER + CLIENT"
  require_macos; common_prompts; require_role suryansh; ensure_dirs
  show_net_info
  if [ "$NETWORK_MODE" = "tunnel" ]; then
    save_config_var EDGE_IP "${TUNNEL_EDGE_IP:-10.250.0.2}"
    prompt_var DNS_IP "This Mac's (DNS server) IP" "127.0.0.1"
  else
    local detected_ip; detected_ip="$(detect_my_ip)"
    if [ -n "${DNS_IP:-}" ] && [ -n "$detected_ip" ] && [ "$DNS_IP" != "$detected_ip" ]; then
      warn "Current interface IP ($detected_ip) differs from configured DNS_IP ($DNS_IP)."
      prompt_var DNS_IP "Update DNS server LAN IP" "$detected_ip"
    else
      prompt_var DNS_IP "This Mac's (DNS server) LAN IP" "$detected_ip"
    fi
    prompt_var EDGE_IP "Pranjal's (edge) LAN IP"
    prompt_var AJEESH_LAN_IP "Ajeesh's (Backend A) LAN IP"
    prompt_var SARVAJEET_LAN_IP "Sarvajeet's (Backend B) LAN IP"
  fi
  load_config
  ensure_formula dnsmasq dnsmasq
  have_cmd dig || ensure_formula bind dig
  dns_start
  resolver_install 127.0.0.1
  if [ -f "$CN_CA_CERT_REPO" ]; then "$here/install-ca.sh" || warn "CA install skipped"
  else warn "pki/ca.crt not found yet. After Pranjal runs edge setup and pushes it: git pull && scripts/install-ca.sh"; fi
  echo; info "Quick checks"
  "$REPO_ROOT/tests/test_dns.sh" || true
  if chk_edge_tcp; then "$REPO_ROOT/tests/test_tls.sh" || true; else warn "Edge $EDGE_IP:$EDGE_PORT not reachable yet (Pranjal not ready?)"; fi
  echo; suryansh_status
  echo; log_paths_hint
  echo "Other Macs: run  scripts/configure-client-dns.sh   (points them at ${DNS_IP})"
}
suryansh_start() { dns_start; resolver_install 127.0.0.1; }
suryansh_stop()  { dns_stop; ok "dnsmasq stopped"; }
suryansh_status() {
  banner "MAC 1 SURYANSH - DNS / CLIENT"
  row "dnsmasq process" "$(mark dns_running)"
  row "DNS answers ${APP_DOMAIN}" "$(mark chk_dns_server)"
  row "client resolver -> edge IP" "$(mark chk_dns_client)"
  [ -f "$RESOLVER_FILE_DIR/$TEST_ZONE" ] && row "/etc/resolver/$TEST_ZONE" "present" || row "/etc/resolver/$TEST_ZONE" "MISSING"
}
suryansh_teardown() {
  dns_stop; resolver_remove
  info "dnsmasq stopped; resolver removed. CA trust kept (remove: scripts/install-ca.sh --remove)"
}

# ------------------------------------------------------------------- PRANJAL
pranjal_setup() {
  banner "MAC 2 - PRANJAL - NGINX EDGE (TLS + PROXY + LB)"
  require_macos; common_prompts; require_role pranjal; ensure_dirs
  show_net_info
  if [ "$NETWORK_MODE" = "tunnel" ]; then
    save_config_var EDGE_IP "${TUNNEL_EDGE_IP:-10.250.0.2}"
    ensure_formula cloudflared cloudflared
    have_cmd warp-cli || [ -d "/Applications/Cloudflare WARP.app" ] || { ensure_brew; info "Installing Cloudflare WARP client"; "$BREW_BIN" install --cask cloudflare-warp; }
    local cred="${CN_CREDENTIAL_FILE:-}"
    [ -z "$cred" ] && [ ! -f "$CN_SECRETS_DIR/tunnel-token" ] && [ ! -f "$CN_SECRETS_DIR/tunnel-credentials.json" ] && [ -t 0 ] && \
      read -r -p "Path to credentials-cn-edge.json Suryansh gave you (or token): " cred
    [ -n "$cred" ] && adopt_tunnel_secret "$cred"
    tunnel_reachability_hint
  else
    local detected_ip; detected_ip="$(detect_my_ip)"
    if [ -n "${EDGE_IP:-}" ] && [ -n "$detected_ip" ] && [ "$EDGE_IP" != "$detected_ip" ]; then
      warn "Current interface IP ($detected_ip) differs from configured EDGE_IP ($EDGE_IP)."
      prompt_var EDGE_IP "Update edge LAN IP" "$detected_ip"
    else
      prompt_var EDGE_IP "This Mac's (edge) LAN IP" "$detected_ip"
    fi
    prompt_var DNS_IP "Suryansh's (DNS server) LAN IP"
    prompt_var AJEESH_LAN_IP "Ajeesh's (Backend A) LAN IP"
    prompt_var SARVAJEET_LAN_IP "Sarvajeet's (Backend B) LAN IP"
  fi
  load_config
  ensure_formula nginx nginx
  have_cmd dig || ensure_formula bind dig
  "$here/create-local-ca.sh"
  [ "$NETWORK_MODE" = "lan" ] && resolver_install "$DNS_IP"
  edge_start
  echo
  for b in A B; do
    if chk_backend_direct "$b"; then ok "Backend $b reachable from edge"; else warn "Backend $b NOT reachable yet from the edge (owner must run their setup${NETWORK_MODE:+; mode=$NETWORK_MODE})"; fi
  done
  echo; pranjal_status
  echo; log_paths_hint
  echo
  info "NEXT: commit and push pki/ca.crt so clients can trust it:  git add pki/ca.crt && git commit -m 'Add public CA cert' && git push"
  info "(pki/ca.crt is the PUBLIC certificate. The private key never leaves $CN_TLS_DIR.)"
}
tunnel_reachability_hint() {
  if ! port_open "$TUNNEL_A_IP" "$BACKEND_A_PORT" 3 || ! port_open "$TUNNEL_B_IP" "$BACKEND_B_PORT" 3; then
    warn "Private routes to $TUNNEL_A_IP / $TUNNEL_B_IP not reachable yet. Checklist (docs/CLOUDFLARE_MODE.md):"
    echo "   1. Open Cloudflare WARP, log in to the team Suryansh created (Zero Trust)."
    echo "   2. Zero Trust > Settings > WARP Client > Split Tunnels must INCLUDE 10.250.0.0/24"
    echo "      (default 'Exclude' mode removes 10.0.0.0/8 from the tunnel)."
    echo "   3. Ajeesh and Sarvajeet must have run their setup (cloudflared connected)."
  fi
}
pranjal_start() { edge_start; }
pranjal_stop()  { edge_stop; ok "nginx stopped"; }
pranjal_status() {
  banner "MAC 2 PRANJAL - EDGE"
  row "nginx process" "$(mark edge_running)"
  row "TCP ${EDGE_PORT} listening" "$(mark port_open 127.0.0.1 "$EDGE_PORT" 2)"
  row "nginx config test" "$(mark edge_test_config)"
  row "Backend A upstream ${BACKEND_A_HOST}:${BACKEND_A_PORT}" "$(mark chk_backend_direct A)"
  row "Backend B upstream ${BACKEND_B_HOST}:${BACKEND_B_PORT}" "$(mark chk_backend_direct B)"
  row "TLS cert file" "$([ -f "$TLS_CERT" ] && echo present || echo MISSING)"
  [ "$NETWORK_MODE" = tunnel ] && row "Cloudflare route to backends" "$(mark chk_backend_direct A) / $(mark chk_backend_direct B)"
  return 0
}
pranjal_teardown() { edge_stop; info "nginx stopped. Config lives in $CN_CONFIG_DIR (delete manually to purge keys)."; }

# ---------------------------------------------------- AJEESH / SARVAJEET
backend_setup() {
  backend_vars
  banner "MAC $([ "$ROLE" = ajeesh ] && echo 3 || echo 4) - $(echo "$ROLE" | tr a-z A-Z) - BACKEND $B_ID"
  require_macos; common_prompts; require_role "$ROLE"; ensure_dirs
  show_net_info
  need_python
  if [ "$NETWORK_MODE" = tunnel ]; then
    ensure_formula cloudflared cloudflared
    local cred="${CN_CREDENTIAL_FILE:-}"
    [ -z "$cred" ] && [ ! -f "$CN_SECRETS_DIR/tunnel-token" ] && [ ! -f "$CN_SECRETS_DIR/tunnel-credentials.json" ] && [ -t 0 ] && \
      read -r -p "Path to the credential file Suryansh gave you (token or credentials JSON): " cred
    [ -n "$cred" ] && adopt_tunnel_secret "$cred"
  fi
  backend_start
  echo
  backend_status
  echo; log_paths_hint
}
backend_status() {
  backend_vars
  banner "MAC $([ "$ROLE" = ajeesh ] && echo 3 || echo 4) $(echo "$ROLE" | tr a-z A-Z) - BACKEND $B_ID"
  row "Backend process" "$(mark pid_alive "$B_PID")"
  row "Port $B_PORT (0.0.0.0)" "$(mark port_open 127.0.0.1 "$B_PORT" 2)"
  local h; h="$("$CURL" -s --max-time 3 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$B_PORT/health" 2>/dev/null || true)"
  row "Health (GET /health)" "$([ "$h" = 200 ] && echo "${C_GRN}PASS${C_RST}" || echo "${C_RED}FAIL${C_RST}")"
  row "X-Backend header" "$("$CURL" -sI --max-time 3 "http://127.0.0.1:$B_PORT/" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="x-backend:"{print $2}')"
  if [ "$NETWORK_MODE" = tunnel ]; then
    row "Virtual IP $B_VIP (lo0)" "$(ifconfig lo0 | grep -q "inet $B_VIP " && echo "${C_GRN}OK${C_RST}" || echo "${C_RED}MISSING${C_RST}")"
    row "Cloudflare tunnel" "$(tunnel_connected && echo "${C_GRN}CONNECTED${C_RST}" || echo "${C_RED}DOWN${C_RST}")"
  fi
  if [ "$h" = 200 ]; then echo; echo "  READY"; fi
}
backend_teardown() { backend_stop || true; }

# ------------------------------------------------------------------ dispatch
fn="${role}_${action}"
case "$role" in
  ajeesh|sarvajeet|sravjeet)
    case "$action" in
      setup) if [ "${1:-}" = "--credentials" ]; then CN_CREDENTIAL_FILE="${2:?file}"; fi; backend_setup;;
      start) backend_start; echo; backend_status;;
      stop) backend_stop;;
      status) backend_status;;
      teardown) backend_teardown;;
      *) die "unknown action $action";;
    esac;;
  pranjal)
    case "$action" in
      setup) if [ "${1:-}" = "--credentials" ]; then CN_CREDENTIAL_FILE="${2:?file}"; shift 2 || true; fi; pranjal_setup "$@";;
      *) declare -F "$fn" >/dev/null || die "unknown action '$action' for $role"; "$fn" "$@";;
    esac;;
  suryansh)
    declare -F "$fn" >/dev/null || die "unknown action '$action' for $role"
    "$fn" "$@";;
  *) die "unknown role '$role' (valid roles: suryansh, pranjal, ajeesh, sarvajeet)";;
esac
