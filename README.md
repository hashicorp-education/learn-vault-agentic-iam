# Learn Vault Agent IAM

This is a Docker Compose lab that stands up a pre-configured Vault Enterprise
server for the [Manage non-human identities and secure agentic workflows](https://developer.hashicorp.com/vault/tutorials/enterprise/manage-secure-agentic-workflows) tutorial.
One `docker compose up` gives you a TLS-enabled Vault server, seeded secrets,
ACL policies, a file audit device, and two personas with username and password
authentication enabled.

## Container infrastructure

| Service | Purpose |
| ------- | ------- |
| `tls-init` | Runs **mkcert** in a throwaway container to generate the Vault server certificate and capture the CA certificate. |
| `vault` | Vault Enterprise `2.0.2-ent`, single node, integrated (raft) storage, TLS enabled. |
| `vault-init` | Idempotent one-shot bootstrap to initialize, unseal, and pre-configure everything below. |

### Automatically pre-configured 

- **TLS** with [mkcert](https://github.com/filosottile/mkcert). 
  The CA certificate gets saved to `./tls/vault-ca.pem` and
  referenced through `VAULT_CACERT`, so the command line tool verifies TLS
  without errors or the need to use `VAULT_SKIP_VERIFY`.
- **Audit device** (`file/`) writing to `./logs/vault-server-audit-log.json`.
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

As the learner, you do these steps in the tutorial:

- The OAuth resource server **profile**.
- The subject/actor **identity entities and aliases**.
- The **Agent Registry** registration.

## Requirements

- Docker with Compose v2.
- Internet access on first run (pulls the Vault image and the `mkcert` binary).
- A valid Vault Enterprise license. Export it as `VAULT_LICENSE` in your host
  environment before starting the lab:

  ```shell-session
  $ export VAULT_LICENSE="<your-vault-enterprise-license-string>"
  ```

  Compose passes this value through to the Vault server. If `VAULT_LICENSE` is
  unset, `docker compose up` fails fast with a reminder.

- The Vault command line tool on your host (optional, only if you want to drive
  the lab from the host instead of `docker compose exec`).

## Use the project

1. Clone the repository.

```shell-session
git clone https://https://github.com/hashicorp-education/learn-vault-agentic-iam
```

1. Change into the project directory.

    ```shell-session
    $ cd learn-vault-agentic-iam
    ```

1. Export your Vault Enterprise license string as the value of the
   `VAULT_LICENSE` environment variable. Use your actual value instead of
   the truncated example value.

    ```shell-session
    $ export VAULT_LICENSE=3894JFNCOFFEE...
    ```

Deploy the containers.

    ```shell-session
    $ docker compose up -d
    ```

You can check progress in the logs.

```shell-session
$ docker compose logs vault-init | grep 'Vault lab is preconfigured and ready'
vault-init-1  | [bootstrap] Vault lab is preconfigured and ready.
```

If Vault is ready, move on to configure your shell with the `env.sh` file.

1. Source the environment file to set important environment variables.

    ```shell-session
    $ source ./env.sh
    VAULT_ADDR   = https://127.0.0.1:8200
    VAULT_CACERT = .../tls/vault-ca.pem
    VAULT_TOKEN  = (root token loaded)
    ```

1. Verify Vault server status.

    ```shell-session
    $ vault status
    ```

1. Authenticate to Vault as the operator persona.

    ```shell-session
    $ vault login -method=userpass \
      username=oliver
    ```

    When prompted for a password, enter: `oliver-example-YgGk0ycnbrUOOEux`

1. Check ACL policies

    ```shell-session
    $ vault policy list
    ```

At this point you have completed the "Set up the lab" section of the tutorial.

## Files

```
docker-compose.yml          Service definitions
.env.example                Optional overrides (passwords, activation flag)
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

Copy `.env.example` to `.env` to change the user passwords or switch off the
OAuth Resource Server feature activation:

```shell-session
$ cp .env.example .env
```

## Clean up

Stop containers and remove all data.

```shell-session
$ docker compose down --remove-orphans
```

Remove the Vault data, logs, and initialization file.

```
$ rm -rf tls/* logs/* vault/data vault/init/vault-init.json
```

## Notes

- The server certificate is valid for `localhost`, `vault`, `127.0.0.1`, and
  `::1`. The in-cluster `vault-init` container reaches the server at
  `https://vault:8200`; you reach it from the host at `https://127.0.0.1:8200`.
- Root token use is for bootstrapping only. The tutorial recommends a scoped
  administrative token for real operator work.
