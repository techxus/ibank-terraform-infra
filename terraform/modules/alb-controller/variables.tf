variable "region" { type = string }
variable "cluster_name" { type = string }

variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca_data" {
  type = string
}
