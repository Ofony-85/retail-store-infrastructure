# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "bedrock"
environment  = "production"

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.10.0/24", "10.0.20.0/24"]

# EKS Configuration
kubernetes_version    = "1.28"
node_instance_types   = ["t3.medium"]
desired_nodes        = 3
min_nodes           = 1
max_nodes           = 5

# EC2 Key Pair (optional - for SSH access to worker nodes)
key_pair_name = "ofonweb_key"
enable_managed_db = false 
domain_name = "example.com"

