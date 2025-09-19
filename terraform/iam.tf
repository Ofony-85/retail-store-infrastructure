# Developer IAM User
resource "aws_iam_user" "developer" {
  name = "${var.project_name}-developer"
  path = "/"

  tags = merge(local.common_tags, {
    Role = "Developer"
  })
}

# Developer Access Keys
resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name
}

resource "aws_iam_policy" "developer_eks_readonly" {
  name        = "${var.project_name}-developer-enhanced-readonly"
  path        = "/"
  description = "Enhanced read-only access to EKS cluster and AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates",
          "eks:DescribeFargateProfile",
          "eks:ListFargateProfiles",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:DescribeIdentityProviderConfig",
          "eks:ListIdentityProviderConfigs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeImages",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:GetUser",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies",
          "iam:GetRolePolicy",
          "iam:GetUserPolicy",
          "iam:ListUsers",
          "iam:ListRoles",
          "iam:ListPolicies"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroupAttributes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackResources",
          "cloudformation:ListStacks"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach policy to developer user
resource "aws_iam_user_policy_attachment" "developer_eks_readonly" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_eks_readonly.arn
}

# Kubernetes RBAC for developer
resource "kubernetes_namespace" "retail_store" {
  metadata {
    name = "retail-store"
  }

  depends_on = [aws_eks_cluster.main]
}

resource "kubernetes_cluster_role" "developer_readonly" {
  metadata {
    name = "developer-readonly"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "persistentvolumeclaims", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }

  depends_on = [aws_eks_cluster.main]
}

resource "kubernetes_cluster_role_binding" "developer_readonly" {
  metadata {
    name = "developer-readonly-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.developer_readonly.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${aws_iam_user.developer.name}"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [aws_eks_cluster.main]
}

# ConfigMap for AWS auth
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_node_group.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])

    mapUsers = yamlencode([
      {
        userarn  = aws_iam_user.developer.arn
        username = aws_iam_user.developer.name
        groups   = ["developer-readonly"]
      }
    ])
  }

  depends_on = [aws_eks_cluster.main]
}


