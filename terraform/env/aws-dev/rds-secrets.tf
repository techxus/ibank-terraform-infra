############################################
# RDS PostgreSQL Master Credentials
# Stored in AWS Secrets Manager as JSON
############################################

resource "random_password" "rds_master" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "rds_master" {
  name                    = "${var.cluster_name}/rds/postgres"
  description             = "Master credentials for RDS PostgreSQL used by EKS services"
  recovery_window_in_days = 7

  tags = {
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id

  secret_string = jsonencode({
    username = "appuser"
    password = random_password.rds_master.result
    dbname   = "appdb"
  })
}

output "rds_master_secret_name" {
  value = aws_secretsmanager_secret.rds_master.name
}

output "rds_master_secret_arn" {
  value = aws_secretsmanager_secret.rds_master.arn
}
