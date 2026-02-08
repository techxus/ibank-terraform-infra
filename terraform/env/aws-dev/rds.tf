############################################
# RDS PostgreSQL (Production-grade defaults)
############################################

locals {
  rds_identifier = "${var.cluster_name}-postgres"
  rds_name       = "appdb"
  rds_port       = 5432
}

# Subnet group: private subnets only
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.cluster_name}-rds-private"
  subnet_ids = module.eks.private_subnets

  tags = {
    Name    = "${var.cluster_name}-rds-private"
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

# Security group for RDS: only allow Postgres from EKS worker nodes
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "RDS PostgreSQL: allow access only from EKS node SG"
  vpc_id      = module.eks.vpc_id

  tags = {
    Name    = "${var.cluster_name}-rds-sg"
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

resource "aws_security_group_rule" "rds_ingress_from_eks_nodes" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = local.rds_port
  to_port                  = local.rds_port
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  description              = "Postgres from EKS node security group"
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.rds.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Force SSL at the DB level (recommended)
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.cluster_name}-postgres16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

############################################
# RDS Enhanced Monitoring Role (required)
############################################

data "aws_iam_policy_document" "rds_monitoring_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${var.cluster_name}-rds-enhanced-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}


# RDS instance
resource "aws_db_instance" "postgres" {
  identifier = local.rds_identifier

  engine = "postgres"
  # Pin major family using parameter group; keep minor upgrades automatic.
  # AWS currently supports 16.x and newer. See AWS release notes.
  engine_version = "16.9" # update later if needed
  instance_class = var.rds_instance_class

  db_name  = jsondecode(aws_secretsmanager_secret_version.rds_master.secret_string)["dbname"]
  username = jsondecode(aws_secretsmanager_secret_version.rds_master.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.rds_master.secret_string)["password"]

  port = local.rds_port

  multi_az            = var.rds_multi_az
  publicly_accessible = false

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Storage
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Backups / maintenance
  backup_retention_period = var.rds_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"

  # Monitoring
  performance_insights_enabled    = true
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Safety
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.cluster_name}-postgres-final"

  # Apply behavior
  apply_immediately          = false
  auto_minor_version_upgrade = true

  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "rds_db_name" {
  value     = aws_db_instance.postgres.db_name
  sensitive = true
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
