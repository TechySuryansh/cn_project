#!/usr/bin/env bash
# Point THIS Mac at the team DNS server for *.<team>.test only (Task B).
# Uses /etc/resolver/<zone>, so the rest of your DNS settings are untouched.
#   scripts/configure-client-dns.sh [dns-ip]   |   scripts/configure-client-dns.sh --remove
set -euo pipefail
. "$(dirname "$0")/common.sh"; load_config; . "$(dirname "$0")/roles.sh"
if [ "${1:-}" = "--remove" ]; then resolver_remove; exit 0; fi
if [ -n "${1:-}" ]; then save_config_var DNS_IP "$1"; load_config; fi
prompt_var TEAM "Team name" team1
load_config
prompt_var DNS_IP "Suryansh's (DNS server) LAN IP"
resolver_install "$DNS_IP"
[ -f "$CN_CA_CERT_REPO" ] && "$(dirname "$0")/install-ca.sh" || warn "pki/ca.crt missing (git pull after Pranjal pushes it)"
"$(command -v dig)" +short -p "$DNS_PORT" "@$DNS_IP" "$APP_DOMAIN" || true
