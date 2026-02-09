############################################
# IRSA for notification-service to read RDS creds from Secrets Manager
############################################

data "aws_caller_identity" "current" {}

locals {
  region = try(var.region, "us-east-1")

  # Allow read of the terraform-created secret (name prefix)
  # You can keep this wildcard approach, or pass exact ARN as a variable later.
  secret_arn = "arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:ibank-eks-dev/rds/postgres-*"

  notification_namespace            = "apps-dev"
  notification_service_account_name = "notification-service-sa"

  # OIDC provider URL/ARN: prefer variables if provided, otherwise use discovered existing provider
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

############################################
# Trust policy for IRSA
############################################
data "aws_iam_policy_document" "notification_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.effective_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(local.effective_oidc_provider_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:${local.notification_namespace}:${local.notification_service_account_name}"
      ]
    }
  }
}

resource "aws_iam_role" "notification_irsa" {
  name               = "${var.cluster_name}-notification-irsa"
  assume_role_policy = data.aws_iam_policy_document.notification_assume_role.json
}

############################################
# Policy: read Secrets Manager secret
############################################
data "aws_iam_policy_document" "notification_secrets_read" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [local.secret_arn]
  }
}

resource "aws_iam_policy" "notification_secrets_read" {
  name   = "${var.cluster_name}-notification-secrets-read"
  policy = data.aws_iam_policy_document.notification_secrets_read.json
}

resource "aws_iam_role_policy_attachment" "notification_attach" {
  role       = aws_iam_role.notification_irsa.name
  policy_arn = aws_iam_policy.notification_secrets_read.arn
}

output "notification_irsa_role_arn" {
  value = aws_iam_role.notification_irsa.arn
}
