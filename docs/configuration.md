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

The Identity Hub resolves the VP signing key from the requesting participant's own key pair resource, so one hub can serve many participants. There is nothing to configure - the vault alias and verification method id come from the key registered when the participant context was created.

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

Proof-of-possession JWTs are signed with the requesting participant's own key pair, resolved per context like VP signing.

| Env var | Default | Description |
|---|---|---|
| `EDC_SQL_STORE_OID4VCI_TOKENS_DATASOURCE` | `default` | Datasource name for the SQL token store (persistence builds) |

## Gaia-X Policy (Connector)

Active only when `gx-impl` extension is loaded.

| Env var | Default | Description |
|---|---|---|
| `EDC_GAIAX_BASIC_FUNCTIONS_URL` | `""` | Optional URL for `gx-basic-functions` remote validation (SHACL + trust chain). Empty = local checks only. |

## Terraform variables (shared base)

`deployment/terraform.tfvars`:

| Variable | Description |
|---|---|
| `kubeconfig-path` | Path to the kubeconfig. k3s writes `/etc/rancher/k3s/k3s.yaml` |
| `rds-host` / `rds-port` / `rds-master-user` / `rds-master-password` | Postgres connection |
| `gx_basic_functions_url` | URL of an externally hosted `gx-basic-functions` service, empty disables remote validation |
| `use-https` | Resolve `did:web` over HTTPS. Required for publicly hosted DID documents |
| `useSVE` | Adds `-XX:UseSVE=0`, needed on Apple Silicon |
| `enable-issuer` | Deploy the issuer service. Not needed when credentials come from a GXDCH |
| `enable-catalog-server` | Deploy the federated catalog server |
| `identityhub-hosts` | Hostnames the shared Identity Hub answers on for the identity and credentials APIs |

Participant DIDs are not terraform variables - each participant is provisioned separately.

## provision.sh

One participant per invocation. Required:

| Variable | Description |
|---|---|
| `NAME` | Tenant name, used as the helm release and resource prefix |
| `DID` | Participant DID |
| `IH_URL` | Identity API base URL of the shared Identity Hub |
| `IH_SERVICE` | In-cluster service name of the Identity Hub |
| `VAULT_SERVICE` | In-cluster service name of the vault |
| `DB_HOST` / `DB_USER` / `DB_PASSWORD` | Postgres connection |

Optional:

| Variable | Default | Description |
|---|---|---|
| `KEY` | generate | Private JWK to import. Empty lets the Identity Hub generate an Ed25519 key pair |
| `KEY_ALIAS` | `<name>-key` | Vault alias for the participant key. Must be unique per participant in a shared vault |
| `GX_JWT` | | `gx:LabelCredential` to load. Skipped when empty |
| `DB_NAME` | `cssp_<name>_edc` | Tenant database |
| `USE_HTTPS` | `true` | Resolve `did:web` over HTTPS. Set `false` for in-cluster DIDs |
| `USE_SVE` | `false` | Apple Silicon workaround |
| `NODE_PORT_BASE` | | Pins node ports: management `+81`, dsp `+82`, dataplane public `+92` |
| `INGRESS_HOST` | | Publishes an ingress for `/api/dsp`, `/api/management`, `/api/public` |
| `PUBLIC_DSP_URL` / `PUBLIC_DATAPLANE_URL` | | Public base URLs advertised to counterparties. Required when anything outside the cluster talks to this participant |
| `IMAGE_REGISTRY` / `IMAGE_TAG` | `latest` | Container images |
| `MANAGEMENT_KEY` | `password` | Management API key |
| `DID_HOST_ALIAS` | derived from `DID` | Service alias so the participant `did:web` host resolves to the shared hub |
| `STS_SECRET_ALIAS` | `<name>-sts-client-secret` | Vault alias for the STS client secret |

## Policy Constraint Keys

| Short form (after `@vocab` expansion) | Full IRI |
|---|---|
| `GaiaXLabelCredential` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelCredential` |
| `GaiaXLabelLevel` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelLevel` |
| `ConnectorDid` | `https://w3id.org/edc/v0.0.1/ns/ConnectorDid` |

Operators and right-operand values:

- `GaiaXLabelCredential` — `eq` `"active"`
- `GaiaXLabelLevel` — `eq` `"SC"`, `"L1"`, `"L2"`, `"L3"`
- `ConnectorDid` — `eq`/`in`/`isAnyOf` (or negated `neq`/`isNoneOf`) with one DID or a list, e.g. `["did:web:partner-a", "did:web:partner-b"]`
