# Getting Started

This guide walks through setting up a local kind-based development environment.

## Prerequisites

- Docker
- [kind](https://kind.sigs.k8s.io)
- `kubectl`
- `terraform`
- JDK 17+
- `jq`
- [just](https://github.com/casey/just)
- [helm](https://helm.sh)

> This project uses `just` (a `make` replacement) for build and deploy recipes - there is no Makefile. Install it via your package manager (`brew install just`, `apt install just`, `cargo install just`) before running the steps below.

> **Windows users**: use WSL2. The provisioning scripts are bash and the build recipes use `just` - both require a Unix environment. All commands in this guide assume a bash/zsh shell. Install Docker Desktop with WSL2 integration enabled, then run everything from inside WSL2 or you could modify the scripts for Windows.

## Host Entries

The local kind cluster uses ingress-nginx with hostname-based routing. Add these entries to your `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```
127.0.0.1 consumer.local provider.local
```

Without these, curl requests to `consumer.local` / `provider.local` won't resolve.

## Repository layout

The three repos should be cloned side-by-side:

* workspace/
    - Connector/
    - IdentityHub/
    - GXEDC/

## 1. Build the EDC extensions

Both companion repos have a `justfile` whose `just build` publishes the modified modules to your local Maven Repository (`~/.m2`). Make sure to build the companion repos before we build the main one

## 2. Configure deployment

Modify `GXEDC/deployment/terraform.tfvars`

```hcl
rds-host            = "host.docker.internal"
rds-port            = "5432"
rds-master-user     = "postgres"
rds-master-password = "localdev123"

# optional: URL of an externally hosted gx-basic-functions service
# for remote SHACL / trust chain validation. Empty = local checks only.
gx_basic_functions_url = ""
```

Participant DIDs are no longer terraform variables - they are passed to `provision.sh` per participant.

See [configuration.md](./configuration.md) for full list of variables.

## 3. Start supporting services

Postgres is required. Start it via Docker Compose at `GXEDC/docker-compose.yml`

```bash
docker compose up -d
```

## 4. Build and deploy the base

```bash
cd GXEDC
just build       # builds the images
just deploy-kind # kind cluster + shared base
```

Terraform deploys only what every participant shares: Postgres init, one vault, one Identity Hub, and the optional issuer and catalog server. No connectors and no participants yet.

## 5. Provision participants

Each participant is one `provision.sh` call. `provision_consumer.sh` and `provision_provider.sh` are ready-made wrappers for the two local test participants:

```bash
./provision_consumer.sh
./provision_provider.sh
```

Each run does five idempotent steps: create the tenant database, create the participant context in the shared Identity Hub (importing `KEY` or generating an Ed25519 keypair), load the `gx:LabelCredential` from `GX_JWT`, install the `edc-tenant` chart, and wait for rollout.

Required inputs are `NAME`, `DID`, `IH_URL`, `IH_SERVICE`, `VAULT_SERVICE`, `DB_HOST`, `DB_USER`, `DB_PASSWORD`; see [configuration](./configuration.md) for the full list.

Because the Identity Hub keys DID documents off the request URL, the chart also creates an `ExternalName` service named after the DID host (`did:web:consumer-identityhub%3A7083` needs `consumer-identityhub` to resolve). `provision.sh` derives that name from the DID.

## 6. Verify

```bash
CONSUMER_ENC=$(echo -n "did:web:consumer-identityhub%3A7083" | base64 | tr -d '\n')
curl -s "http://consumer.local/api/identity/v1alpha/participants/${CONSUMER_ENC}/credentials" \
    -H "x-api-key: c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=" | jq
```

You should see a `gx:LabelCredential` stored under the consumer.

## 7. Test the DSP flow

Create an asset, policy, and contract definitions on the provider, then request the catalog from the consumer.

Example of LabelCredential Policy Check:
```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  },
  "@id": "policy-name",
  "policy": {
    "@type": "odrl:Set",
    "odrl:permission": [
      {
        "odrl:action": {
          "@id": "odrl:use"
        },
        "odrl:constraint": [
          {
            "odrl:leftOperand": {
              "@id": "https://w3id.org/edc/v0.0.1/ns/GaiaXLabelCredential"
            },
            "odrl:operator": {
              "@id": "odrl:eq"
            },
            "odrl:rightOperand": "active"
          }
        ]
      }
    ]
  }
}
```

## DIDs and certificates

Each participant needs a DID, a key pair, and (for Gaia-X) an approved X.509 Certificate

For local-only testing without Gaia-X the kind cluster uses internal `did:web` DIDs (`did:web:consumer-identityhub%3A7083` etc.). These resolve via k8s DNS and don't work outside the cluster

For Gaia-X testing, you need:

1. A **publicly-resolvable `did:web` document** hosted at a domain you control.
2. An **X.509 certificate** for that domain (Let's Encrypt works in dev).
3. The public key (JWK format) embedded in the DID document under `verificationMethod` with type `JsonWebKey2020` and `x5u` pointing to your cert chain (used when requesting credentials from a GXDCH, not by this stack at runtime).

This project **does not** prescribe how to create those artifacts.

## Obtaining Gaia-X credentials

The `gx:LabelCredential` passed as `GX_JWT` must come from a GXDCH (notary + compliance). For real Gaia-X compliance you need a valid X.509 certificate registered in the Gaia-X Registry (ETSI trust anchors) - see the upstream [Gaia-X Digital Clearing House](https://gaia-x.eu) documentation. Request the credential from the GXDCH with your participant DID as subject and pass it as `GX_JWT` when provisioning.

For remote validation of loaded credentials (SHACL + trust chain), host a `gx-basic-functions` service and point `gx_basic_functions_url` at it.
