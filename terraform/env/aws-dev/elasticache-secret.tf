resource "aws_secretsmanager_secret" "redis" {
  name = "${var.cluster_name}/redis"
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id

  secret_string = jsonencode({
    username = "default"
    password = random_password.redis.result
  })
}

resource "random_password" "redis" {
  length  = 32
  special = false
}

output "redis_secret_arn" {
  value = aws_secretsmanager_secret.redis.arn
}

