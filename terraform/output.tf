# outputs.tf

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

# Developer credentials (sensitive)
output "developer_access_key_id" {
  description = "Access key ID for developer user"
  value       = aws_iam_access_key.developer.id
  sensitive   = true
}

output "developer_secret_access_key" {
  description = "Secret access key for developer user"
  value       = aws_iam_access_key.developer.secret
  sensitive   = true
}

output "developer_user_arn" {
  description = "ARN of the developer IAM user"
  value       = aws_iam_user.developer.arn
}

# Kubeconfig command
output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}