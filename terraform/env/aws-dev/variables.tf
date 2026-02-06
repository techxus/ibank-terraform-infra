variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "ibank-eks-dev"
}

variable "allowed_api_cidrs" {
  description = "CIDRs allowed to access EKS API endpoint (e.g. your IP /32)"
  type        = list(string)
}

variable "public_zone_name" {
  description = "Route53 public hosted zone name"
  type        = string
  default     = "bankit.cloud"
}

variable "api_hostname" {
  description = "Public API hostname"
  type        = string
  default     = "api.dev.bankit.cloud"
}

variable "gitops_repo_url" {
  description = "GitOps repo URL"
  type        = string
  default     = "https://github.com/techxus/ibank-minikube-gitops.git"
}

variable "gitops_target_revision" {
  type    = string
  default = "master"
}

variable "gitops_root_path" {
  description = "Path in GitOps repo for Argo root app"
  type        = string
  default     = "argocd"
}
