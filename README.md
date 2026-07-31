# Gaia-X EDC (OID4VC)

Gaia-X Dataspace deployment built on the Eclipse Dataspace Connector (EDC) with OID4VC (OpenID for Verifiable Credentials) replacing DCP.

## Companion Repositories

This project depends on two companion repositories with custom EDC extensions

- **[Connector](https://github.com/yamazhen/Connector)** - fork of [eclipse-edc/Connector](https://github.com/eclipse-edc/Connector) with an OID4VP-based `IdentityService` (replaces DCP for DSP authentication).
- **[IdentityHub](https://github.com/yamazhen/IdentityHub)** - fork of [eclipse-edc/IdentityHub](https://github.com/eclipse-edc/IdentityHub) with OID4VP presentation API and OID4VCI issuer/holder protocols.

Both are built and published to Maven local, then consumed by this project. All three repos use [just](https://github.com/casey/just) for their build/deploy recipes (`just build`, `just deploy`) - make sure it is installed.

## What this repo contains
- **`extensions/`** - GXEDC extensions
    - `gx-impl` - `GaiaXCredentialValidator` plus `GaiaXLabelCredential` and `GaiaXLabelLevel` policy functions (loaded by the Connector)
    - `access-policy` - `ConnectorDid` policy function for restricting offers to specific participant DIDs (loaded by the Connector)
    - `superuser-seed` - bootstraps the Identity Hub super-user participant context
    - `catalog-node-resolver` - federated catalog target node directory
    - `dataplane-public-api` - public data-plane HTTP controller
- **`launchers/`** - Runtimes for controlplane, dataplane, identity-hub, catalog-server, issuer-service
- **`deployment/`** - Terraform for the shared base (Postgres, vault, Identity Hub) plus the `edc-tenant` Helm chart
- **`provision.sh`** - provisions one participant: database, participant context, key, Gaia-X credential and connector runtimes

## Documentation

| Doc | Purpose |
| --- | --- |
| [getting-started](./docs/getting-started.md) | Clone, build, deploy, provision |
| [architecture](./docs/architecture.md) | Module layout, protocols, design decisions |
| [configuration](./docs/configuration.md) | Env vars and `@Setting` keys |
| [status](./docs/status.md) | Feature statuses |

## Two deployment modes

1. **Pure OID4VC** - OID4VP for DSP auth, OID4VCI for credential issuance. No Gaia-X. Drop `gx-impl`.
2. **OID4VC + Gaia-X policy** - keep `gx-impl` for `gx:LabelCredential` validation and policy enforcement. Gaia-X credentials are obtained from a GXDCH out-of-band and loaded at provisioning time, optionally verified remotely via `gx-basic-functions`.

> The former `gx-issuer` / `gx-issuer-s3` extensions (in-connector GXDCH proxying and VC publishing) have been removed - credentials are now issued/obtained outside the connector and loaded at provisioning time.

All policy extensions are plug and play. `access-policy` (per-participant sharing via the `ConnectorDid` constraint) works in either mode - if you don't need it, turn it off by not building it: remove its `runtimeOnly` line from `launchers/controlplane/build.gradle.kts`. Policies referencing `ConnectorDid` are then no longer enforced, so don't create them.

## Note

The OID4VC implementation has been tested without issues but the same cannot be said for the Gaia-X addon extension

Feel free to contribute or give ideas for improvements

## License

Apache 2.0
