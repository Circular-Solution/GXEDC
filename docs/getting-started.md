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

> This project uses `just` (a `make` replacement) for build and deploy recipes - there is no Makefile. Install it via your package manager (`brew install just`, `apt install just`, `cargo install just`) before running the steps below.

> **Windows users**: use WSL2. The seed script is bash and the build recipes use `just` - both require a Unix environment. All commands in this guide assume a bash/zsh shell. Install Docker Desktop with WSL2 integration enabled, then run everything from inside WSL2 or you could modify the scripts for Windows.

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

Modify `GXEDC/deployment/local/terraform.tfvars`

```hcl
rds-host            = "host.docker.internal"
rds-port            = "5432"
rds-master-user     = "postgres"
rds-master-password = "localdev123"

# optional: URL of an externally hosted gx-basic-functions service
# for remote SHACL / trust chain validation. Empty = local checks only.
gx_basic_functions_url = ""
```

Participant DIDs default to the in-cluster `did:web:consumer-identityhub%3A7083` / `did:web:provider-identityhub%3A7083`; override `consumer-did` / `provider-did` / `issuer-did` for publicly-resolvable DIDs.

See [configuration.md](./configuration.md) for full list of variables.

## 3. Start supporting services

Postgres is required. Start it via Docker Compose at `GXEDC/docker-compose.yml`

```bash
docker compose up -d
```

## 4. Build and deploy
```bash
cd GXEDC
just build # builds all the images we need
just deploy
```

> Or you could run the commands directly from `GXEDC/justfile`

## 5. Seed

run the `seed.sh` in `GXEDC`

The script:

1. Seeds a private RSA JWK into the consumer/provider vaults (alias `gxdch-signing-key`) - this is the participants' signing key, published in their DID documents as verification method `JWK2020-RSA`. It looks for `GXEDC/private-jwk.json` (next to `seed.sh`); override with `PRIVATE_JWK_PATH=/path/to/key.json ./seed.sh`. The script fails without it.
2. Creates the consumer and provider participant contexts in their Identity Hubs.
3. Loads a pre-issued `gx:LabelCredential` from `GXEDC/seed-credential.jwt` into each participant (override with `SEED_CREDENTIAL_PATH`). The credential is obtained from a GXDCH out-of-band - this repo no longer proxies GXDCH issuance.

### Generating private-jwk.json from your PEM private key

Use any PEM -> JWK tool. For example with [jose](https://github.com/panva/jose):

```javascript
import * as jose from "jose";
import { readFileSync } from "fs";

const PEM_PATH = "./privkey.pem"

const pem = readFileSync(PEM_PATH, "utf8");
const key = await jose.importPKCS8(pem, "PS256", { extractable: true });
const jwk = await jose.exportJWK(key);
jwk.alg = "PS256";
jwk.kid = "JWK2020-RSA";
console.log(JSON.stringify(jwk, null, 2));
```

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
3. The public key (JWK format) embedded in the DID document under `verificationMethod` with type `JsonWebKey2020` and `x5u` pointing to your cert chain.
4. The matching private key in JWK format (this becomes `private-jwk.json` for the seed script)

This project **does not** prescribe how to create those artifacts.

## Obtaining Gaia-X credentials

The `gx:LabelCredential` loaded by the seed script must come from a GXDCH (notary + compliance). For real Gaia-X compliance you need a valid X.509 certificate registered in the Gaia-X Registry (ETSI trust anchors) - see the upstream [Gaia-X Digital Clearing House](https://gaia-x.eu) documentation. Request the credential from the GXDCH with your participant DID as subject, save it as `seed-credential.jwt`, and re-run the seed.

For remote validation of seeded credentials (SHACL + trust chain), host a `gx-basic-functions` service and point `gx_basic_functions_url` at it.
