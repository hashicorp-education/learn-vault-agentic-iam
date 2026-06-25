# Source this file to configure your shell for the lab:
#   source ./env.sh
#
# It points the Vault CLI at the lab server and uses the mkcert CA so that
# TLS verification succeeds without VAULT_SKIP_VERIFY.

_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="${_here}/tls/vault-ca.pem"

echo "VAULT_ADDR   = ${VAULT_ADDR}"
echo "VAULT_CACERT = ${VAULT_CACERT}"
