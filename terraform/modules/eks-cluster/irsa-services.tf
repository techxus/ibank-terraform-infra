data "aws_caller_identity" "current" {}

locals {
  region = try(var.region, "us-east-1")
  rds_secret_arn = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/rds/postgres-*"
  redis_secret_arn = var.redis_secret_arn

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

module "irsa_db_secrets_sa" {
  source = "../irsa-service-account"

  cluster_name         = var.cluster_name
  namespace            = "apps-dev"
  service_account_name = "db-secrets-sa"

  oidc_provider_url    = local.effective_oidc_provider_url
  oidc_provider_arn    = local.effective_oidc_provider_arn

  role_name            = "${var.cluster_name}-db-secrets-sa"
  policy_name          = "${var.cluster_name}-db-secrets-sa-secrets-read"

  secret_arns = [
    local.rds_secret_arn,
    local.redis_secret_arn
  ]
}
