############################################
# Private EC2 for SSM DB access (no public IP)
############################################

# Latest Amazon Linux 2023 AMI (x86)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################################
# Security group for db-access instance
############################################

resource "aws_security_group" "db_access" {
  name        = "${var.cluster_name}-db-access-sg"
  description = "SSM access host for private RDS"
  vpc_id      = module.eks.vpc_id

  # No inbound rules → cannot be reached from internet

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.cluster_name}-db-access-sg"
    Project = var.cluster_name
    Env     = "aws-dev"
  }
}

############################################
# Allow this instance to reach RDS on 5432
############################################

resource "aws_security_group_rule" "rds_from_db_access" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db_access.id
  description              = "Allow Postgres from db-access instance"
}

############################################
# IAM role for SSM
############################################

data "aws_iam_policy_document" "ssm_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "db_access_ssm" {
  name               = "${var.cluster_name}-db-access-ssm"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json
}

resource "aws_iam_role_policy_attachment" "db_access_ssm" {
  role       = aws_iam_role.db_access_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "db_access_ssm" {
  name = "${var.cluster_name}-db-access-ssm"
  role = aws_iam_role.db_access_ssm.name
}

############################################
# EC2 instance (private, SSM-only)
############################################

resource "aws_instance" "db_access" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.nano"
  subnet_id                   = module.eks.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.db_access.id]
  iam_instance_profile        = aws_iam_instance_profile.db_access_ssm.name
  associate_public_ip_address = false

  tags = {
    Name    = "${var.cluster_name}-db-access"
    Project = var.cluster_name
    Env     = "aws-dev"
  }
}

output "db_access_instance_id" {
  value = aws_instance.db_access.id
}
