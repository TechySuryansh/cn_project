#!/usr/bin/env bash
# Layer: TLS (Task E) - handshake + certificate validation WITHOUT -k.
. "$(dirname "$0")/../scripts/testlib.sh"
echo "[TLS]"
detect_trust
if [ "$CN_TRUST_MODE" = cacert ]; then
  t_warn "System keychain does not trust the project CA; validated with --cacert pki/ca.crt instead (run scripts/install-ca.sh)"
else
  t_pass "System trust store accepts the certificate (no -k, no --cacert)"
fi
t_check "TLS handshake + certificate chain + hostname ${APP_DOMAIN}" \
  "certificate not signed by a trusted CA, wrong SAN, or expired" chk_tls
if have_cmd openssl && [ -f "$CN_CA_CERT_REPO" ]; then
  out="$(printf '' | openssl s_client -connect "${EDGE_IP}:${EDGE_PORT}" -servername "$APP_DOMAIN" -CAfile "$CN_CA_CERT_REPO" 2>&1 || true)"
  grep -q "Verify return code: 0" <<<"$out" && t_pass "openssl s_client: Verify return code 0 ($(grep -oE 'TLSv[0-9.]+' <<<"$out" | head -1))" \
    || t_fail "openssl s_client verification" "chain does not verify against pki/ca.crt"
fi
t_finish
