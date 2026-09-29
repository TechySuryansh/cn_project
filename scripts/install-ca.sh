#!/usr/bin/env bash
# Install ONLY the public CA certificate into this Mac's System keychain so
# curl/Safari/Chrome trust https://app.<team>.test without -k.  Usage:
#   scripts/install-ca.sh [path/to/ca.crt]     |   scripts/install-ca.sh --remove
set -euo pipefail
. "$(dirname "$0")/common.sh"
load_config
LABEL="CN Phase1 Local CA (${TEAM})"
if [ "${1:-}" = "--remove" ]; then
  sudo_run security delete-certificate -c "$LABEL" /Library/Keychains/System.keychain || warn "not installed"
  exit 0
fi
crt="${1:-$CN_CA_CERT_REPO}"
[ -f "$crt" ] || die "CA certificate not found: $crt (run: git pull; Vaibhav must run his setup first)"
grep -q "PRIVATE KEY" "$crt" && die "Refusing: $crt contains a private key"
if security find-certificate -c "$LABEL" /Library/Keychains/System.keychain >/dev/null 2>&1; then
  ok "CA already trusted"; exit 0
fi
info "Adding CA to the System keychain (needs admin password)"
sudo_run security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$crt"
ok "CA trusted. Remove later with: scripts/install-ca.sh --remove"
