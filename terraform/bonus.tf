# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  count = var.enable_managed_db ? 1 : 0

  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# RDS Security Group
resource "aws_security_group" "rds" {
  count = var.enable_managed_db ? 1 : 0

  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS databases"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })
}

# RDS MySQL
resource "aws_db_instance" "mysql" {
  count = var.enable_managed_db ? 1 : 0

  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "catalog"
  username = "catalog_user"
  password = random_password.mysql_password[0].result

  vpc_security_group_ids = [aws_security_group.rds[0].id]
  db_subnet_group_name   = aws_db_subnet_group.main[0].name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-mysql"
  })

  depends_on = [aws_db_subnet_group.main, aws_security_group.rds]
}

# RDS PostgreSQL
resource "aws_db_instance" "postgresql" {
  count = var.enable_managed_db ? 1 : 0

  identifier     = "${var.project_name}-postgresql"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "orders"
  username = "orders_user"
  password = random_password.postgresql_password[0].result

  vpc_security_group_ids = [aws_security_group.rds[0].id]
  db_subnet_group_name   = aws_db_subnet_group.main[0].name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-postgresql"
  })

  depends_on = [aws_db_subnet_group.main, aws_security_group.rds]
}

# Random passwords
resource "random_password" "mysql_password" {
  count   = var.enable_managed_db ? 1 : 0
  length  = 16
  special = true
}

resource "random_password" "postgresql_password" {
  count   = var.enable_managed_db ? 1 : 0
  length  = 16
  special = true
}

# DynamoDB Table
resource "aws_dynamodb_table" "carts" {
  count = var.enable_managed_db ? 1 : 0

  name         = "carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-carts-table"
  })
}

# IAM Role Policy for DynamoDB
resource "aws_iam_role_policy" "eks_nodes_dynamodb" {
  count = var.enable_managed_db ? 1 : 0

  name = "${var.project_name}-eks-nodes-dynamodb"
  role = aws_iam_role.eks_node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.carts[0].arn
      }
    ]
  })

  depends_on = [aws_dynamodb_table.carts]
}

# OIDC Identity Provider
data "tls_certificate" "eks" {
  url        = aws_eks_cluster.main.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.main]
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = local.common_tags
}

# AWS Load Balancer Controller IAM Policy
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "iam:CreateServiceLinkedRole",
          "cognito-idp:Describe*",
          "waf-regional:GetWebACL",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL"
        ]
        Resource = "*"
      }
    ]
  })
}

# AWS Load Balancer Controller IAM Role
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policy to the Role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
