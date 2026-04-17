# Gaia-X EDC (OID4VC)

Gaia-X Dataspace deployment built on the Eclipse Dataspace Connector (EDC) with OID4VC (OpenID for Verifiable Credentials) replacing DCP.

## Companion Repositories

This project depends on two companion repositories with custom EDC extensions

- **[Connector](https://github.com/yamazhen/Connector)** - fork of [eclipse-edc/Connector](https://github.com/eclipse-edc/Connector) with an OID4VP-based `IdentityService` (replaces DCP for DSP authentication).
- **[IdentityHub](https://github.com/yamazhen/IdentityHub)** - fork of [eclipse-edc/IdentityHub](https://github.com/eclipse-edc/IdentityHub) with OID4VP presentation API and OID4VCI issuer/holder protocols.

Both are built and published to Maven local, then consumed by this project.

## What this repo contains
- **`extensions/`** - Gaia-X addon extensions
    - `gx-impl` - `GaiaXLabelCredential` and `GaiaXLabelLevel` policy functions (loaded by the Connector)
    - `gx-issuer` - `GxdchCredentialGenerator` implementing the `CredentialGenerator` SPI for real Gaia-X compliance flow (loaded by the Identity Hub)
- **`launchers/`** - Runtimes for controlplane, dataplane, identity-hub, catalog-server, issuer-service
- **`deployment/`** - Terraform modules for kind (local) and production infrastructure

## Documentation

| Doc | Purpose |
| --- | --- |
| [getting-started](./docs/getting-started.md) | Clone, build, deploy, seed |
| [architecture](./docs/architecture.md) | Module layout, protocols, design decisions |
| [configuration](./docs/configuration.md) | Env vars and `@Setting` keys |
| [status](./docs/status.md) | Feature statuses |

## Three deployment modes

1. **Pure OID4VC** - OID4VP for DSP auth, OID4VCI for credential issuance. No Gaia-X. Drop `gx-impl` + `gx-issuer`.
2. **OID4VC + Gaia-X policy** - keep `gx-impl` for policy. Seed credentials manually.
3. **Full Gaia-X** - keep both. OID4VCI auto-issues credentials via GXDCH (notary + compliance)

## Note

The OID4VC implementation has been tested without issues but the same cannot be said for the Gaia-X addon extension

Feel free to contribute or give ideas for improvements

## License

Apache 2.0
