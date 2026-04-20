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

variable "consumer-did" {
  default = "did:web:consumer-identityhub%3A7083"
}

variable "provider-did" {
  default = "did:web:provider-identityhub%3A7083"
}

variable "issuer-did" {
  default = "did:web:dataspace-issuer-service%3A10016"
}

variable "gxdch_public_did" {
  type        = string
  default     = ""
  description = "Publicly-resolvable did:web used for GXDCH signing (leave blank to skip)"
}

variable "gxdch_domain" {
  type        = string
  default     = ""
  description = "Base URL matching gxdch_public_did (e.g. https://example.com for did:web:example.com). Used to derive per-participant gxdch_base_id"
}

variable "gxdch_notary_url" {
  type    = string
  default = "https://www.delta-dao.com/notary/v2"
}

variable "gxdch_compliance_url" {
  type        = string
  default     = "https://www.delta-dao.com/compliance/v2"
  description = "GXDCH compliance endpoint"
}

variable "useSVE" {
  type        = bool
  description = "If true, the -XX:UseSVE=0 switch (Scalable Vector Extensions) will be added to the JAVA_TOOL_OPTIONS. Can help on macOs on Apple Silicon processors"
  default     = true
}

variable "rds-host" {
  description = "RDS endpoint hostname"
  default     = "YOUR_RDS_ENDPOINT.rds.amazonaws.com"
}

variable "rds-port" {
  description = "RDS port"
  default     = "5432"
}

variable "rds-master-user" {
  description = "RDS master username"
  default     = "postgres"
}

variable "rds-master-password" {
  description = "RDS master password"
  sensitive   = true
  default     = ""
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
  type        = string
  default     = ""
  description = "LEI code for GXDCH notary registration"
}

variable "gxdch_verification_method_id" {
  type        = string
  default     = "X509-JWK"
  description = "DID document verification method fragment (e.g. JWK2020-RSA)"
}

variable "gx_basic_functions_enabled" {
  type    = bool
  default = false
}

variable "gxdch_registry_url" {
  type    = string
  default = "https://www.delta-dao.com/registry/v2"
}
