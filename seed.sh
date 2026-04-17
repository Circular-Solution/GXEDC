#!/bin/bash
set -e

API_KEY="c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
NAMESPACE="cs"
CONSUMER_DID="did:web:consumer-identityhub%3A7083"
PROVIDER_DID="did:web:provider-identityhub%3A7083"
ISSUER_DID="did:web:dataspace-issuer-service%3A10016"

SCRIPT_DIR="$(dirname "$0")"
PRIVATE_JWK_PATH="${PRIVATE_JWK_PATH:-$SCRIPT_DIR/private-jwk.json}"

ISSUER_ENCODED_DID=$(echo -n "$ISSUER_DID" | base64 | tr -d '\n')
ISSUER_OID4VCI_BASE="http://provider-identityhub:7082/api/credentials/v1/participants/$ISSUER_ENCODED_DID/oid4vci"

if [ -f "$PRIVATE_JWK_PATH" ]; then
  echo "Seeding GXDCH signing key into consumer/provider vaults..."
  PRIVATE_JWK_CONTENT=$(cat "$PRIVATE_JWK_PATH")
  for participant in consumer provider; do
    kubectl exec -n $NAMESPACE ${participant}-vault-0 -- sh -c \
      "VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/gxdch-signing-key content='$PRIVATE_JWK_CONTENT'"
  done
else
  echo "WARNING: $PRIVATE_JWK_PATH not found, skipping vault seed"
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

  local response
  response=$(curl -s --location "http://$ih_host/api/identity/v1alpha/participants/" \
    --header 'Content-Type: application/json' \
    --header "x-api-key: $API_KEY" \
    --data @- <<EOF
{
  "roles": [],
  "serviceEndpoints": [
    {
      "type": "CredentialService",
      "serviceEndpoint": "http://$ih_internal:7082/api/credentials/v1/participants/$encoded_did",
      "id": "$name-credentialservice"
    }
  ],
  "active": true,
  "participantContextId": "$did",
  "participantId": "$did",
  "did": "$did",
  "key": {
    "keyId": "$did#key-1",
    "privateKeyAlias": "key-1",
    "keyGeneratorParams": {
      "algorithm": "EC",
      "curve": "secp256r1"
    }
  }
}
EOF
  )

  local client_secret
  client_secret=$(echo "$response" | jq -r '.clientSecret // empty')
  if [ -z "$client_secret" ]; then
    echo "WARNING: no client secret for $name"
    return
  fi

  kubectl exec -n $NAMESPACE ${name}-vault-0 -- sh -c \
    "VAULT_TOKEN=root VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/sts-client-secret content=\"$client_secret\""
}

issue_credential() {
  local holder_host=$1
  local holder_did=$2
  local holder_name=$3

  local holder_encoded_did
  holder_encoded_did=$(echo -n "$holder_did" | base64 | tr -d '\n')

  echo "Issuing credential to $holder_name..."
  local offer
  offer=$(curl -s -X POST "http://provider.local/api/credentials/v1/participants/$ISSUER_ENCODED_DID/oid4vci/offers" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
  "credential_configuration_id": "gx:LabelCredential",
  "issuer_base_url": "$ISSUER_OID4VCI_BASE"
}
EOF
  )

  curl -s -X POST "http://$holder_host/api/credentials/v1/participants/$holder_encoded_did/oid4vci/offer" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer seed-token" \
    -d "$offer" > /dev/null
}

create_participant "consumer" "consumer.local" "$CONSUMER_DID" "consumer-identityhub"
create_participant "provider" "provider.local" "$PROVIDER_DID" "provider-identityhub"

echo "Creating issuer participant..."
curl -s -o /dev/null -X DELETE \
  "http://provider.local/api/identity/v1alpha/participants/$ISSUER_ENCODED_DID" \
  -H "x-api-key: $API_KEY" || true

curl -s --location "http://provider.local/api/identity/v1alpha/participants/" \
  --header 'Content-Type: application/json' \
  --header "x-api-key: $API_KEY" \
  --data @- <<EOF > /dev/null
{
  "roles": ["admin"],
  "serviceEndpoints": [
    {
      "type": "IssuerService",
      "serviceEndpoint": "http://dataspace-issuer-service:10012/api/issuance/v1alpha/participants/$ISSUER_ENCODED_DID",
      "id": "issuer-service"
    }
  ],
  "active": true,
  "participantContextId": "$ISSUER_DID",
  "participantId": "$ISSUER_DID",
  "did": "$ISSUER_DID",
  "key": {
    "keyId": "$ISSUER_DID#issuer-key-1",
    "privateKeyAlias": "issuer-key-1",
    "keyGeneratorParams": {
      "algorithm": "EdDSA"
    }
  }
}
EOF

issue_credential "consumer.local" "$CONSUMER_DID" "consumer"
issue_credential "provider.local" "$PROVIDER_DID" "provider"

echo "Restarting deployments..."
for dep in consumer-controlplane consumer-dataplane provider-controlplane provider-dataplane provider-catalog-server; do
  kubectl rollout restart deployment "$dep" -n $NAMESPACE
done

kubectl rollout status deployment consumer-controlplane -n $NAMESPACE --timeout=120s
kubectl rollout status deployment provider-controlplane -n $NAMESPACE --timeout=120s

echo "Done."
