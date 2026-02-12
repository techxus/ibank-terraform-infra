############################################
# EKS Cluster Outputs (pass-through)
############################################

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider
}

############################################
# VPC/Subnet Outputs for RDS + networking
############################################

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

############################################
# Security group outputs
############################################

# Node SG is the safest default to allow DB traffic from your worker nodes.
output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

# Useful sometimes for cluster-to-something rules
output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "msk_bootstrap_brokers" {
  value = aws_msk_cluster.kafka.bootstrap_brokers_sasl_scram
}

output "msk_app_secret_arn" {
  value = aws_secretsmanager_secret.msk_app.arn
}

output "msk_app_secret_name" {
  value = aws_secretsmanager_secret.msk_app.name
}

output "msk_bootstrap_brokers_tls" {
  value = aws_msk_cluster.kafka.bootstrap_brokers_tls
}

output "msk_cluster_arn" {
  value = aws_msk_cluster.kafka.arn
}

