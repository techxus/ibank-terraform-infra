variable "region" { type = string }
variable "cluster_name" { type = string }
variable "allowed_api_cidrs" { type = list(string) }

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA (optional if created inside this module)"
  type        = string
  default     = null
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (issuer) for IRSA (optional if created inside this module)"
  type        = string
  default     = null
}

variable "redis_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for Redis auth secret"
}

