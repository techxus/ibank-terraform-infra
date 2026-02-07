# ------------------------------------------------------------
# GitHub Actions -> AWS auth using OIDC (no long-lived keys)
# This is "once per AWS account" setup.
# ------------------------------------------------------------

# 1) Create the GitHub OIDC provider in AWS (once)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # GitHub Actions OIDC thumbprint (commonly used)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# 2) IAM Role that GitHub Actions will assume
# IMPORTANT: set your GitHub org/repo here
locals {
  github_org  = "techxus"
  github_repo = "ibank-infra"
}

resource "aws_iam_role" "github_actions_terraform" {
  name = "github-actions-ibank-infra"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # Allow ANY workflow in this repo.
          # Later you can tighten this to only main branch.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${local.github_org}/${local.github_repo}:ref:refs/heads/master"
          }
        }
      }
    ]
  })
}

# 3) Permissions for Terraform from GitHub Actions
# Easiest to start: AdministratorAccess.
# Later: replace with least-privilege.
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 4) Output the role ARN (this becomes AWS_GITHUB_OIDC_ROLE_ARN)
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}
