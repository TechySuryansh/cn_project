#!/usr/bin/env bash
# Role implementations shared by macs/*/{setup,start,stop,status}.sh.
# Source after common.sh + load_config.
# shellcheck disable=SC2034

RESOLVER_FILE_DIR="/etc/resolver"

# =============================================================== DNS (Mac 1)
DNSMASQ_PID="$CN_RUN_DIR/dnsmasq.pid"
DNSMASQ_CONF="$CN_GEN_DIR/dnsmasq.conf"

dns_render() {
  ensure_dirs
  [ -n "${DNS_IP:-}" ] || die "DNS_IP not set"
  [ -n "${EDGE_IP:-}" ] || die "EDGE_IP (Vaibhav's IP) not set"
  if [ "$DNS_IP" = "127.0.0.1" ]; then DNS_LISTEN="127.0.0.1"; else DNS_LISTEN="127.0.0.1,${DNS_IP}"; fi
  export DNS_LISTEN DNSMASQ_PID
  render_template "$REPO_ROOT/config/dns/dnsmasq.conf.template" "$DNSMASQ_CONF" \
    DNS_PORT DNS_LISTEN TEST_ZONE APP_DOMAIN API_DOMAIN EDGE_IP DNS_TTL DNSMASQ_PID
}

dns_start() {
  local bin; bin="$(brew_bin dnsmasq)"; [ -x "$bin" ] || die "dnsmasq not installed (run setup)"
  dns_render
  "$bin" --test --conf-file="$DNSMASQ_CONF" >/dev/null 2>&1 || die "dnsmasq config invalid: $DNSMASQ_CONF"
  dns_stop
  : >> "$CN_LOG_DIR/dnsmasq.log"
  sudo -v
  info "Starting dnsmasq on ${DNS_LISTEN}:${DNS_PORT}"
  # shellcheck disable=SC2024  # intentional: the log file must stay owned by the user, not root
  sudo "$bin" --keep-in-foreground --conf-file="$DNSMASQ_CONF" >> "$CN_LOG_DIR/dnsmasq.log" 2>&1 &
  disown || true
  local i; for i in $(seq 1 20); do
    if dig +short +time=1 +tries=1 -p "$DNS_PORT" @127.0.0.1 "$APP_DOMAIN" 2>/dev/null | grep -q .; then
      local pid; pid="$(pgrep -f "dnsmasq.*$DNSMASQ_CONF" | tail -1 || true)"
      [ -n "$pid" ] && echo "$pid" > "$DNSMASQ_PID"
      ok "dnsmasq answering: $APP_DOMAIN -> $EDGE_IP"
      return 0
    fi
    sleep 0.3
  done
  die "dnsmasq did not answer. See $CN_LOG_DIR/dnsmasq.log"
}

dns_stop() {
  if [ -f "$DNSMASQ_PID" ]; then stop_pidfile "$DNSMASQ_PID" sudo; fi
  sudo_run pkill -f "dnsmasq.*$DNSMASQ_CONF" 2>/dev/null || true
  rm -f "$DNSMASQ_PID"
}

dns_running() {
  if [ -f "$DNSMASQ_PID" ] && kill -0 "$(cat "$DNSMASQ_PID" 2>/dev/null)" 2>/dev/null; then
    return 0
  fi
  pgrep -f "dnsmasq.*$DNSMASQ_CONF" >/dev/null 2>&1
}

# Scoped resolver: only *.<team>.test goes to our server; the rest of the
# system DNS configuration is left untouched (no System Settings edits needed).
resolver_install() {  # resolver_install <nameserver-ip>
  local ns="$1" f="$RESOLVER_FILE_DIR/$TEST_ZONE" tmp
  tmp="$(mktemp)"
  { echo "# managed by cn-phase1 (remove: bin/teardown)"; echo "nameserver $ns"; [ "$DNS_PORT" != 53 ] && echo "port $DNS_PORT"; } > "$tmp"
  sudo_run mkdir -p "$RESOLVER_FILE_DIR"
  if [ -f "$f" ] && ! grep -q "managed by cn-phase1" "$f"; then
    sudo_run cp -p "$f" "$CN_BACKUP_DIR/resolver.$TEST_ZONE.orig"
    echo "$f|$CN_BACKUP_DIR/resolver.$TEST_ZONE.orig" >> "$CN_BACKUP_DIR/INDEX"
    info "Backed up existing $f"
  fi
  sudo_run cp "$tmp" "$f"; sudo_run chmod 644 "$f"; rm -f "$tmp"
  flush_dns_cache
  ok "Resolver for .${TEST_ZONE} -> $ns  ($f)"
}

resolver_remove() {
  local f="$RESOLVER_FILE_DIR/$TEST_ZONE"
  if [ -f "$f" ] && grep -q "managed by cn-phase1" "$f"; then
    sudo_run rm -f "$f"; ok "Removed $f"
  fi
  if [ -f "$CN_BACKUP_DIR/resolver.$TEST_ZONE.orig" ]; then
    sudo_run cp -p "$CN_BACKUP_DIR/resolver.$TEST_ZONE.orig" "$f"; ok "Restored original $f"
  fi
  flush_dns_cache
}

flush_dns_cache() {
  sudo_run dscacheutil -flushcache 2>/dev/null || true
  sudo_run killall -HUP mDNSResponder 2>/dev/null || true
}

# ============================================================ EDGE (Mac 2)
NGINX_PID="$CN_RUN_DIR/nginx.pid"
NGINX_CONF="$CN_GEN_DIR/nginx.conf"
NGINX_PREFIX="$CN_RUN_DIR/nginx"
TLS_CERT="$CN_TLS_DIR/server.crt"
TLS_KEY="$CN_TLS_DIR/server.key"
LOG_DIR="$CN_LOG_DIR"

edge_render() {
  ensure_dirs
  [ -n "${BACKEND_A_HOST:-}" ] && [ -n "${BACKEND_B_HOST:-}" ] || die "Backend addresses not set (HARDIK_LAN_IP/AKSHAT_LAN_IP, or NETWORK_MODE=tunnel)"
  mkdir -p "$NGINX_PREFIX/tmp"
  export NGINX_PID NGINX_PREFIX TLS_CERT TLS_KEY LOG_DIR
  render_template "$REPO_ROOT/config/nginx/nginx.conf.template" "$NGINX_CONF" \
    NETWORK_MODE NGINX_PID LOG_DIR NGINX_PREFIX BACKEND_A_HOST BACKEND_A_PORT BACKEND_B_HOST BACKEND_B_PORT \
    UPSTREAM_MAX_FAILS UPSTREAM_FAIL_TIMEOUT UPSTREAM_CONNECT_TIMEOUT EDGE_PORT APP_DOMAIN API_DOMAIN TLS_CERT TLS_KEY
}

nginx_cmd() { "$(brew_bin nginx)" -e "$CN_LOG_DIR/nginx-error.log" -p "$NGINX_PREFIX/" -c "$NGINX_CONF" "$@"; }

edge_test_config() { edge_render; nginx_cmd -t; }

edge_start() {
  [ -x "$(brew_bin nginx)" ] || die "nginx not installed (run setup)"
  [ -f "$TLS_CERT" ] || "$REPO_ROOT/scripts/create-local-ca.sh"
  edge_render
  nginx_cmd -t || die "nginx config test failed"
  if pid_alive "$NGINX_PID"; then nginx_cmd -s reload; ok "nginx reloaded"
  else
    if [ "$EDGE_PORT" -lt 1024 ]; then sudo_run "$(brew_bin nginx)" -e "$CN_LOG_DIR/nginx-error.log" -p "$NGINX_PREFIX/" -c "$NGINX_CONF"
    else nginx_cmd; fi
    ok "nginx started on :${EDGE_PORT}"
  fi
  wait_for_port 127.0.0.1 "$EDGE_PORT" 10 || die "nginx is not listening on :$EDGE_PORT (see $CN_LOG_DIR/nginx-error.log)"
}

edge_stop() {
  if pid_alive "$NGINX_PID"; then nginx_cmd -s quit 2>/dev/null || stop_pidfile "$NGINX_PID"; fi
}

edge_running() { pid_alive "$NGINX_PID"; }

# ======================================================= BACKEND (Mac 3 / 4)
backend_vars() {
  case "$ROLE" in
    hardik) B_ID=A; B_OWNER="$BACKEND_A_OWNER"; B_PORT="$BACKEND_A_PORT"; B_VIP="$TUNNEL_A_IP"; B_TUN="$TUNNEL_A_NAME";;
    akshat) B_ID=B; B_OWNER="$BACKEND_B_OWNER"; B_PORT="$BACKEND_B_PORT"; B_VIP="$TUNNEL_B_IP"; B_TUN="$TUNNEL_B_NAME";;
    *) die "backend_vars: ROLE must be hardik or akshat (got '${ROLE:-}')";;
  esac
  B_PID="$CN_RUN_DIR/backend-$(echo "$B_ID" | tr A-Z a-z).pid"
  B_LOG="$CN_LOG_DIR/backend-$(echo "$B_ID" | tr A-Z a-z).log"
  CF_PID="$CN_RUN_DIR/cloudflared.pid"
  CF_LOG="$CN_LOG_DIR/cloudflared.log"
}

backend_start() {
  backend_vars; ensure_dirs
  if pid_alive "$B_PID"; then ok "Backend $B_ID already running"
  else
    port_open 127.0.0.1 "$B_PORT" 1 && die "Port $B_PORT is already in use by another process"
    BACKEND_ID="$B_ID" BACKEND_OWNER="$B_OWNER" PORT="$B_PORT" BIND=0.0.0.0 \
      nohup python3 "$REPO_ROOT/backends/server.py" >> "$B_LOG" 2>&1 &
    echo $! > "$B_PID"; disown || true
    wait_for_port 127.0.0.1 "$B_PORT" 10 || die "Backend did not start; see $B_LOG"
    ok "Backend $B_ID started on 0.0.0.0:$B_PORT"
  fi
  [ "$NETWORK_MODE" = "tunnel" ] && tunnel_start
  return 0
}

backend_stop() {
  backend_vars
  [ "$NETWORK_MODE" = "tunnel" ] && tunnel_stop
  stop_pidfile "$B_PID"
  ok "Backend $B_ID stopped"
}

backend_running() { backend_vars; pid_alive "$B_PID"; }

# --------------------------------------------------------- Cloudflare tunnel
tunnel_alias_up() {
  # cloudflared forwards private-network traffic to the DESTINATION IP as-is,
  # so this Mac must own the virtual IP. A /32 loopback alias does that
  # without touching the real network interface.
  if ifconfig lo0 | grep -q "inet $B_VIP "; then ok "lo0 alias $B_VIP present"; return; fi
  sudo_run ifconfig lo0 alias "$B_VIP" 255.255.255.255
  ok "Added lo0 alias $B_VIP (removed by stop/teardown or reboot)"
}
tunnel_alias_down() { ifconfig lo0 | grep -q "inet $B_VIP " && sudo_run ifconfig lo0 -alias "$B_VIP" || true; }

tunnel_start() {
  need_cmd cloudflared
  tunnel_alias_up
  if pid_alive "$CF_PID"; then ok "cloudflared already running"; return; fi
  local token="$CN_SECRETS_DIR/tunnel-token" cred="$CN_SECRETS_DIR/tunnel-credentials.json"
  : >> "$CF_LOG"
  if [ -f "$token" ]; then
    TUNNEL_TOKEN="$(cat "$token")" nohup cloudflared tunnel --no-autoupdate run >> "$CF_LOG" 2>&1 &
  elif [ -f "$cred" ]; then
    local id; id="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["TunnelID"])' "$cred")"
    cat > "$CN_GEN_DIR/cloudflared.yml" <<Y
tunnel: $id
credentials-file: $cred
warp-routing:
  enabled: true
Y
    nohup cloudflared tunnel --no-autoupdate --config "$CN_GEN_DIR/cloudflared.yml" run >> "$CF_LOG" 2>&1 &
  else
    die "No tunnel credential found. Put the file Mitul gave you at:
   $token            (token from the Zero Trust dashboard), or
   $cred   (credentials JSON from admin/bootstrap-cloudflare.sh)
 then re-run. (chmod 600 is applied automatically.)"
  fi
  echo $! > "$CF_PID"; disown || true
  local i; for i in $(seq 1 30); do
    grep -qE "Registered tunnel connection|Connection .* registered" "$CF_LOG" 2>/dev/null && { ok "cloudflared connected"; return; }
    sleep 1
  done
  warn "cloudflared has not reported a connection yet; check $CF_LOG"
}

tunnel_stop() {
  stop_pidfile "$CF_PID"
  tunnel_alias_down
}

tunnel_connected() {
  pid_alive "$CF_PID" && grep -qE "Registered tunnel connection|Connection .* registered" "$CF_LOG" 2>/dev/null
}

adopt_tunnel_secret() {  # adopt_tunnel_secret <file> -> secrets dir, chmod 600
  local src="$1" dst
  [ -f "$src" ] || die "File not found: $src"
  if grep -q '"TunnelID"' "$src"; then dst="$CN_SECRETS_DIR/tunnel-credentials.json"; else dst="$CN_SECRETS_DIR/tunnel-token"; fi
  install -m 600 "$src" "$dst"; ok "Stored credential at $dst (chmod 600)"
}

# --------------------------------------------------------------- summaries --
mark() { if "$@" >/dev/null 2>&1; then printf '%sOK%s' "$C_GRN" "$C_RST"; else printf '%sFAIL%s' "$C_RED" "$C_RST"; fi; }
row()  { printf '  %-32s %s\n' "$1" "$2"; }
