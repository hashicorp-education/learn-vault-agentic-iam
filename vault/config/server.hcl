# Vault Enterprise server configuration for the agentic IAM lab.
# Single node, integrated (raft) storage, TLS enabled with mkcert material.

api_addr      = "https://127.0.0.1:8200"
cluster_addr  = "https://127.0.0.1:8201"
disable_mlock = true
ui            = true
log_level     = "info"

storage "raft" {
  path    = "/vault/data"
  node_id = "vault_node_1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/server/server.pem"
  tls_key_file  = "/vault/tls/server/server-key.pem"
}

# The license is supplied at runtime via the VAULT_LICENSE environment
# variable. Export VAULT_LICENSE with a valid license string in your host
# environment before running `docker compose up`.
