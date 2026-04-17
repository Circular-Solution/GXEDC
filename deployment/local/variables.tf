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
  default     = "CHANGE_ME"
}

variable "gxdch_legal_name" {
  type    = string
  default = "Zhen Software"
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
