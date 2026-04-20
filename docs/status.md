# Status

What's built, what's tested, what's not.

## OID4VC Protocols (Connector + IdentityHub)

| Feature | Status | Notes |
|---|---|---|
| OID4VP IdentityService (DSP auth) | Tested | End-to-end DSP auth working |
| OID4VP presentation API | Tested | Credential store query + VP signing |
| JWT signature verification via DID | Tested | Uses EDC's `DidPublicKeyResolver` |
| VP + VC signature verification | Tested | Multi-layer signature check |
| OID4VCI holder flow |  Tested | Metadata → token → proof → credential → store |
| OID4VCI issuer flow |  Tested | Metadata, token, credential, offers endpoints |
| `CredentialGenerator` SPI |  Tested | Default local-signing implementation verified |
| OID4VCI SQL token store | Built, not integration-tested | In-memory default is covered |
| VC revocation / status list | Not implemented | |
| Deferred / batch credential issuance | Not implemented | |

## Gaia-X Addon (gaiax-edc)

| Feature | Status | Notes |
|---|---|---|
| `GaiaXLabelCredentialFunction` | Tested | Full GX Basic Functions check |
| `GaiaXLabelLevelFunction` | Built, not tested | Compiles; no integration test |
| `GaiaXCredentialValidator` local checks | Tested | Type, time, compliantCredentials |
| `GxdchCredentialGenerator` full flow | Tested | End-to-end via CISPE GXDCH |
| `GxdchCredentialGenerator` error paths | Partial | |
| `gx-basic-functions` SRI verification | Tested | |
| VC publishing via `VcPublisher` SPI | Tested | `S3VcPublisher` implementation, S3 + Cloudfront |
| Against public GXDCH endpoints | Tested | Tested with CISPE & deltaDAO GXDCH |
