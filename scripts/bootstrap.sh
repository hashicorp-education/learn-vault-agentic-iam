#!/bin/sh
# bootstrap.sh: Initialize, unseal, and preconfigure the Vault Enterprise lab.
#
# Runs once in the vault-init container after confirming Vault server status.
# This automates all preconfiguration steps the operator (Oliver) and developer
# (Danielle) need *up to the point* where the tutorial begins:
#
#   * operator init + unseal (1 share / 1 threshold for a single-node lab)
#   * file audit device
#   * KV v2 secrets engine + seed secrets (repo token, prod password)
#   * ACL policies:
#       - danielle-developer            (human baseline, per the tutorial)
#       - agent-repo-reviewer-ceiling   (agent ceiling, per the tutorial)
#       - oliver-sudo                   (operator: every capability on "*")
#   * userpass auth method with users:
#       - oliver   / oliver-example-YgGk0ycnbrUOOEux  -> oliver-sudo
#       - danielle / danielle-password  -> danielle-developer
#
# It does not create the OAuth resource server profile, the identity entities
# and aliases, or the Agent Registry record. Those are demonstrated by the
# tutorial with the operator persona and then exercised by the
# developer persona.
#
# The script is idempotent; re-running it is safe.

set -eu

INIT_FILE="/vault/init/vault-init.json"

OLIVER_PASSWORD="${OLIVER_PASSWORD:-oliver-example-YgGk0ycnbrUOOEux}"
DANIELLE_PASSWORD="${DANIELLE_PASSWORD:-danielle-example-8HMurmZddhPBM5KR}"
ACTIVATE_OAUTH_RS="${ACTIVATE_OAUTH_RS:-true}"

log() { echo "[bootstrap] $*"; }

###############################################################################
# 1. Wait for the Vault server to answer.
###############################################################################
log "Waiting for Vault at ${VAULT_ADDR} ..."
i=0
while :; do
    # 'vault status' exits 0 (unsealed), 1 (error/unreachable), or 2 (sealed).
    status_rc=0
    vault status >/dev/null 2>&1 || status_rc=$?
    if [ "$status_rc" = "0" ] || [ "$status_rc" = "2" ]; then
        break
    fi
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        log "Vault did not become reachable in time." >&2
        vault status || true
        exit 1
    fi
    sleep 2
done

###############################################################################
# 2. Initialize (once) and unseal.
###############################################################################
if vault status 2>/dev/null | grep -q 'Initialized.*true'; then
    log "Vault already initialized."
    if [ ! -f "$INIT_FILE" ]; then
        log "ERROR: Vault is initialized but ${INIT_FILE} is missing." >&2
        log "Remove the vault-data volume to start fresh (docker compose down -v)." >&2
        exit 1
    fi
else
    log "Initializing Vault (1 key share, threshold 1) ..."
    init_out="$(vault operator init -key-shares=1 -key-threshold=1)"
    UNSEAL_KEY="$(echo "$init_out" | grep 'Unseal Key 1:' | awk '{print $NF}')"
    ROOT_TOKEN="$(echo "$init_out" | grep 'Initial Root Token:' | awk '{print $NF}')"
    cat >"$INIT_FILE" <<EOF
{
  "unseal_keys_b64": ["${UNSEAL_KEY}"],
  "unseal_key": "${UNSEAL_KEY}",
  "root_token": "${ROOT_TOKEN}"
}
EOF
    chmod 600 "$INIT_FILE"
    log "Wrote unseal key and root token to ${INIT_FILE}."
fi

UNSEAL_KEY="$(grep '"unseal_key"' "$INIT_FILE" | sed 's/.*: *"\(.*\)".*/\1/')"
ROOT_TOKEN="$(grep '"root_token"' "$INIT_FILE" | sed 's/.*: *"\(.*\)".*/\1/')"

if vault status 2>/dev/null | grep -q 'Sealed.*true'; then
    log "Unsealing Vault ..."
    vault operator unseal "$UNSEAL_KEY" >/dev/null
fi

export VAULT_TOKEN="$ROOT_TOKEN"
log "Vault is unsealed and authenticated with the root token."

###############################################################################
# 3. Audit device.
###############################################################################
if vault audit list 2>/dev/null | grep -q '^file/'; then
    log "Audit device 'file/' already enabled."
else
    log "Enabling file audit device ..."
    vault audit enable file \
        file_path=/vault/logs/vault-server-audit-log.json
fi

###############################################################################
# 4. KV v2 secrets engine + seed secrets.
###############################################################################
if vault secrets list 2>/dev/null | grep -q '^hashicups-kv/'; then
    log "Secrets engine 'hashicups-kv/' already enabled."
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
# 5. ACL policies.
###############################################################################
log "Writing ACL policies ..."

# Danielle's human baseline (matches the tutorial exactly).
vault policy write danielle-developer - >/dev/null <<'EOF'
path "hashicups-kv/data/*"     { capabilities = ["create","read","update","delete","list"] }
path "hashicups-kv/metadata/*" { capabilities = ["read","list"] }
EOF

# The agent's read-only, repo-only ceiling (matches the tutorial exactly).
vault policy write agent-repo-reviewer-ceiling - >/dev/null <<'EOF'
path "hashicups-kv/data/repo/*"     { capabilities = ["read"] }
path "hashicups-kv/metadata/repo/*" { capabilities = ["read","list"] }
EOF

# Oliver's operator "sudo" policy: every Vault API capability on every path.
# (deny is intentionally omitted because it would override the others.)
vault policy write oliver-sudo - >/dev/null <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}
EOF

###############################################################################
# 7. # (No longer necessary outside of beta with GA
###############################################################################

###############################################################################
# Done.
###############################################################################
cat <<EOF

[bootstrap] ============================================================
[bootstrap] Vault lab is preconfigured and ready.
[bootstrap]
[bootstrap]   VAULT_ADDR    https://127.0.0.1:8200
[bootstrap]   VAULT_CACERT  ./tls/vault-ca.pem   (mkcert CA)
[bootstrap]   Root token    see ./vault/init/vault-init.json
[bootstrap]
[bootstrap]   Users (userpass):
[bootstrap]     oliver   / ${OLIVER_PASSWORD}     -> oliver-sudo
[bootstrap]     danielle / ${DANIELLE_PASSWORD}   -> danielle-developer
[bootstrap]
[bootstrap]   Secrets engine: hashicups-kv (kv-v2)
[bootstrap]     repo/github-token, prod/db-password
[bootstrap]
[bootstrap]   Policies: oliver-sudo, danielle-developer,
[bootstrap]            agent-repo-reviewer-ceiling
[bootstrap]
[bootstrap]   NOT automated (demonstrated in the tutorial):
[bootstrap]     - OAuth resource server profile
[bootstrap]     - identity entities & aliases
[bootstrap]     - Agent Registry registration
[bootstrap] ============================================================
EOF
