#!/usr/bin/env bash
# Install ONLY the public CA certificate into this Mac's System keychain so
# curl/Safari/Chrome trust https://app.<team>.test without -k.  Usage:
#   scripts/install-ca.sh [path/to/ca.crt]     |   scripts/install-ca.sh --remove
set -euo pipefail
. "$(dirname "$0")/common.sh"
load_config
LABEL="CN Phase1 Local CA (${TEAM})"
if [ "${1:-}" = "--remove" ]; then
  removed=0
  while security find-certificate -c "$LABEL" /Library/Keychains/System.keychain >/dev/null 2>&1; do
    sudo_run security delete-certificate -c "$LABEL" /Library/Keychains/System.keychain || break
    removed=1
  done
  [ $removed -eq 1 ] && ok "Removed $LABEL from System keychain" || warn "not installed"
  exit 0
fi

crt="${1:-$CN_CA_CERT_REPO}"
[ -f "$crt" ] || die "CA certificate not found: $crt (run: git pull; Pranjal must run edge setup first)"
grep -q "PRIVATE KEY" "$crt" && die "Refusing: $crt contains a private key"

target_fp="$(openssl x509 -in "$crt" -noout -fingerprint -sha1 2>/dev/null | cut -d= -f2 || true)"
existing_fp="$(security find-certificate -c "$LABEL" -p /Library/Keychains/System.keychain 2>/dev/null | openssl x509 -noout -fingerprint -sha1 2>/dev/null | cut -d= -f2 || true)"

if [ -n "$existing_fp" ]; then
  if [ "$existing_fp" = "$target_fp" ]; then
    ok "CA already trusted and matches $crt"
    exit 0
  fi
  info "Keychain has an older/different CA certificate for '$LABEL'. Removing it first..."
  while security find-certificate -c "$LABEL" /Library/Keychains/System.keychain >/dev/null 2>&1; do
    sudo_run security delete-certificate -c "$LABEL" /Library/Keychains/System.keychain || break
  done
fi

info "Adding CA to the System keychain (needs admin password)"
sudo_run security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$crt"
ok "CA trusted. Remove later with: scripts/install-ca.sh --remove"
