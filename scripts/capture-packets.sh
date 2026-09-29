#!/usr/bin/env bash
# Optional, BOUNDED packet capture for Task G. Never runs indefinitely.
#   scripts/capture-packets.sh [seconds=60] [outfile]
# While it runs, in another terminal:  curl -v https://app.<team>.test:<port>/api/status
# Open the resulting .pcap in Wireshark. Useful display filters:
#   dns  |  tcp.flags.syn==1  |  tls.handshake  |  tcp.port==8443
set -euo pipefail
. "$(dirname "$0")/common.sh"; load_config
secs="${1:-60}"; [[ "$secs" =~ ^[0-9]+$ ]] || die "seconds must be a number"
[ "$secs" -le 600 ] || die "refusing captures longer than 600s"
iface="$(route -n get default | awk '/interface:/{print $2}')"
out="${2:-$REPO_ROOT/evidence/phase1-$(date +%Y%m%d-%H%M%S).pcap}"
info "Capturing ${secs}s on $iface -> $out  (filter: DNS port ${DNS_PORT} or edge port ${EDGE_PORT})"
info "Generate traffic now in another terminal. Ctrl-C stops early."
sudo_run perl -e 'alarm shift; exec @ARGV' "$secs" tcpdump -i "$iface" -n -w "$out" "port ${DNS_PORT} or port ${EDGE_PORT} or port ${BACKEND_A_PORT} or port ${BACKEND_B_PORT}" 2>&1 || true
[ -f "$out" ] && sudo_run chown "$(id -un)" "$out" && ok "Saved $out ($(du -h "$out" | cut -f1))"
