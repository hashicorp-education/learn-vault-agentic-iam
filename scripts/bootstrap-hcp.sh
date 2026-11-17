#!/bin/sh
# Configure the Agent IAM tutorial resources in an existing HCP Vault namespace.
#
# Set VAULT_ADDR, VAULT_TOKEN, and VAULT_NAMESPACE in the environment, then run:
#   ./scripts/bootstrap-hcp.sh

set -eu

log() { echo "[bootstrap-hcp] $*"; }
fail() {
    log "ERROR: $*" >&2
    exit 1
}

: "${VAULT_ADDR:?Set VAULT_ADDR to the HCP Vault address.}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN to a token with setup permissions.}"
: "${VAULT_NAMESPACE:?Set VAULT_NAMESPACE to the target namespace.}"

if ! command -v vault >/dev/null 2>&1; then
    fail "The Vault CLI is required."
fi

export VAULT_ADDR VAULT_TOKEN VAULT_NAMESPACE

log "Checking Vault access at ${VAULT_ADDR} in namespace ${VAULT_NAMESPACE} ..."
if ! vault token lookup >/dev/null 2>&1; then
    fail "Could not authenticate with the supplied token in the target namespace."
fi

###############################################################################
# KV v2 secrets engine + seed secrets.
###############################################################################
if vault secrets list 2>/dev/null | grep -q '^hashicups-kv/'; then
    if ! vault read -format=json sys/mounts/hashicups-kv/tune 2>/dev/null \
        | grep -Eq '"version"[[:space:]]*:[[:space:]]*"2"'; then
        fail "The existing hashicups-kv mount is not KV v2, or its version could not be verified."
    fi
    log "Secrets engine 'hashicups-kv/' already enabled as KV v2."
else
    log "Enabling KV v2 at hashicups-kv ..."
    vault secrets enable -path=hashicups-kv kv-v2 >/dev/null
fi

log "Seeding example secrets ..."
vault kv put hashicups-kv/repo/github-token \
    token="ghp_demoRepoReadToken123" >/dev/null
vault kv put hashicups-kv/prod/db-password \
    password="superSecretProdPw" >/dev/null

###############################################################################
# ACL policies.
###############################################################################
log "Writing ACL policies ..."

vault policy write danielle-developer - >/dev/null <<'EOF'
path "hashicups-kv/data/*"     { capabilities = ["create","read","update","delete","list"] }
path "hashicups-kv/metadata/*" { capabilities = ["read","list"] }
EOF

vault policy write agent-repo-reviewer-ceiling - >/dev/null <<'EOF'
path "hashicups-kv/data/repo/*"     { capabilities = ["read"] }
path "hashicups-kv/metadata/repo/*" { capabilities = ["read","list"] }
EOF

vault policy write oliver-sudo - >/dev/null <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}
EOF

cat <<EOF

[bootstrap-hcp] ==========================================================
[bootstrap-hcp] HCP Vault namespace is ready for the Agent IAM tutorial.
[bootstrap-hcp]
[bootstrap-hcp]   VAULT_ADDR      ${VAULT_ADDR}
[bootstrap-hcp]   VAULT_NAMESPACE ${VAULT_NAMESPACE}
[bootstrap-hcp]
[bootstrap-hcp]   Secrets engine: hashicups-kv (kv-v2)
[bootstrap-hcp]     repo/github-token, prod/db-password
[bootstrap-hcp]
[bootstrap-hcp]   Policies: danielle-developer,
[bootstrap-hcp]            agent-repo-reviewer-ceiling, oliver-sudo
[bootstrap-hcp] ==========================================================
EOF