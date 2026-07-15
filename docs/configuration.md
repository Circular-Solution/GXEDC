# Configuration Reference

All runtime settings are EDC `@Setting` annotations, passed as Kubernetes ConfigMap env vars via Terraform.

## OID4VP (Connector)

| Env var | Default | Description |
|---|---|---|
| `EDC_IAM_ISSUER_ID` | (required) | Participant DID |
| `EDC_IAM_STS_PRIVATEKEY_ALIAS` | `key-1` | Vault alias for the participant's signing key (EC, RSA, or Ed25519 JWK) |
| `EDC_IAM_STS_PUBLICKEY_ID` | `<did>#<alias>` | Verification method id used as `kid` in JWT headers; must match the participant's DID document |
| `EDC_OID4VP_IDENTITY_HUB_URL` | `http://localhost:7083` | Identity Hub base URL |
| `EDC_OID4VP_CREDENTIAL_SCOPE` | `org.eclipse.edc.vc.type:VerifiableCredential:read` | Scope requested in OID4VP auth requests |
| `EDC_OID4VP_CONNECTOR_PUBLIC_URL` | `http://localhost:8181` | Public URL of this Connector for `direct_post` callbacks |
| `EDC_OID4VP_WALLET_BACKEND` | `identityhub` | `identityhub` or `oid4vp` (external wallet) |
| `EDC_OID4VP_EXTERNAL_WALLET_URL` | `""` | External OID4VP wallet authorize URL (when backend = `oid4vp`) |
| `EDC_OID4VP_EXTERNAL_WALLET_AUTH` | `""` | Authorization header value for the external wallet |
| `WEB_HTTP_OID4VP_PORT` | `11003` | Port of the oid4vp web context (`direct_post` callback) |
| `WEB_HTTP_OID4VP_PATH` | `/api/oid4vp` | Path of the oid4vp web context |

## OID4VP wallet (Identity Hub)

| Env var | Default | Description |
|---|---|---|
| `EDC_OID4VP_SIGNING_KEY_ALIAS` | `key-1` | Vault alias for the VP-signing key |
| `EDC_OID4VP_VERIFICATION_METHOD_ID` | `key-1` | DID verification method fragment used as `kid` in VP signatures |

## OID4VCI Issuer (Identity Hub / Issuer Service)

| Env var | Default | Description |
|---|---|---|
| `EDC_OID4VCI_CREDENTIAL_CONFIG_IDS` | `""` | Comma-separated credential configuration IDs offered by this issuer |
| `EDC_OID4VCI_CREDENTIAL_CONFIG_FORMATS` | `""` | Parallel list of formats (e.g. `vc+jwt`) |
| `EDC_OID4VCI_CREDENTIAL_CONFIG_SCOPES` | `""` | Parallel list of scopes |
| `EDC_OID4VCI_ISSUER_PUBLIC_BASE_URL` | `""` | Public base URL used for `credential_issuer` in metadata and proof `aud` checks; empty = derive from request |

Values are comma-separated and aligned by index - index `N` of IDS, FORMATS, and SCOPES defines one credential configuration.

`vc+jwt` is an ecosystem-defined format identifier: it denotes a W3C VCDM 2.0 credential secured per VC-JOSE-COSE (`application/vc+jwt`). OID4VCI 1.0 defines no standard identifier for this combination (its `jwt_vc_json` profile targets VCDM 1.1).

Example - offer one `gx:LabelCredential` config:

```
EDC_OID4VCI_CREDENTIAL_CONFIG_IDS=gx:LabelCredential
EDC_OID4VCI_CREDENTIAL_CONFIG_FORMATS=vc+jwt
EDC_OID4VCI_CREDENTIAL_CONFIG_SCOPES=org.eclipse.edc.vc.type:gx:LabelCredential:read
```

## OID4VCI Holder (Identity Hub)

| Env var | Default | Description |
|---|---|---|
| `EDC_OID4VCI_SIGNING_KEY_ALIAS` | `key-1` | Vault alias for the proof-of-possession signing key |
| `EDC_OID4VCI_VERIFICATION_METHOD_ID` | `key-1` | DID verification method fragment used as `kid` in proof JWTs |
| `EDC_SQL_STORE_OID4VCI_TOKENS_DATASOURCE` | `default` | Datasource name for the SQL token store (persistence builds) |

## Gaia-X Policy (Connector)

Active only when `gx-impl` extension is loaded.

| Env var | Default | Description |
|---|---|---|
| `EDC_GAIAX_BASIC_FUNCTIONS_URL` | `""` | Optional URL for `gx-basic-functions` remote validation (SHACL + trust chain). Empty = local checks only. |

## Terraform variables

`deployment/local/terraform.tfvars`:

| Variable | Description |
|---|---|
| `consumer-did` | Consumer participant DID (default `did:web:consumer-identityhub%3A7083`) |
| `provider-did` | Provider participant DID (default `did:web:provider-identityhub%3A7083`) |
| `issuer-did` | Dataspace issuer service DID |
| `rds-host` | Postgres host |
| `rds-port` | Postgres port |
| `rds-master-user` | Postgres user |
| `rds-master-password` | Postgres password |
| `gx_basic_functions_url` | URL of an externally hosted `gx-basic-functions` service (empty = local checks only) |
| `useSVE` | Kind/Colima compatibility toggle for the local cluster |

## Policy Constraint Keys

| Short form (after `@vocab` expansion) | Full IRI |
|---|---|
| `GaiaXLabelCredential` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelCredential` |
| `GaiaXLabelLevel` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelLevel` |

Both constraints expect `operator: "eq"`. Right-operand values:

- `GaiaXLabelCredential` — `"active"`
- `GaiaXLabelLevel` — `"SC"`, `"L1"`, `"L2"`, `"L3"`
