# Configuration Reference

All runtime settings are EDC `@Setting` annotations, passed as Kubernetes ConfigMap env vars via Terraform.

## OID4VP (Connector)

| Env var | Default | Description |
|---|---|---|
| `EDC_IAM_ISSUER_ID` | (required) | Participant DID |
| `EDC_IAM_STS_PRIVATEKEY_ALIAS` | `key-1` | Vault alias for participant's EC signing key |
| `EDC_IAM_STS_PUBLICKEY_ID` | `<did>#<alias>` | Public key ID used as `kid` in OID4VP JWT headers |
| `EDC_OID4VP_IDENTITY_HUB_URL` | `http://localhost:7083` | Identity Hub base URL |
| `EDC_OID4VP_CREDENTIAL_SCOPE` | `org.eclipse.edc.vc.type:VerifiableCredential:read` | Scope requested in OID4VP auth requests |

## OID4VCI Issuer (Identity Hub)

| Env var | Default | Description |
|---|---|---|
| `EDC_OID4VCI_CREDENTIAL_CONFIG_IDS` | `""` | Comma-separated credential configuration IDs offered by this issuer |
| `EDC_OID4VCI_CREDENTIAL_CONFIG_FORMATS` | `""` | Parallel list of formats (e.g. `jwt_vc_json`) |
| `EDC_OID4VCI_CREDENTIAL_CONFIG_SCOPES` | `""` | Parallel list of scopes |

Values are comma-seperated and aligned by index - index `N` of IDS, FORMATS, and SCOPES define one credential configuration.

Example - offer one `gx:LabelCredential` config:

```
EDC_OID4VCI_CREDENTIAL_CONFIG_IDS=gx:LabelCredential
EDC_OID4VCI_CREDENTIAL_CONFIG_FORMATS=jwt_vc_json
EDC_OID4VCI_CREDENTIAL_CONFIG_SCOPES=org.eclipse.edc.vc.type:gx:LabelCredential:read
```

## GXDCH Adapter (Identity Hub)

Active only when `gx-issuer` extension is loaded.

| Env var | Default | Description |
|---|---|---|
| `EDC_GAIAX_GXDCH_PUBLIC_DID` | `""` | Override participant DID for GXDCH signing. Leave blank in production. |
| `EDC_GAIAX_GXDCH_BASE_ID` | `https://example.com` | Base URL for self-signed credential IDs |
| `EDC_GAIAX_GXDCH_LEGAL_NAME` | `Example Company` | Company name |
| `EDC_GAIAX_GXDCH_COUNTRY_CODE` | `KR` | ISO 3166 country code |
| `EDC_GAIAX_GXDCH_LEI` | `""` | 20-character LEI code (one of LEI/VAT/EORI/EUID required) |
| `EDC_GAIAX_GXDCH_VAT` | `""` | VAT ID |
| `EDC_GAIAX_GXDCH_EORI` | `""` | EORI number |
| `EDC_GAIAX_GXDCH_EUID` | `""` | EUID |
| `EDC_GAIAX_GXDCH_NOTARY_URL` | `https://registrationnumber.notary.lab.gaia-x.eu/v2` | Notary base URL |
| `EDC_GAIAX_GXDCH_COMPLIANCE_URL` | `https://compliance.lab.gaia-x.eu/v2` | Compliance base URL |
| `EDC_GAIAX_GXDCH_COMPLIANCE_LEVEL` | `standard-compliance` | One of `standard-compliance`, `label-level-1`, `-2`, `-3` |
| `EDC_GAIAX_GXDCH_SIGNING_KEY_ALIAS` | `gxdch-signing-key` | Vault alias for RSA signing key |
| `EDC_GAIAX_GXDCH_VERIFICATION_METHOD_ID` | `X509-JWK` | DID fragment for verification method |
| `EDC_GAIAX_GXDCH_TERMS_HASH` | Gaia-X standard hash | SHA-256 hash of Gaia-X terms text |

## Gaia-X Policy (Connector)

Active only when `gx-impl` extension is loaded.

| Env var | Default | Description |
|---|---|---|
| `EDC_GAIAX_BASIC_FUNCTIONS_URL` | `""` | Optional URL for `gx-basic-functions` remote validation. Empty = local checks only. |

## Terraform variables

`deployment/local/terraform.tfvars`:

| Variable | Description |
|---|---|
| `rds-host` | Postgres host |
| `rds-port` | Postgres port |
| `rds-master-user` | Postgres user |
| `rds-master-password` | Postgres password |
| `gxdch_lei` | LEI code for Gaia-X notary |
| `gxdch_legal_name` | Legal entity name |
| `gxdch_country_code` | Country code |

Per-participant overrides in `consumer.tf` / `provider.tf`:

| Variable | Description |
|---|---|
| `gxdch_public_did` | Public DID override (e.g. `did:web:yourdomain.com`) |
| `gxdch_base_id` | Base URL for self-signed credentials |
| `gxdch_notary_url` | Notary URL (public Gaia-X or local Docker) |
| `gxdch_compliance_url` | Compliance URL |

## Policy Constraint Keys

| Short form (after `@vocab` expansion) | Full IRI |
|---|---|
| `GaiaXLabelCredential` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelCredential` |
| `GaiaXLabelLevel` | `https://w3id.org/edc/v0.0.1/ns/GaiaXLabelLevel` |

Both constraints expect `operator: "eq"`. Right-operand values:

- `GaiaXLabelCredential` — `"active"`
- `GaiaXLabelLevel` — `"SC"`, `"L1"`, `"L2"`, `"L3"`

