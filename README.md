# Learn Vault Agent IAM

This is a Docker Compose lab that stands up a pre-configured Vault Enterprise
server for the
[Secure agent permissions with Vault](https://developer.hashicorp.com/vault/tutorials/enterprise/manage-secure-agentic-workflows)
tutorial. One `docker compose up` gives you a TLS-enabled Vault server, seeded
secrets, ACL policies, a file audit device, and two personas with username and
password authentication enabled.

## Container infrastructure

| Service      | Purpose                                                       |
|--------------|---------------------------------------------------------------|
| `tls-init`   | Runs **mkcert** to generate TLS material.                     |
| `vault`      | Vault Enterprise `latest`, 1 node, integrated storage, TLS.   |
| `vault-init` | Idempotent one-shot bootstrap to configure Vault environment. |

### Automatically pre-configured

- **TLS** with [mkcert](https://github.com/filosottile/mkcert).
  The CA certificate gets saved to `./tls/vault-ca.pem` and
  referenced through `VAULT_CACERT`, so the command line tool verifies TLS
  without errors or the need to use `VAULT_SKIP_VERIFY`.

- **File audit device** (`file/`) at `./logs/vault-server-audit-log.json`.

- **KV v2** engine at `hashicups-kv` seeded with:
  - `hashicups-kv/repo/github-token`
  - `hashicups-kv/prod/db-password`

- **ACL policies**:
  - `oliver-sudo`: every Vault API capability (`create, read, update, patch,
    delete, list, sudo`) on path `*`.
  - `danielle-developer`: full read/write across `hashicups-kv` (the human
    baseline from the tutorial).
  - `agent-repo-reviewer-ceiling`: read-only, repo-only (the agent ceiling).

- **userpass** auth method with two users:

  | User       | Password                            | Policy               |
  |------------|-------------------------------------|----------------------|
  | `oliver`   | `oliver-example-YgGk0ycnbrUOOEux`   | `oliver-sudo`        |
  | `danielle` | `danielle-example-8HMurmZddhPBM5KR` | `danielle-developer` |

### Not automated

As the learner, you perform these steps from the related tutorial:

- Create an OAuth resource server **profile**.
- Create the subject/actor **identity entities and aliases**.
- Register your agent in the **Agent Registry**.

## Requirements

- Docker with Compose v2.
- Internet access on first run (pulls the Vault image and the `mkcert` binary).
- A valid Vault Enterprise license. Export it as `VAULT_LICENSE` in your host
  environment before starting the lab:

  ```shell
  export VAULT_LICENSE="<your-vault-enterprise-license-string>"
  ```

  Compose passes this value through to the Vault server. If `VAULT_LICENSE` is
  unset, `docker compose up` fails fast with a reminder to export the
  environment variable.

- The Vault command line tool on your host (optional, but recommended if you
  want to drive the lab from the host instead of `docker compose exec`).

## Use the lab

1. Clone the repository.

    ```shell
    git clone https://https://github.com/hashicorp-education/learn-vault-agentic-iam
    ```

1. Change into the project directory.

    ```shell
    cd learn-vault-agentic-iam
    ```

1. Export your Vault Enterprise license string as the value of the
   `VAULT_LICENSE` environment variable. Use your actual value instead of
   the truncated example value.

    ```shell
    export VAULT_LICENSE=3894JFNCOFFEE...
    ```

1. Deploy the containers.

    ```shell
    docker compose up -d
    ```

1. Check progress in the logs.

    ```shell
    $ docker compose logs vault-init | grep 'Vault lab is preconfigured and ready'
    vault-init-1  | [bootstrap] Vault lab is preconfigured and ready.
    ```

When Vault is ready, move on to configure your shell with the `env.sh` file.

1. Source the environment file to set important environment variables.

    ```shell
    source ./env.sh
    VAULT_ADDR   = https://127.0.0.1:8200
    VAULT_CACERT = .../tls/vault-ca.pem
    VAULT_TOKEN  = (root token loaded)
    ```

1. Verify Vault server status.

    ```shell
    vault status
    ```

1. Authenticate to Vault as the operator persona.

    ```shell
    vault login -method=userpass \
        username=oliver
    ```

    When prompted for a password, enter: `oliver-example-YgGk0ycnbrUOOEux`

1. Check ACL policies

    ```shell
    vault policy list
    ```

At this point you have completed the "Set up the lab" section of the tutorial.

## Files

```plaintext
docker-compose.yml          Service definitions
.env.example                Optional overrides (passwords)
env.sh                      Source to set VAULT_ADDR / VAULT_CACERT / VAULT_TOKEN
scripts/
  Dockerfile.mkcert         mkcert helper image
  gen-certs.sh              Generates TLS material + captures the CA cert
  bootstrap.sh              Init, unseal, and preconfigure Vault (idempotent)
vault/
  config/server.hcl         Vault server configuration
  init/vault-init.json      Generated unseal key + root token (gitignored)
tls/                        Generated mkcert CA + server cert/key (gitignored)
logs/                       Audit + server logs (gitignored)
```

## Customize

Copy `.env.example` to `.env` to change the user password values.

```shell
cp .env.example .env
```

## Clean up

Stop containers and remove all data.

```shell
docker compose down --remove-orphans
```

Remove the Vault data, logs, and initialization file.

```shell
rm -rf tls/* logs/* vault/data vault/init/vault-init.json
```

## Notes

- The server certificate is valid for `localhost`, `vault`, `127.0.0.1`, and
  `::1`. The in-cluster `vault-init` container reaches the server at
  `https://vault:8200`; you reach it from the host at `https://127.0.0.1:8200`.

- Root token use is for bootstrapping only. The tutorial recommends a scoped
  administrative token for real operator work.
