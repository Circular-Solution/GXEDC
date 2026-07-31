#!/bin/bash
export NAME=provider
export DID=did:web:provider-identityhub%3A7083
export IH_URL=http://consumer.local
export IH_SERVICE=identityhub
export VAULT_SERVICE=vault
export DB_HOST=host.docker.internal
export DB_USER=cs
export DB_PASSWORD=cs
export DB_NAME=cssp_provider_edc
export INGRESS_HOST=provider.local
export USE_SVE=true
export USE_HTTPS=false
export GX_JWT="jwt"
./provision.sh
