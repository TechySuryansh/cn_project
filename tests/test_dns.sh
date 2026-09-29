#!/usr/bin/env bash
# Layer: DNS (Task B) - name -> IP via OUR server, and via the client resolver.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[DNS]"
[ -n "$DIG" ] || { t_fail "dig available" "install bind tools: brew install bind"; t_finish; exit; }
t_check "DNS server ${DNS_IP}:${DNS_PORT} answers ${APP_DOMAIN} = ${EDGE_IP}" \
  "if the resolver is down or the record is wrong, nothing after this can work" chk_dns_server
api="$("$DIG" +short +time=2 +tries=1 -p "$DNS_PORT" "@${DNS_IP}" "$API_DOMAIN" | head -1)"
[ "$api" = "$EDGE_IP" ] && t_pass "${API_DOMAIN} = ${EDGE_IP}" || t_fail "${API_DOMAIN} = ${EDGE_IP} (got '${api:-none}')" "api record missing/wrong"
t_check "client resolver (what a browser uses) returns ${EDGE_IP}" \
  "client is not configured to use our DNS (see scripts/configure-client-dns.sh)" chk_dns_client
t_finish
