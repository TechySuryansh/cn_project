#!/usr/bin/env bash
# ONE-TIME ADMIN STEP (Suryansh only): create the two tunnels and the private
# IP routes in your Cloudflare account, then produce one credential file per
# backend owner. Nothing here is committed to git.
#   admin/bootstrap-cloudflare.sh [--dry-run]
#
# What it automates (cloudflared CLI):
#   cloudflared tunnel login                  (opens browser, one time)
#   cloudflared tunnel create cn-backend-a/b
#   cloudflared tunnel route ip add 10.250.0.3/32 cn-backend-a
#   cloudflared tunnel route ip add 10.250.0.4/32 cn-backend-b
# What CANNOT be scripted safely (dashboard, see docs/CLOUDFLARE_MODE.md):
#   - creating the Zero Trust organisation / free plan
#   - Split Tunnels must INCLUDE 10.250.0.0/24 for WARP clients
#   - allowing Pranjal's device to enrol (Device enrollment permissions)
set -euo pipefail
. "$(dirname "$0")/../scripts/common.sh"
load_config; ensure_dirs
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
need_cmd cloudflared
run() { if [ "$dry" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

OUT="$CN_CONFIG_DIR/admin-out"; mkdir -p "$OUT"; chmod 700 "$OUT"

if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
  info "Logging in to Cloudflare (browser will open; choose your account/zone)"
  run cloudflared tunnel login
else ok "Already logged in (~/.cloudflared/cert.pem)"; fi

make_tunnel() {  # name ip
  local name="$1" ip="$2" cred
  if [ "$dry" = 0 ] && cloudflared tunnel list -o json 2>/dev/null | python3 -c 'import json,sys;sys.exit(0 if any(t["name"]==sys.argv[1] for t in json.load(sys.stdin) or []) else 1)' "$name"; then
    ok "Tunnel $name already exists"
  else
    run cloudflared tunnel create "$name"
  fi
  run cloudflared tunnel route ip add "${ip}/32" "$name" || warn "route ${ip}/32 may already exist"
  if [ "$dry" = 0 ]; then
    local id; id="$(cloudflared tunnel list -o json | python3 -c 'import json,sys;print(next(t["id"] for t in json.load(sys.stdin) if t["name"]==sys.argv[1]))' "$name")"
    cred="$HOME/.cloudflared/${id}.json"
    if [ -f "$cred" ]; then install -m 600 "$cred" "$OUT/credentials-${name}.json"; ok "Credential for $name -> $OUT/credentials-${name}.json"
    else warn "$cred not found (tunnel created elsewhere?). Use: cloudflared tunnel token $name > file"; fi
  fi
}
make_tunnel "${TUNNEL_EDGE_NAME:-cn-edge}" "${TUNNEL_EDGE_IP:-10.250.0.2}"
make_tunnel "$TUNNEL_A_NAME" "$TUNNEL_A_IP"
make_tunnel "$TUNNEL_B_NAME" "$TUNNEL_B_IP"

cat <<MSG

Done. Now:
 1. Credentials generated in $OUT:
    - Give Pranjal    $OUT/credentials-${TUNNEL_EDGE_NAME:-cn-edge}.json  (runs Edge setup with --credentials)
    - Give Ajeesh     $OUT/credentials-${TUNNEL_A_NAME}.json            (runs mac3-ajeesh with --credentials)
    - Give Sarvajeet  $OUT/credentials-${TUNNEL_B_NAME}.json            (runs mac4-sarvajeet with --credentials)
 2. Dashboard (manual, one time): Zero Trust > Settings > WARP Client > Device settings >
    Split Tunnels: make sure 10.250.0.0/24 is NOT excluded (or use 'Include' mode with it).
 3. Suryansh and Pranjal install Cloudflare WARP and sign in to your Zero Trust team.
See docs/CLOUDFLARE_MODE.md.
MSG
