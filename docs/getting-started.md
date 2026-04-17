# Getting Started

This guide walks through setting up a local kind-based development environment.

## Prerequisites

- Docker
- [kind](https://kind.sigs.k8s.io)
- `kubectl`
- `terraform`
- JDK 17+
- `jq`

> **Windows users**: use WSL2. The seed script is bash and the Makefile uses `make` - both require a Unix environment. All commands in this guide assume a bash/zsh shell. Install Docker Desktop with WSL2 integration enabled, then run everything from inside WSL2 or you could modify the scripts for Windows.

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

Both companion repos have a `build.sh` that publishes the modified modules to your local Maven Repository (`~/.m2`). Make sure to build the companion repos before we build the main one

## 2. Configure deployment

Modify `GXEDC/deployment/local/terraform.tfvars`

```hcl
rds-host = "URL"
rds-port = "5432"
rds-master-user = "USER"
rds-master-password = "PASSWORD"

# Gaia-X metadata used by gx-issuer when calling GXDCH notary (skip this if you seed directly)
gxdch_lei = "20CHARACTERLEI"
gxdch_legal_name = "COMPANYNAME"
gxdch_country_code = "2DIGITCOUNTRYCODE"
```

In `deployment/local/consumer.tf` and `provider.tf`,
set `gxdch_public_did` and `gxdch_base_id` to your public-resolvable DID and domain. See [Testing with Gaia-X](#testing-with-gaia-x) below

See [configuration.md](./configuration.md) for full list of variables.

## 3. Start supporting services

Postgres is required. Start it via Docker Compose at `GXEDC/docker-compose.yml`

```bash
docker compose up -d
```

## 4. Build and deploy
```bash
cd GXEDC
make build # builds all the images we need
make deploy
```

> Or you could run the commands directly in `GXEDC/Makefile`

## 5. Seed

run the `seed.sh` in `GXEDC`

The script creates participants and issues credentials via OID4VCI.

If you've configured `gx-issuer`, the script also seeds a private JWK into the vaults so the issuer can sign credentials for GXDCH. By default it looks for `GXEDC/private-jwk.json` (next to `seed.sh`). Override with `PRIVATE_JWK_PATH=/path/to/key.json ./seed.sh`. Without the file, the GXDCH signing step is skipped and the issuer falls back to local credential signing.

## 6. Verify

```bash
CONSUMER_ENC=$(echo -n "did:web:consumer-identityhub%3A7083" | base64 | tr -d '\n')
curl -s "http://consumer.local/api/identity/v1alpha/participants/${CONSUMER_ENC}/credentials" \
    -H "x-api-key: c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=" | jq
```

You should see a `gx:LabelCredential` stored under the consumer.

## 7. Test the DSP flow

Create an asset, policy, and contract definitions on the provider, then request the catalog from the consumer.

## DIDs and certificates

Each participant needs a DID, a key pair, and (for Gaia-X) an approved X.509 Certificate

For local-only testing without Gaia-X the kind cluster auto-generates EC keys and uses internal `did:web` DIDs (`did:web:consumer-identityhub%3A7083` etc.). These resolve via k8s DNS and don't work outside the cluster

For Gaia-X testing, you need:

1. A **publicly-resolvable `did:web` document** hosted at a domain you control.
2. An **X.509 certificate** for that domain (Let's Encrypt works in dev).
3. The public key (JWK format) embedded in the DID document under `verificationMethod` with type `JsonWebKey2020` and `x5u` pointing to your cert chain.
4. The matching private key in JWK format

This project **does not** prescribe how to create those artifacts.

## Testing with Gaia-X

For the full end-to-end flow against real GXDCH you need a valid X.509 certificate registered in the Gaia-X Registry (ETSI trust anchors). Setup is outside of the scope of this guide. Please have a look in upstream [Gaia-X Digital Clearing House](https://gaia-x.eu) documentation.

For local development with a Let's Encrypt cert, you can run the `gx-compliance`, `gaia-x-notary-registrationnumber`, and `gx-registry` services yourself and point the connector at them via `gxdch_notary_url` / `gxdch_compliance_url`. How to run those services is documented in their respective upstream repos.
