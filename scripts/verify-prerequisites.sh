#!/usr/bin/env bash
# Usage: verify-prerequisites.sh [role]   -- read-only check of required tools.
set -euo pipefail
. "$(dirname "$0")/common.sh"
load_config
role="${1:-${ROLE:-}}"
rc=0
chk() { if have_cmd "$1" || [ -x "$(brew_bin "$1" 2>/dev/null || true)" ]; then ok "$1"; else fail "$1 missing ($2)"; rc=1; fi; }

require_macos
chk python3 "brew install python"
chk openssl "brew install openssl"
chk curl "ships with macOS"
chk nc "ships with macOS"
case "$role" in
  mitul)   chk dnsmasq "brew install dnsmasq"; chk dig "brew install bind";;
  vaibhav) chk nginx "brew install nginx"; chk dig "brew install bind";;
  hardik|akshat) [ "$NETWORK_MODE" = tunnel ] && chk cloudflared "brew install cloudflared";;
  "") warn "No ROLE configured yet; only generic tools checked.";;
esac
exit $rc
