#!/bin/bash
set -e

API_KEY="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
NAMESPACE="cs"

CONSUMER_IH_URL="${CONSUMER_IH_URL:-http://consumer.local}"
PROVIDER_IH_URL="${PROVIDER_IH_URL:-http://provider.local}"

CONSUMER_DID="${CONSUMER_DID:-did:web:consumer-identityhub%3A7083}"
PROVIDER_DID="${PROVIDER_DID:-did:web:provider-identityhub%3A7083}"

# private JWK (JSON) whose public half is published as <did>#key-1 in the hosted DID document.
# Empty = let the Identity Hub generate a keypair and publish it in its own DID document.
CONSUMER_KEY="${CONSUMER_KEY:-}"
# vault alias for the participant key. Must be unique per participant when the vault is shared.
CONSUMER_KEY_ALIAS="${CONSUMER_KEY_ALIAS:-key-1}"
PROVIDER_KEY="${PROVIDER_KEY:-}"
PROVIDER_KEY_ALIAS="${PROVIDER_KEY_ALIAS:-key-1}"

GX_JWT="${GX_JWT:-}"

create_participant() {
  local name=$1
  local ih_url=$2
  local did=$3
  local private_key=$5
  local key_alias=$6
  local ih_internal=$4

  local encoded_did
  encoded_did=$(echo -n "$did" | base64 | tr -d '\n')

  echo "Creating $name participant..."
  curl -s -o /dev/null -X DELETE \
    "$ih_url/api/identity/v1alpha/participants/$encoded_did" \
    -H "x-api-key: $API_KEY" || true

  local key_spec
  if [ -n "$private_key" ]; then
    echo "Importing provided signing key for $name..."
    kubectl exec -n $NAMESPACE ${name}-vault-0 -- sh -c \
      "VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/$key_alias content='$private_key'" >/dev/null
    key_spec=$(jq -n --arg did "$did" \
      --argjson public_jwk "$(echo "$private_key" | jq -c 'del(.d, .p, .q, .dp, .dq, .qi)')" \
      --arg alias "$key_alias" \
      '{keyId: "\($did)#key-1", privateKeyAlias: $alias, publicKeyJwk: $public_jwk}')
  else
    key_spec=$(jq -n --arg did "$did" \
      --arg alias "$key_alias" \
      '{keyId: "\($did)#key-1", privateKeyAlias: $alias,
        keyGeneratorParams: {algorithm: "EdDSA", curve: "Ed25519"}}')
  fi

  local body
  body=$(jq -n \
    --arg did "$did" \
    --arg encoded_did "$encoded_did" \
    --arg name "$name" \
    --arg ih_internal "$ih_internal" \
    --argjson key "$key_spec" \
    '{
      roles: [],
      serviceEndpoints: [{
        type: "CredentialService",
        serviceEndpoint: "http://\($ih_internal):7082/api/credentials/v1/participants/\($encoded_did)",
        id: "\($name)-credentialservice"
      }],
      active: true,
      participantContextId: $did,
      participantId: $did,
      did: $did,
      key: $key
    }')

  local response
  response=$(curl -s --location "$ih_url/api/identity/v1alpha/participants/" \
    --header 'Content-Type: application/json' \
    --header "x-api-key: $API_KEY" \
    --data "$body")

  local client_secret
  client_secret=$(echo "$response" | jq -r 'if type == "array" then "" else (.clientSecret // empty) end')
  if [ -z "$client_secret" ]; then
    echo "WARNING: no client secret for $name. Response: $response"
    return
  fi

  kubectl exec -n $NAMESPACE ${name}-vault-0 -- sh -c \
    "VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/sts-client-secret content=\"$client_secret\""
}

load_credential() {
  local name=$1
  local ih_url=$2
  local did=$3

  if [ -z "$GX_JWT" ]; then
    echo "WARNING: GX_JWT not set, skipping credential seed for $name"
    return
  fi

  local encoded_did
  encoded_did=$(echo -n "$did" | base64 | tr -d '\n')

  local vc_jwt
  vc_jwt=$(echo -n "$GX_JWT" | tr -d '[:space:]')

  if [ "$(echo "$vc_jwt" | awk -F. '{print NF}')" -ne 3 ]; then
    echo "ERROR: GX_JWT is not a JWT (expected 3 dot-separated parts)"
    exit 1
  fi

  local payload_b64
  payload_b64=$(echo "$vc_jwt" | cut -d. -f2)
  local padding=$(((4 - ${#payload_b64} % 4) % 4))
  if [ "$padding" -ne 0 ]; then
    payload_b64="${payload_b64}$(printf '%*s' "$padding" | tr ' ' '=')"
  fi
  local payload
  payload=$(echo "$payload_b64" | tr '_-' '/+' | base64 -d 2>/dev/null)
  if [ -z "$payload" ]; then
    echo "WARNING: could not decode credential JWT payload for $name"
    return
  fi

  local issuer_id subject_id types valid_from valid_until
  issuer_id=$(echo "$payload" | jq -r 'if (.issuer | type) == "string" then .issuer else (.issuer.id // .iss) end')
  subject_id=$(echo "$payload" | jq -r 'if (.credentialSubject | type) == "array" then .credentialSubject[0].id else .credentialSubject.id end // ""')
  types=$(echo "$payload" | jq -c '.type // ["VerifiableCredential"]')
  valid_from=$(echo "$payload" | jq -r '.validFrom // .issuanceDate // (if .iat then (.iat | todate) else "" end)')
  valid_until=$(echo "$payload" | jq -r '.validUntil // .expirationDate // (if .exp then (.exp | todate) else "" end)')

  if [ -z "$valid_from" ] || [ "$valid_from" = "null" ]; then
    valid_from=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  fi
  if [ -z "$valid_until" ] || [ "$valid_until" = "null" ]; then
    valid_until=$(date -u -v+90d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+90 days" +"%Y-%m-%dT%H:%M:%SZ")
  fi

  echo "Loading credential into $name wallet (issuer=$issuer_id, subject=$subject_id, validFrom=$valid_from, validUntil=$valid_until)..."

  local body
  body=$(jq -n \
    --arg did "$did" \
    --arg jwt "$vc_jwt" \
    --arg issuer "$issuer_id" \
    --arg subject "$subject_id" \
    --argjson types "$types" \
    --arg valid_from "$valid_from" \
    --arg valid_until "$valid_until" \
    '{
      id: "seed-label-credential",
      participantContextId: $did,
      verifiableCredentialContainer: {
        rawVc: $jwt,
        format: "VC2_0_JOSE",
        credential: {
          type: $types,
          issuer: { id: $issuer },
          credentialSubject: [{ id: $subject }],
          issuanceDate: $valid_from,
          expirationDate: $valid_until
        }
      }
    }')

  local response_code
  response_code=$(curl -s -o /tmp/cred-load-resp -w "%{http_code}" \
    -X POST "$ih_url/api/identity/v1alpha/participants/$encoded_did/credentials" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $API_KEY" \
    -d "$body")
  if [ "$response_code" != "204" ] && [ "$response_code" != "200" ]; then
    echo "WARNING: credential load for $name returned $response_code: $(cat /tmp/cred-load-resp)"
  fi
}

create_participant "consumer" "$CONSUMER_IH_URL" "$CONSUMER_DID" "consumer-identityhub" "$CONSUMER_KEY" "$CONSUMER_KEY_ALIAS"
create_participant "provider" "$PROVIDER_IH_URL" "$PROVIDER_DID" "provider-identityhub" "$PROVIDER_KEY" "$PROVIDER_KEY_ALIAS"

load_credential "consumer" "$CONSUMER_IH_URL" "$CONSUMER_DID"
load_credential "provider" "$PROVIDER_IH_URL" "$PROVIDER_DID"

echo "Restarting deployments..."
for dep in consumer-controlplane consumer-dataplane provider-controlplane provider-dataplane provider-catalog-server; do
  kubectl rollout restart deployment "$dep" -n $NAMESPACE 2>/dev/null || true
done

kubectl rollout status deployment consumer-controlplane -n $NAMESPACE --timeout=120s
kubectl rollout status deployment provider-controlplane -n $NAMESPACE --timeout=120s

echo "Done."
