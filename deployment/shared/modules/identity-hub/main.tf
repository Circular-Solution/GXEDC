#
#  Copyright (c) 2024 Metaform Systems, Inc.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  SPDX-License-Identifier: Apache-2.0
#
#  Contributors:
#       Metaform Systems, Inc. - initial API and implementation
#       Circular Solution Co., Ltd - production config
#

resource "kubernetes_deployment" "identityhub" {
  metadata {
    name      = lower(var.humanReadableName)
    namespace = var.namespace
    labels = {
      App = lower(var.humanReadableName)
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        App = lower(var.humanReadableName)
      }
    }

    template {
      metadata {
        labels = {
          App = lower(var.humanReadableName)
        }
      }

      spec {
        container {
          image_pull_policy = "Never"
          image             = "identity-hub:latest"
          name              = "identity-hub"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.identityhub-config.metadata[0].name
            }
          }
          port {
            container_port = var.ports.credentials-api
            name           = "creds-port"
          }

          port {
            container_port = var.ports.ih-debug
            name           = "debug"
          }
          port {
            container_port = var.ports.ih-identity-api
            name           = "identity"
          }
          port {
            container_port = var.ports.ih-did
            name           = "did"
          }
          port {
            container_port = var.ports.web
            name           = "default-port"
          }

          liveness_probe {
            http_get {
              path = "/api/check/liveness"
              port = var.ports.web
            }
            failure_threshold = 10
            period_seconds    = 5
            timeout_seconds   = 30
          }

          readiness_probe {
            http_get {
              path = "/api/check/readiness"
              port = var.ports.web
            }
            failure_threshold = 10
            period_seconds    = 5
            timeout_seconds   = 30
          }

          startup_probe {
            http_get {
              path = "/api/check/startup"
              port = var.ports.web
            }
            failure_threshold = 10
            period_seconds    = 5
            timeout_seconds   = 30
          }
        }
      }
    }
  }
}


resource "kubernetes_config_map" "identityhub-config" {
  metadata {
    name      = "${lower(var.humanReadableName)}-ih-config"
    namespace = var.namespace
  }

  data = {
    # IdentityHub variables
    EDC_IH_IAM_ID                      = var.participantId
    EDC_IAM_DID_WEB_USE_HTTPS          = var.use-https
    EDC_IH_IAM_PUBLICKEY_ALIAS         = local.public-key-alias
    EDC_IH_API_SUPERUSER_KEY           = var.ih_superuser_apikey
    WEB_HTTP_PORT                      = var.ports.web
    WEB_HTTP_PATH                      = "/api"
    WEB_HTTP_IDENTITY_PORT             = var.ports.ih-identity-api
    WEB_HTTP_IDENTITY_PATH             = "/api/identity"
    WEB_HTTP_IDENTITY_AUTH_KEY         = "password"
    WEB_HTTP_CREDENTIALS_PORT          = var.ports.credentials-api
    WEB_HTTP_CREDENTIALS_PATH          = "/api/credentials"
    WEB_HTTP_DID_PORT                  = var.ports.ih-did
    WEB_HTTP_DID_PATH                  = "/"
    WEB_HTTP_STS_PORT                  = var.ports.sts-api
    WEB_HTTP_STS_PATH                  = var.sts-token-path
    JAVA_TOOL_OPTIONS                  = "${var.useSVE ? "-XX:UseSVE=0 " : ""}-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${var.ports.debug} -Dsun.net.http.allowRestrictedHeaders=true"
    EDC_IAM_STS_PRIVATEKEY_ALIAS       = var.aliases.sts-private-key
    EDC_IAM_STS_PUBLICKEY_ID           = "${var.participantId}#${var.aliases.sts-public-key-id}"
    EDC_VAULT_HASHICORP_URL            = var.vault-url
    EDC_VAULT_HASHICORP_TOKEN          = var.vault-token
    EDC_DATASOURCE_DEFAULT_URL         = var.database.url
    EDC_DATASOURCE_DEFAULT_USER        = var.database.user
    EDC_DATASOURCE_DEFAULT_PASSWORD    = var.database.password
    EDC_SQL_SCHEMA_AUTOCREATE          = true
    EDC_IAM_ACCESSTOKEN_JTI_VALIDATION = true
    EDC_ENCRYPTION_AES_KEY_ALIAS       = "aes-encryption-key"

    EDC_VAULT_HASHICORP_TOKEN_SCHEDULED_RENEW_ENABLED = "false"
    EDC_VAULT_HASHICORP_ALLOW_FALLBACK                = "true"

    EDC_GAIAX_GXDCH_PUBLIC_DID             = var.gxdch_public_did
    EDC_GAIAX_GXDCH_BASE_ID                = var.gxdch_base_id
    EDC_GAIAX_GXDCH_LEGAL_NAME             = var.gxdch_legal_name
    EDC_GAIAX_GXDCH_COUNTRY_CODE           = var.gxdch_country_code
    EDC_GAIAX_GXDCH_LEI                    = var.gxdch_lei
    EDC_GAIAX_GXDCH_SIGNING_KEY_ALIAS      = var.gxdch_signing_key_alias
    EDC_GAIAX_GXDCH_VERIFICATION_METHOD_ID = var.gxdch_verification_method_id
    EDC_GAIAX_GXDCH_NOTARY_URL             = var.gxdch_notary_url
    EDC_GAIAX_GXDCH_COMPLIANCE_URL         = var.gxdch_compliance_url
    EDC_GAIAX_GXDCH_COMPLIANCE_LEVEL       = var.gxdch_compliance_level

    EDC_OID4VCI_CREDENTIAL_CONFIG_IDS     = "gx:LabelCredential"
    EDC_OID4VCI_CREDENTIAL_CONFIG_FORMATS = "jwt_vc_json"
    EDC_OID4VCI_CREDENTIAL_CONFIG_SCOPES  = "gx:LabelCredential"

    AWS_ACCESS_KEY_ID         = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY     = var.aws_secret_access_key
    EDC_GAIAX_GXDCH_S3_BUCKET = var.gxdch_s3_bucket
    EDC_GAIAX_GXDCH_S3_REGION = var.gxdch_s3_region
  }
}

locals {
  public-key-alias = "${var.humanReadableName}-publickey"
}
