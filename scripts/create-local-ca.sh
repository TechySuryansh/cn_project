#!/usr/bin/env bash
# Educational local CA + server certificate (Task E). Runs on the EDGE Mac.
#   - CA private key stays in ~/.config/cn-phase1/tls (chmod 600), never in git.
#   - Only the PUBLIC CA certificate is copied to pki/ca.crt so clients can
#     install it (scripts/install-ca.sh).
# Idempotent: existing CA is reused; server cert is re-issued only if missing,
# expiring within 30 days, or missing a required SAN.
set -euo pipefail
. "$(dirname "$0")/common.sh"
load_config; ensure_dirs
need_cmd openssl

CA_KEY="$CN_TLS_DIR/ca.key"; CA_CRT="$CN_TLS_DIR/ca.crt"
SRV_KEY="$CN_TLS_DIR/server.key"; SRV_CRT="$CN_TLS_DIR/server.crt"; SRV_CSR="$CN_TLS_DIR/server.csr"

if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CRT" ]; then
  info "Creating local CA"
  (umask 077; openssl ecparam -name prime256v1 -genkey -noout -out "$CA_KEY")
  cat > "$CN_TLS_DIR/ca.ext" <<X
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
X
  openssl req -x509 -new -key "$CA_KEY" -sha256 -days 1095 \
    -subj "/O=CN Phase1 Educational/CN=CN Phase1 Local CA (${TEAM})" \
    -extensions v3_ca -config <(printf '[req]\ndistinguished_name=dn\n[dn]\n[v3_ca]\n%s\n' "$(cat "$CN_TLS_DIR/ca.ext")") \
    -out "$CA_CRT"
  chmod 600 "$CA_KEY"
else
  ok "CA already exists"
fi

need_new=0
if [ ! -f "$SRV_CRT" ] || [ ! -f "$SRV_KEY" ]; then need_new=1
elif ! openssl x509 -checkend $((30*86400)) -noout -in "$SRV_CRT" >/dev/null; then need_new=1
else
  txt="$(openssl x509 -noout -text -in "$SRV_CRT")"
  grep -q "DNS:${APP_DOMAIN}" <<<"$txt" && grep -q "DNS:${API_DOMAIN}" <<<"$txt" || need_new=1
fi

if [ "$need_new" = 1 ]; then
  info "Issuing server certificate for ${APP_DOMAIN}, ${API_DOMAIN}"
  (umask 077; openssl ecparam -name prime256v1 -genkey -noout -out "$SRV_KEY")
  openssl req -new -key "$SRV_KEY" -subj "/CN=${APP_DOMAIN}" -out "$SRV_CSR"
  cat > "$CN_TLS_DIR/server.ext" <<X
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:${APP_DOMAIN},DNS:${API_DOMAIN}
authorityKeyIdentifier=keyid,issuer
subjectKeyIdentifier=hash
X
  openssl x509 -req -in "$SRV_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -out "$SRV_CRT" -days 397 -sha256 -extfile "$CN_TLS_DIR/server.ext"
  chmod 600 "$SRV_KEY"
else
  ok "Server certificate is valid and has the required SANs"
fi

mkdir -p "$REPO_ROOT/pki"
cp "$CA_CRT" "$CN_CA_CERT_REPO"
ok "Public CA certificate published to pki/ca.crt (commit this; it is NOT secret)"
ok "CA private key stays at $CA_KEY (never commit or copy it to clients)"
