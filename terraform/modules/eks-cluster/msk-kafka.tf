############################################
# MSK (Kafka) + SCRAM secret + SG
############################################

resource "random_password" "msk_scram_password" {
  length  = 32
  special = false
}

############################################
# KMS key for MSK SCRAM secrets (required by MSK)
############################################
resource "aws_kms_key" "msk_scram" {
  description             = "CMK for MSK SCRAM secret encryption (${var.cluster_name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "msk_scram" {
  name          = "alias/${var.cluster_name}-msk-scram"
  target_key_id = aws_kms_key.msk_scram.key_id
}

############################################
# MSK Security Group
# - 9094: TLS (non-SASL) client endpoint (optional)
# - 9096: SASL/SCRAM client endpoint (REQUIRED for your current bootstrap brokers)
############################################
resource "aws_security_group" "msk" {
  name        = "${var.cluster_name}-msk"
  description = "MSK access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Kafka TLS (9094) from EKS nodes"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    description     = "Kafka SASL/SCRAM (9096) from EKS nodes"
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# Secret that MSK will use for SCRAM user
# MSK REQUIREMENTS:
#  - Secret name must start with "AmazonMSK_"
#  - Secret must be encrypted with a customer-managed KMS key (NOT default)
############################################
resource "aws_secretsmanager_secret" "msk_scram" {
  name                    = "AmazonMSK_${var.cluster_name}_scram"
  description             = "MSK SCRAM credentials for ${var.cluster_name}"
  recovery_window_in_days = 7

  # ✅ REQUIRED by MSK: use CMK (customer managed KMS key)
  kms_key_id = aws_kms_key.msk_scram.arn

  tags = {
    Project = var.cluster_name
    Env     = "aws-dev"
    Managed = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "msk_scram" {
  secret_id = aws_secretsmanager_secret.msk_scram.id
  secret_string = jsonencode({
    username = "appuser"
    password = random_password.msk_scram_password.result
  })
}

############################################
# MSK cluster
############################################
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.cluster_name}-msk"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type  = "kafka.t3.small"
    client_subnets = module.vpc.private_subnets
    security_groups = [
      aws_security_group.msk.id
    ]

    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS" # MSK uses TLS on client endpoints; SASL/SCRAM rides over TLS (9096)
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      scram = true
    }
  }

  enhanced_monitoring = "PER_TOPIC_PER_BROKER"
}

############################################
# Associate SCRAM secret with MSK
############################################
resource "aws_msk_scram_secret_association" "kafka" {
  cluster_arn     = aws_msk_cluster.kafka.arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram.arn]
}

############################################
# Store runtime connection info in a separate app secret
# (this is what pods should read via CSI)
############################################
resource "aws_secretsmanager_secret" "msk_app" {
  name        = "${var.cluster_name}/msk/app"
  description = "MSK bootstrap brokers + config for apps"
}

resource "aws_secretsmanager_secret_version" "msk_app" {
  secret_id = aws_secretsmanager_secret.msk_app.id
  secret_string = jsonencode({
    bootstrapBrokers  = aws_msk_cluster.kafka.bootstrap_brokers_sasl_scram
    securityProtocol  = "SASL_SSL"
    saslMechanism     = "SCRAM-SHA-512"
    username          = "appuser"
    password          = random_password.msk_scram_password.result
  })
}
