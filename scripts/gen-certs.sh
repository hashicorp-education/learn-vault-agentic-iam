#!/bin/sh
# gen-certs.sh: Generate TLS material for the Vault server with mkcert.
#
# The script runs inside the **tls-init** container, and does the following:
#   1. Create local mkcert CA (stored under /tls/ca so it persists on the host).
#   2. Issue a server certificate valid for the names the lab uses
#      (localhost, the "vault" compose hostname, and 127.0.0.1 / ::1).
#   3. Capture the mkcert CA certificate to /tls/vault-ca.pem so it can be
#      referenced through the VAULT_CACERT environment variable.
#
# NB: The script is idempotent: existing material is reused on subsequent runs.

set -eu

TLS_DIR=/tls
SERVER_DIR="${TLS_DIR}/server"
CA_DIR="${TLS_DIR}/ca"
CA_OUT="${TLS_DIR}/vault-ca.pem"

# mkcert reads/writes its CA from CAROOT.
export CAROOT="${CA_DIR}"

mkdir -p "${SERVER_DIR}" "${CA_DIR}"

if [ -f "${SERVER_DIR}/server.pem" ] &&
    [ -f "${SERVER_DIR}/server-key.pem" ] &&
    [ -f "${CA_OUT}" ]; then
    echo "[tls-init] Existing TLS material found in ${TLS_DIR}; reusing it."
    exit 0
fi

echo "[tls-init] Creating mkcert CA in ${CAROOT} ..."
# -install would add the CA to a system trust store; inside this throwaway
# container there is nothing to trust it, so we only need the CA files created.
mkcert -CAROOT >/dev/null
# Force CA creation by issuing a throwaway cert if the root does not yet exist.
if [ ! -f "${CAROOT}/rootCA.pem" ]; then
    mkcert -cert-file /tmp/_seed.pem -key-file /tmp/_seed-key.pem localhost >/dev/null 2>&1 || true
    rm -f /tmp/_seed.pem /tmp/_seed-key.pem
fi

echo "[tls-init] Issuing Vault server certificate ..."
mkcert \
    -cert-file "${SERVER_DIR}/server.pem" \
    -key-file "${SERVER_DIR}/server-key.pem" \
    localhost vault 127.0.0.1 ::1

echo "[tls-init] Capturing mkcert CA certificate to ${CA_OUT} ..."
cp "$(mkcert -CAROOT)/rootCA.pem" "${CA_OUT}"

# Vault runs as a non-root user (uid 100); make the material readable.
chmod 644 "${CA_OUT}" "${SERVER_DIR}/server.pem" "${SERVER_DIR}/server-key.pem"

echo "[tls-init] Done. Use VAULT_CACERT=${CA_OUT} on the host (mapped to ./tls/vault-ca.pem)."
