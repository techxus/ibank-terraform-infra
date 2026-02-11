############################################
# ElastiCache Redis + Secret
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
  name_prefix = "${var.cluster_name}-redis-"
  description = "Redis access from EKS nodes + db-access (SSM tunnel)"
  vpc_id      = module.eks.vpc_id

  tags = {
    Name = "${var.cluster_name}-redis"
  }

  lifecycle {
    create_before_destroy = true
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
  num_cache_clusters         = 2
}

resource "aws_security_group_rule" "redis_ingress_from_eks_nodes" {
  type                     = "ingress"
  security_group_id        = aws_security_group.redis.id
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  description              = "Redis from EKS nodes"
}

resource "aws_security_group_rule" "redis_ingress_from_db_access" {
  type                     = "ingress"
  security_group_id        = aws_security_group.redis.id
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = tolist(data.aws_instance.db_access.vpc_security_group_ids)[0]
  description              = "Redis from db-access (SSM tunnel)"
}

resource "aws_security_group_rule" "redis_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.redis.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

