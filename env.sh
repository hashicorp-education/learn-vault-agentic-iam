# Source this file to configure your shell for the lab:
#   source ./env.sh
#
# It points the Vault CLI at the lab server and uses the mkcert CA so that
# TLS verification succeeds without VAULT_SKIP_VERIFY.

_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="${_here}/tls/vault-ca.pem"

if [ -f "${_here}/vault/init/vault-init.json" ]; then
  # Root token only to bootstrap the tutorial; use a scoped token in production.
  VAULT_TOKEN="$(grep root_token "${_here}/vault/init/vault-init.json" \
    | sed 's/.*: *"\(.*\)".*/\1/')"
  export VAULT_TOKEN
fi

echo "VAULT_ADDR   = ${VAULT_ADDR}"
echo "VAULT_CACERT = ${VAULT_CACERT}"
echo "VAULT_TOKEN  = ${VAULT_TOKEN:+(root token loaded)}"
