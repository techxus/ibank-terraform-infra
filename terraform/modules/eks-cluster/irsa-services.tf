data "aws_caller_identity" "current" {}

locals {
  region = try(var.region, "us-east-1")

  # same wildcard you used (fine for now)
  rds_secret_arn = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:ibank-eks-dev/rds/postgres-*"

  effective_oidc_provider_url = coalesce(
    var.oidc_provider_url,
    data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  )

  effective_oidc_provider_arn = coalesce(
    var.oidc_provider_arn,
    try(data.aws_iam_openid_connect_provider.existing.arn, null),
    try(aws_iam_openid_connect_provider.eks[0].arn, null)
  )
}

module "irsa_notification_service" {
  source = "../irsa-service-account"

  cluster_name          = var.cluster_name
  namespace             = "apps-dev"
  service_account_name  = "notification-service-sa"

  oidc_provider_url     = local.effective_oidc_provider_url
  oidc_provider_arn     = local.effective_oidc_provider_arn

  role_name             = "${var.cluster_name}-notification-irsa"
  policy_name           = "${var.cluster_name}-notification-secrets-read"

  secret_arns           = [local.rds_secret_arn]
}

module "irsa_user_service" {
  source = "../irsa-service-account"

  cluster_name          = var.cluster_name
  namespace             = "apps-dev"
  service_account_name  = "user-service-sa"

  oidc_provider_url     = local.effective_oidc_provider_url
  oidc_provider_arn     = local.effective_oidc_provider_arn

  role_name             = "${var.cluster_name}-user-irsa"
  policy_name           = "${var.cluster_name}-user-secrets-read"

  secret_arns           = [local.rds_secret_arn]
}

module "irsa_db_secrets_sa" {
  source = "../irsa-service-account"

  cluster_name         = var.cluster_name
  namespace            = "apps-dev"
  service_account_name = "db-secrets-sa"

  oidc_provider_url    = local.effective_oidc_provider_url
  oidc_provider_arn    = local.effective_oidc_provider_arn

  # stable names (no collisions)
  role_name            = "${var.cluster_name}-db-secrets-sa"
  policy_name          = "${var.cluster_name}-db-secrets-sa-secrets-read"

  # wildcard for the secret name (works even with the random suffix)
  secret_arns          = [local.rds_secret_arn]
}



