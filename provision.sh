#!/bin/bash
set -e

# Provisions one EDC participant: database, participant context, signing key,
# gaia-x credential and the connector runtimes.
#
#   NAME=acme DID=did:web:example.com:identities:<uuid> ./provision.sh
#
# Re-running is safe: every step is idempotent.

NAME="${NAME:?NAME is required (used as the helm release and resource prefix)}"
DID="${DID:?DID is required}"

NAMESPACE="${NAMESPACE:-cs}"
CHART="${CHART:-$(dirname "$0")/deployment/charts/edc-tenant}"

# identity hub that holds this participant's context, credentials and keys
IH_URL="${IH_URL:?IH_URL is required, e.g. http://127.0.0.1:32071}"
IH_SERVICE="${IH_SERVICE:?IH_SERVICE is required, e.g. provider-identityhub}"
IH_API_KEY="${IH_API_KEY:-c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo=}"
IH_CREDENTIALS_PORT="${IH_CREDENTIALS_PORT:-7082}"
IH_STS_PORT="${IH_STS_PORT:-7084}"

VAULT_SERVICE="${VAULT_SERVICE:?VAULT_SERVICE is required, e.g. provider-vault}"
VAULT_POD="${VAULT_POD:-${VAULT_SERVICE}-0}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

KEY="${KEY:-}"
KEY_ALIAS="${KEY_ALIAS:-${NAME}-key}"
GX_JWT="${GX_JWT:-}"

DB_HOST="${DB_HOST:?DB_HOST is required}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:?DB_USER is required}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
DB_NAME="${DB_NAME:-cssp_${NAME}_edc}"

IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"
PUBLIC_DSP_URL="${PUBLIC_DSP_URL:-}"
PUBLIC_DATAPLANE_URL="${PUBLIC_DATAPLANE_URL:-}"
NODE_PORT_BASE="${NODE_PORT_BASE:-}"
INGRESS_HOST="${INGRESS_HOST:-}"
MANAGEMENT_KEY="${MANAGEMENT_KEY:-password}"
USE_SVE="${USE_SVE:-false}"
USE_HTTPS="${USE_HTTPS:-true}"
GX_BASIC_FUNCTIONS_URL="${GX_BASIC_FUNCTIONS_URL:-}"

encoded_did=$(echo -n "$DID" | base64 | tr -d '\n')
# host part of a did:web, used as the in-cluster service alias for DID resolution
DID_HOST_ALIAS="${DID_HOST_ALIAS:-$(echo "$DID" | sed -e 's|^did:web:||' -e 's|%3A.*$||' -e 's|:.*$||')}"
STS_SECRET_ALIAS="${STS_SECRET_ALIAS:-${NAME}-sts-client-secret}"

echo "==> [1/5] database $DB_NAME"
kubectl run "provision-db-${NAME}" -n "$NAMESPACE" --rm -i --restart=Never --quiet \
  --image=postgres:16.3-alpine3.20 --env="PGPASSWORD=$DB_PASSWORD" --command -- sh -c \
  "psql -h $DB_HOST -p $DB_PORT -U $DB_USER -tAc \"SELECT 1 FROM pg_database WHERE datname='$DB_NAME'\" | grep -q 1 \
   || psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c 'CREATE DATABASE $DB_NAME'"

echo "==> [2/5] participant context $DID"
existing=$(curl -s -o /dev/null -w "%{http_code}" \
  "$IH_URL/api/identity/v1alpha/participants/$encoded_did" -H "x-api-key: $IH_API_KEY")

if [ "$existing" = "200" ]; then
  echo "    already exists, skipping"
else
  if [ -n "$KEY" ]; then
    if ! echo "$KEY" | jq -e 'has("d")' >/dev/null 2>&1; then
      echo "ERROR: KEY is not a private JWK"
      exit 1
    fi
    kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- sh -c \
      "VAULT_TOKEN=$VAULT_TOKEN VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/$KEY_ALIAS content='$KEY'" >/dev/null
    key_spec=$(jq -n --arg did "$DID" --arg alias "$KEY_ALIAS" \
      --argjson jwk "$(echo "$KEY" | jq -c 'del(.d, .p, .q, .dp, .dq, .qi)')" \
      '{keyId: "\($did)#key-1", privateKeyAlias: $alias, publicKeyJwk: $jwk}')
  else
    key_spec=$(jq -n --arg did "$DID" --arg alias "$KEY_ALIAS" \
      '{keyId: "\($did)#key-1", privateKeyAlias: $alias,
        keyGeneratorParams: {algorithm: "EdDSA", curve: "Ed25519"}}')
  fi

  body=$(jq -n --arg did "$DID" --arg encoded "$encoded_did" --arg name "$NAME" \
    --arg ih "$IH_SERVICE" --arg port "$IH_CREDENTIALS_PORT" --argjson key "$key_spec" \
    '{
      roles: [],
      serviceEndpoints: [{
        type: "CredentialService",
        serviceEndpoint: "http://\($ih):\($port)/api/credentials/v1/participants/\($encoded)",
        id: "\($name)-credentialservice"
      }],
      active: true,
      participantContextId: $did,
      participantId: $did,
      did: $did,
      key: $key
    }')

  response=$(curl -s --location "$IH_URL/api/identity/v1alpha/participants/" \
    -H 'Content-Type: application/json' -H "x-api-key: $IH_API_KEY" --data "$body")
  client_secret=$(echo "$response" | jq -r 'if type == "array" then "" else (.clientSecret // empty) end')
  if [ -z "$client_secret" ]; then
    echo "ERROR: participant creation failed: $response"
    exit 1
  fi
  kubectl exec -n "$NAMESPACE" "$VAULT_POD" -- sh -c \
    "VAULT_TOKEN=$VAULT_TOKEN VAULT_ADDR=http://127.0.0.1:8200 vault kv put secret/$STS_SECRET_ALIAS content=\"$client_secret\"" >/dev/null
fi

echo "==> [3/5] gaia-x credential"
if [ -z "$GX_JWT" ]; then
  echo "    GX_JWT not set, skipping"
else
  payload_b64=$(echo -n "$GX_JWT" | tr -d '[:space:]' | cut -d. -f2)
  padding=$(((4 - ${#payload_b64} % 4) % 4))
  if [ "$padding" -ne 0 ]; then
    payload_b64="${payload_b64}$(printf '%*s' "$padding" | tr ' ' '=')"
  fi
  payload=$(echo "$payload_b64" | tr '_-' '/+' | base64 -d 2>/dev/null)
  types=$(echo "$payload" | jq -c '.type // ["VerifiableCredential"]')
  if ! echo "$types" | jq -e 'index("gx:LabelCredential")' >/dev/null; then
    echo "ERROR: GX_JWT is not a gx:LabelCredential (got $types)"
    exit 1
  fi
  cred=$(jq -n --arg cred_id "${NAME}-gx-label-credential" --arg did "$DID" --arg jwt "$(echo -n "$GX_JWT" | tr -d '[:space:]')" \
    --argjson types "$types" \
    --arg issuer "$(echo "$payload" | jq -r 'if (.issuer|type)=="string" then .issuer else (.issuer.id // .iss) end')" \
    --arg subject "$(echo "$payload" | jq -r 'if (.credentialSubject|type)=="array" then .credentialSubject[0].id else .credentialSubject.id end // ""')" \
    --arg from "$(echo "$payload" | jq -r '.validFrom // .issuanceDate')" \
    --arg until "$(echo "$payload" | jq -r '.validUntil // .expirationDate')" \
    '{
      id: $cred_id,
      participantContextId: $did,
      verifiableCredentialContainer: {
        rawVc: $jwt, format: "VC2_0_JOSE",
        credential: {
          type: $types, issuer: {id: $issuer},
          credentialSubject: [{id: $subject}],
          issuanceDate: $from, expirationDate: $until
        }
      }
    }')
  code=$(curl -s -o /tmp/provision-cred -w "%{http_code}" \
    -X POST "$IH_URL/api/identity/v1alpha/participants/$encoded_did/credentials" \
    -H "Content-Type: application/json" -H "x-api-key: $IH_API_KEY" -d "$cred")
  if [ "$code" = "409" ]; then
    echo "    already loaded, skipping"
  elif [ "$code" != "204" ] && [ "$code" != "200" ]; then
    echo "ERROR: credential load returned $code: $(cat /tmp/provision-cred)"
    exit 1
  fi
fi

echo "==> [4/5] helm release edc-$NAME"
helm_args=(
  --namespace "$NAMESPACE"
  --set participantId="$DID"
  --set aliases.privateKey="$KEY_ALIAS"
  --set aliases.stsClientSecret="$STS_SECRET_ALIAS"
  --set identityHub.service="$IH_SERVICE"
  --set didHostAlias="$DID_HOST_ALIAS"
  --set identityHub.url="http://${IH_SERVICE}:${IH_CREDENTIALS_PORT}/api/credentials"
  --set identityHub.stsTokenUrl="http://${IH_SERVICE}:${IH_STS_PORT}/api/sts/token"
  --set vault.url="http://${VAULT_SERVICE}:8200"
  --set vault.token="$VAULT_TOKEN"
  --set database.url="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
  --set database.user="$DB_USER"
  --set database.password="$DB_PASSWORD"
  --set image.tag="$IMAGE_TAG"
  --set management.authKey="$MANAGEMENT_KEY"
  --set useSVE="$USE_SVE"
  --set useHttps="$USE_HTTPS"
  --set gaiaxBasicFunctionsUrl="$GX_BASIC_FUNCTIONS_URL"
)
[ -n "$IMAGE_REGISTRY" ] && helm_args+=(--set image.registry="$IMAGE_REGISTRY")
[ -n "$PUBLIC_DSP_URL" ] && helm_args+=(--set public.dspCallbackAddress="$PUBLIC_DSP_URL")
[ -n "$PUBLIC_DATAPLANE_URL" ] && helm_args+=(--set public.dataplaneUrl="$PUBLIC_DATAPLANE_URL")
[ -n "$NODE_PORT_BASE" ] && helm_args+=(--set service.type=NodePort --set service.nodePortBase="$NODE_PORT_BASE")
[ -n "$INGRESS_HOST" ] && helm_args+=(--set ingress.enabled=true --set ingress.host="$INGRESS_HOST")

helm upgrade --install "edc-$NAME" "$CHART" "${helm_args[@]}"

echo "==> [5/5] waiting for rollout"
kubectl rollout status deployment "edc-${NAME}-controlplane" -n "$NAMESPACE" --timeout=180s
kubectl rollout status deployment "edc-${NAME}-dataplane" -n "$NAMESPACE" --timeout=180s

echo
echo "provisioned $NAME"
echo "  did:        $DID"
echo "  management: http://edc-${NAME}-controlplane:8081/api/management"
echo "  dsp:        http://edc-${NAME}-controlplane:8082/api/dsp/2025-1"
