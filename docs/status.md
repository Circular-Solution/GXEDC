# Status

What's built, what's tested, what's not.

## OID4VC Protocols (Connector + IdentityHub)

| Feature | Status | Notes |
|---|---|---|
| OID4VP IdentityService (DSP auth) | Tested | End-to-end DSP auth working |
| OID4VP presentation API | Tested | Credential store query + VP signing |
| JWT signature verification via DID | Tested | Uses EDC's `DidPublicKeyResolver` |
| VP + VC signature verification | Tested | Multi-layer signature check |
| OID4VCI holder flow | Tested | Metadata → token → proof → credential → store |
| OID4VCI issuer flow | Tested | Metadata, token, credential, offers endpoints |
| `CredentialGenerator` SPI | Tested | Default local-signing implementation verified |
| OID4VCI SQL token store | Built, not integration-tested | In-memory default is covered |
| VC revocation / status list | Not implemented | |
| Deferred / batch credential issuance | Not implemented | |

## Spec-conformance update (2026-07)

Wire-level changes aligning with the final OID4VP 1.0 / OID4VCI 1.0 specs. Built and compiling; end-to-end retest pending.

| Change | Status |
|---|---|
| `decentralized_identifier:` client id prefix (request + validation) | Built, retest pending |
| `vp_token` as JSON object keyed by DCQL query id, array values | Built, retest pending |
| kid↔issuer binding and VP holder-binding checks | Built, retest pending |
| Well-known metadata inserted between host and path | Built, retest pending (needs ingress rewrite at host root) |
| `vc+jwt` ecosystem format identifier (replaces `jwt_vc_json`) | Built, retest pending |
| Holder proof signing for EC / RSA / Ed25519 keys | Built, retest pending |
| Nonce endpoint `Cache-Control: no-store` | Built |

## Access Policy Addon (access-policy)

| Feature | Status | Notes |
|---|---|---|
| `ConnectorDid` policy function | Tested | Catalog filtering, negotiation acceptance and rejection verified end-to-end |

## Gaia-X Addon (gx-impl)

| Feature | Status | Notes |
|---|---|---|
| `GaiaXLabelCredentialFunction` | Tested | Full GX Basic Functions check |
| `GaiaXLabelLevelFunction` | Built, not tested | Compiles; no integration test |
| `GaiaXCredentialValidator` local checks | Tested | Type, time, compliantCredentials |
| `gx-basic-functions` remote validation | Tested | Requires externally hosted service (`EDC_GAIAX_BASIC_FUNCTIONS_URL`) |

> The former `gx-issuer` GXDCH proxy and `VcPublisher`/S3 publishing were removed - Gaia-X credentials are now obtained out-of-band and seeded via the Identity API.
