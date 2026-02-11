############################################
# Allow private EC2 → AWS SSM via VPC endpoints
############################################
data "aws_vpc" "eks" {
  id = module.eks.vpc_id
}


resource "aws_security_group" "ssm_endpoints" {
  name        = "${var.cluster_name}-ssm-endpoints"
  description = "SSM interface endpoints"
  vpc_id      = module.eks.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.eks.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  endpoint_subnets = module.eks.private_subnets
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.eks.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.eks.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.eks.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.endpoint_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}
