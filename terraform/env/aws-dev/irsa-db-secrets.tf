############################################
# IRSA Role for apps to read ONE secret from Secrets Manager
############################################

data "aws_iam_policy_document" "db_secrets_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.apps_namespace}:db-secrets-reader"]
    }
  }
}

resource "aws_iam_role" "db_secrets_reader" {
  name               = "${var.cluster_name}-db-secrets-reader"
  assume_role_policy = data.aws_iam_policy_document.db_secrets_assume_role.json
}

data "aws_iam_policy_document" "db_secrets_reader_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.rds_master.arn
    ]
  }
}

resource "aws_iam_policy" "db_secrets_reader" {
  name   = "${var.cluster_name}-db-secrets-reader"
  policy = data.aws_iam_policy_document.db_secrets_reader_policy.json
}

resource "aws_iam_role_policy_attachment" "db_secrets_reader" {
  role       = aws_iam_role.db_secrets_reader.name
  policy_arn = aws_iam_policy.db_secrets_reader.arn
}

output "db_secrets_reader_role_arn" {
  value = aws_iam_role.db_secrets_reader.arn
}
