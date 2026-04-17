variable "humanReadableName" {
  type        = string
  description = "Human readable name. should not contain special characters"
  default     = "gx-basic-functions"
}

variable "namespace" {
  type = string
}

variable "enabled" {
  type        = bool
  description = "Whether to deploy Gaia-X Basic Functions. Set to false if using an external instance"
  default     = true
}

variable "external_url" {
  type        = string
  description = "External Gaia-X Basic Functions URL (if set no in-cluster deployment is created)"
  default     = ""
}

variable "image" {
  type        = string
  description = "Docker image for gx-basic-functions"
  default     = "gx-basic-functions:latest"
}

variable "image_pull_policy" {
  type    = string
  default = "Never"
}

variable "registry_url" {
  type        = string
  description = "Gaia-X Registry URL used by basic functions"
  default     = "https://registry.lab.gaia-x.eu/v2"
}

variable "container_port" {
  type    = number
  default = 3000
}
