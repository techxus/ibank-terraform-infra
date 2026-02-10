variable "cluster_name" { type = string }

variable "namespace" { type = string }
variable "service_account_name" { type = string }

variable "oidc_provider_url" { type = string }
variable "oidc_provider_arn" { type = string }

# Role/policy names
variable "role_name" { type = string }
variable "policy_name" { type = string }

# What secrets can be read
variable "secret_arns" {
  type = list(string)
}
