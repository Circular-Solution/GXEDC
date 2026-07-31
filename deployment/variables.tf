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
  default     = ""
}

variable "gx_basic_functions_url" {
  type        = string
  description = "Production Gaia-X Basic Functions URL"
}

variable "use-https" {
  type        = bool
  description = "Resolve did:web over HTTPS. Must be true for publicly hosted DID documents."
  default     = false
}

variable "kubeconfig-path" {
  type        = string
  description = "Path to the kubeconfig. k3s writes /etc/rancher/k3s/k3s.yaml."
  default     = "~/.kube/config"
}

variable "enable-issuer" {
  type        = bool
  description = "Deploy the dataspace issuer service. Not needed when credentials are issued outside the dataspace."
  default     = true
}

variable "consumer-dataplane-public-url" {
  type        = string
  default     = ""
  description = "Publicly reachable base URL of the consumer data plane. Required when data is pulled from outside the cluster."
}

variable "provider-dataplane-public-url" {
  type        = string
  default     = ""
  description = "Publicly reachable base URL of the provider data plane. Required when data is pulled from outside the cluster."
}

variable "enable-catalog-server" {
  type        = bool
  description = "Deploy the federated catalog server. Not needed when partners are queried directly over DSP."
  default     = true
}


variable "identityhub-hosts" {
  type        = list(string)
  description = "Hostnames the shared identity hub answers on for the identity and credentials APIs."
  default     = ["consumer.local", "provider.local"]
}
