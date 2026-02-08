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

############################################
# RDS defaults (production-grade baseline)
############################################

variable "rds_instance_class" {
  type        = string
  description = "RDS instance class for PostgreSQL"
  default     = "db.m7g.large"
}

variable "rds_allocated_storage" {
  type        = number
  description = "Initial storage in GB"
  default     = 100
}

variable "rds_max_allocated_storage" {
  type        = number
  description = "Max autoscaling storage in GB"
  default     = 500
}

variable "rds_backup_retention_days" {
  type        = number
  description = "Backup retention days"
  default     = 14
}

variable "rds_multi_az" {
  type        = bool
  description = "Multi-AZ for RDS (dev should be false to save cost)"
  default     = true
}

variable "apps_namespace" {
  type        = string
  description = "Namespace where your Spring Boot services run"
  default     = "apps-dev"
}



