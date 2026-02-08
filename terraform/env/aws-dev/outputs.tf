output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "acm_cert_arn" { value = aws_acm_certificate_validation.api_cert.certificate_arn }

# Needed for RDS provisioning
output "vpc_id" { value = module.eks.vpc_id }
output "private_subnets" { value = module.eks.private_subnets }
output "public_subnets" { value = module.eks.public_subnets }
output "node_security_group_id" { value = module.eks.node_security_group_id }
output "cluster_security_group_id" { value = module.eks.cluster_security_group_id }
