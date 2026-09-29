#!/usr/bin/env bash
# Layer: TCP (Task D/G) - three-way handshake to the edge service port.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[TCP]"
ping -c1 -W 1000 "$EDGE_IP" >/dev/null 2>&1 && t_pass "ICMP ping to edge $EDGE_IP" || t_warn "ping to $EDGE_IP failed (ICMP may be filtered; TCP result below is what matters)"
t_check "TCP connect ${EDGE_IP}:${EDGE_PORT}" \
  "IP reachable but nothing listening/allowed on that port: ports are separate from IPs" chk_edge_tcp
t_finish
