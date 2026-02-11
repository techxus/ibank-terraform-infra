# Needed by ssm-endpoints.tf
data "aws_vpc" "eks" {
  id = module.eks.vpc_id
}
