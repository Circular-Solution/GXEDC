#
#  Copyright (c) 2023 Contributors to the Eclipse Foundation
#
#  See the NOTICE file(s) distributed with this work for additional
#  information regarding copyright ownership.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
#
#  SPDX-License-Identifier: Apache-2.0
#
#  Contributors:
#       Circular Solution Co., Ltd - production config
#

## Normally, you shouldn't need to change any values here. If you do, please be sure to also change them in the seed script (seed-k8s.sh).
## Neglecting to do that will render the connectors and identity hubs inoperable!


variable "humanReadableName" {
  type        = string
  description = "Human readable name of the connector, NOT the ID!!. Required."
}

variable "participantId" {
  type        = string
  description = "Participant ID of the connector. Usually a DID"
}

variable "namespace" {
  type = string
}

variable "ports" {
  type = object({
    web             = number
    debug           = number
    ih-debug        = number
    ih-did          = number
    ih-identity-api = number
    credentials-api = number
    sts-api         = number
  })
  default = {
    web             = 7080
    debug           = 1044
    ih-debug        = 1044
    ih-did          = 7083
    ih-identity-api = 7081
    credentials-api = 7082
    sts-api         = 7084
  }
}

variable "ih_superuser_apikey" {
  default     = "c3VwZXItdXNlcg==.c3VwZXItc2VjcmV0LWtleQo="
  description = "Management API Key for the Super-User. Defaults to 'base64(super-user).base64(super-secret-key)"
  type        = string
}

variable "vault-url" {
  description = "URL of the Hashicorp Vault"
  type        = string
}

variable "vault-token" {
  default     = "root"
  description = "This is the authentication token for the vault. DO NOT USE THIS IN PRODUCTION!"
  type        = string
}

variable "aliases" {
  type = object({
    sts-private-key   = string
    sts-public-key-id = string
  })
  default = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }
}

variable "service-name" {
  type        = string
  description = "Name of the Service endpoint"
}

variable "database" {
  type = object({
    url      = string
    user     = string
    password = string
  })
}

variable "use-https" {
  type    = bool
  default = false
}

variable "useSVE" {
  type        = bool
  description = "If true, the -XX:UseSVE=0 switch (Scalable Vector Extensions) will be appended to the JAVA_TOOL_OPTIONS. Can help on macOs on Apple Silicon processors"
  default     = false
}

variable "sts-token-path" {
  description = "path suffix of the STS token API"
  type        = string
  default     = "/api/sts"
}

variable "gxdch_public_did" {
  type        = string
  default     = ""
  description = "Public DID override (did:web:...) used when signing for GXDCH. Empty = use participantId"
}

variable "gxdch_base_id" {
  type        = string
  default     = "https://example.com"
  description = "Base URL for self-signed credential IDs"
}

variable "gxdch_legal_name" {
  type    = string
  default = "Example Company"
}

variable "gxdch_country_code" {
  type    = string
  default = "KR"
}

variable "gxdch_lei" {
  type    = string
  default = ""
}

variable "gxdch_signing_key_alias" {
  type    = string
  default = "gxdch-signing-key"
}

variable "gxdch_verification_method_id" {
  type    = string
  default = "X509-JWK"
}

variable "gxdch_notary_url" {
  type    = string
  default = "https://registrationnumber.notary.lab.gaia-x.eu/v2"
}

variable "gxdch_compliance_url" {
  type    = string
  default = "https://compliance.lab.gaia-x.eu/v2"
}

variable "gxdch_compliance_level" {
  type    = string
  default = "standard-compliance"
}

variable "aws_access_key_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gxdch_s3_bucket" {
  type    = string
  default = ""
}

variable "gxdch_s3_region" {
  type    = string
  default = "ap-northeast-2"
}
