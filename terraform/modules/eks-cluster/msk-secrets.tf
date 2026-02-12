resource "aws_secretsmanager_secret" "msk" {
  name        = "${var.cluster_name}/msk/bootstrap"
  description = "MSK bootstrap brokers for ${var.cluster_name}"
}

resource "aws_secretsmanager_secret_version" "msk" {
  secret_id = aws_secretsmanager_secret.msk.id

  secret_string = jsonencode({
    bootstrapServersTls = aws_msk_cluster.kafka.bootstrap_brokers_tls
    securityProtocol    = "SSL"
  })
}

output "msk_secret_arn" {
  value = aws_secretsmanager_secret.msk.arn
}
