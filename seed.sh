#!/bin/bash
set -e

API_KEY="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
NAMESPACE="cs"

CONSUMER_DID="did:web:consumer-identityhub%3A7083"
PROVIDER_DID="did:web:provider-identityhub%3A7083"

SCRIPT_DIR="$(dirname "$0")"
PRIVATE_JWK_PATH="${PRIVATE_JWK_PATH:-$SCRIPT_DIR/private-jwk.json}"
SEED_CREDENTIAL_PATH="${SEED_CREDENTIAL_PATH:-$SCRIPT_DIR/seed-credential.jwt}"

if [ -f "$PRIVATE_JWK_PATH" ]; then
  echo "Seeding GXDCH signing key into consumer/provider vaults..."
  PRIVATE_JWK_CONTENT=$(cat "$PRIVATE_JWK_PATH")
  PUBLIC_JWK_CONTENT=$(jq -c 'del(.d, .p, .q, .dp, .dq, .qi)' "$PRIVATE_JWK_PATH")
  for participant in consumer provider; do
    kubectl exec -n $NAMESPACE ${participant}-vault-0 -- sh -c \
      "VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/gxdch-signing-key content='$PRIVATE_JWK_CONTENT'"
  done
else
  echo "ERROR: $PRIVATE_JWK_PATH not found, cannot seed RSA key"
  exit 1
fi

create_participant() {
  local name=$1
  local ih_host=$2
  local did=$3
  local ih_internal=$4

  local encoded_did
  encoded_did=$(echo -n "$did" | base64 | tr -d '\n')

  echo "Creating $name participant..."
  curl -s -o /dev/null -X DELETE \
    "http://$ih_host/api/identity/v1alpha/participants/$encoded_did" \
    -H "x-api-key: $API_KEY" || true

  local body
  body=$(jq -n \
    --arg did "$did" \
    --arg encoded_did "$encoded_did" \
    --arg name "$name" \
    --arg ih_internal "$ih_internal" \
    --argjson public_jwk "$PUBLIC_JWK_CONTENT" \
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
      key: {
        keyId: "\($did)#JWK2020-RSA",
        privateKeyAlias: "gxdch-signing-key",
        publicKeyJwk: $public_jwk
      }
    }')

  local response
  response=$(curl -s --location "http://$ih_host/api/identity/v1alpha/participants/" \
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
  local ih_host=$2
  local did=$3

  if [ ! -f "$SEED_CREDENTIAL_PATH" ]; then
    echo "WARNING: $SEED_CREDENTIAL_PATH not found, skipping credential seed for $name"
    return
  fi

  local encoded_did
  encoded_did=$(echo -n "$did" | base64 | tr -d '\n')

  local vc_jwt
  vc_jwt=$(tr -d '[:space:]' < "$SEED_CREDENTIAL_PATH")

  local payload_b64
  payload_b64=$(echo "$vc_jwt" | cut -d. -f2)
  local padding=$((4 - ${#payload_b64} % 4))
  [ $padding -ne 4 ] && payload_b64="${payload_b64}$(printf '%*s' $padding | tr ' ' '=')"
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
    -X POST "http://$ih_host/api/identity/v1alpha/participants/$encoded_did/credentials" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $API_KEY" \
    -d "$body")
  if [ "$response_code" != "204" ] && [ "$response_code" != "200" ]; then
    echo "WARNING: credential load for $name returned $response_code: $(cat /tmp/cred-load-resp)"
  fi
}

create_participant "consumer" "consumer.local" "$CONSUMER_DID" "consumer-identityhub"
create_participant "provider" "provider.local" "$PROVIDER_DID" "provider-identityhub"

load_credential "consumer" "consumer.local" "$CONSUMER_DID"
load_credential "provider" "provider.local" "$PROVIDER_DID"

echo "Restarting deployments..."
for dep in consumer-controlplane consumer-dataplane provider-controlplane provider-dataplane provider-catalog-server; do
  kubectl rollout restart deployment "$dep" -n $NAMESPACE
done

kubectl rollout status deployment consumer-controlplane -n $NAMESPACE --timeout=120s
kubectl rollout status deployment provider-controlplane -n $NAMESPACE --timeout=120s

echo "Done."
