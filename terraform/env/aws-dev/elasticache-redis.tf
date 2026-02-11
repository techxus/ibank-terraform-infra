############################################
# ElastiCache Redis (Valkey-compatible) + Secret
############################################

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis" {
  name = "${var.cluster_name}/redis/auth"
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id     = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    host      = aws_elasticache_replication_group.redis.primary_endpoint_address
    port      = 6379
    authToken = random_password.redis_auth_token.result
    tls       = true
  })
}

# Lookup the db-access instance so we can allow SSM-tunneled access to Redis
# Instance tag Name must be: "${var.cluster_name}-db-access" (your example: ibank-eks-dev-db-access)
data "aws_instance" "db_access" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-db-access"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis"
  description = "Redis access from EKS nodes + db-access (SSM tunnel)"
  vpc_id      = module.eks.vpc_id

  ingress {
    description     = "From EKS nodes + db-access SGs"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = concat(
      [module.eks.node_security_group_id],
      tolist(data.aws_instance.db_access.vpc_security_group_ids)
    )
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis"
  subnet_ids = module.eks.private_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.cluster_name}-redis"
  description          = "Redis for ${var.cluster_name}"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.small"
  port           = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result

  multi_az_enabled           = true
  automatic_failover_enabled = true

  num_cache_clusters = 2
}
