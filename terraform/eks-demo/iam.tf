# ---------------------------------------------------------------
# EKS cluster + node IAM roles
# ---------------------------------------------------------------

data "aws_iam_policy_document" "eks_cluster_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "eks_node_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.eks_node_trust.json
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------------------------------------------------------
# Dedicated GitHub Actions OIDC role, scoped to just the two eks-demo
# lifecycle workflows via the job_workflow_ref claim - deliberately
# separate from the shared "github-actions-resume-site" role (see
# terraform/github-oidc/main.tf) so a compromise of the regular deploy
# pipeline can never reach EKS/EC2/IAM-CreateRole/AutoScaling permissions.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "eks_demo_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values = [
        "${var.github_repo}/.github/workflows/spin-up-eks-demo.yml@refs/heads/main",
        "${var.github_repo}/.github/workflows/teardown-eks-demo.yml@refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "eks_demo_lifecycle" {
  name               = "github-actions-eks-demo-lifecycle"
  assume_role_policy = data.aws_iam_policy_document.eks_demo_trust.json
}

data "aws_iam_policy_document" "eks_demo_lifecycle_permissions" {
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::resume-site-tfstate-ACCOUNT_ID_REDACTED",
      "arn:aws:s3:::resume-site-tfstate-ACCOUNT_ID_REDACTED/*",
    ]
  }

  statement {
    sid    = "SiteStateReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::resume-site-tfstate-ACCOUNT_ID_REDACTED/site/terraform.tfstate",
    ]
  }

  statement {
    sid    = "EksManagement"
    effect = "Allow"
    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:ListTagsForResource",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "eks:CreateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:ListAssociatedAccessPolicies",
      "eks:AccessKubernetesApi",
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:ACCOUNT_ID_REDACTED:cluster/${var.cluster_name}",
      "arn:aws:eks:${var.aws_region}:ACCOUNT_ID_REDACTED:nodegroup/${var.cluster_name}/*/*",
      "arn:aws:eks:${var.aws_region}:ACCOUNT_ID_REDACTED:access-entry/${var.cluster_name}/*/*/*",
    ]
  }

  # EC2/VPC create-family actions don't support resource-level ARN scoping
  # for creation - same acceptance already made for CloudFrontManagement in
  # terraform/github-oidc/main.tf.
  statement {
    sid    = "NetworkManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeAddresses",
      # AWS Load Balancer Controller's own runtime permissions (it creates
      # the ALB/target groups/listeners directly via the EC2/ELB APIs, not
      # via Terraform) - the demo cluster's node role also needs this via
      # the ALB controller's IRSA role (see cluster.tf), but the workflow
      # itself needs read access here for the post-install wait/poll step.
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      # Used by teardown-eks-demo.yml's wait-for-ALB-deletion loop to check
      # for any remaining load balancer tagged for this cluster before
      # terraform destroy touches the VPC underneath it.
      "resourcegroupstaggingapi:GetResources",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IamRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]
    resources = [
      "arn:aws:iam::ACCOUNT_ID_REDACTED:role/${var.cluster_name}-*",
      "arn:aws:iam::ACCOUNT_ID_REDACTED:oidc-provider/*",
    ]
  }

  statement {
    sid    = "AutoScalingForManagedNodegroup"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
    ]
    resources = ["*"]
  }

  # EKS managed node groups and the node's own IAM role creation each
  # provision an AWS service-linked role on first use per account - one-time
  # per account, but granted defensively since this is the first stack in
  # this account to create an EKS cluster.
  statement {
    sid    = "ServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "CostAllocationAndBudget"
    effect = "Allow"
    actions = [
      "ce:CreateCostAllocationTag",
      "ce:UpdateCostAllocationTagsStatus",
      "ce:ListCostAllocationTags",
      "budgets:ViewBudget",
      "budgets:ModifyBudget",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Route53DemoRecords"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone",
    ]
    resources = ["arn:aws:route53:::hostedzone/Z090356212OBKYAPYDLK1"]
  }

  statement {
    sid       = "Route53ChangeStatus"
    effect    = "Allow"
    actions   = ["route53:GetChange"]
    resources = ["*"]
  }

  statement {
    sid       = "StsIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid    = "ClusterStatusWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
    ]
    # Table lives in the persistent stack (terraform/site/, see
    # cluster_control.tf) - referenced by its stable, known ARN rather than
    # a remote-state read, since only the ARN (not any other site-stack
    # detail) is needed here.
    resources = ["arn:aws:dynamodb:${var.aws_region}:ACCOUNT_ID_REDACTED:table/site-eks-demo-status"]
  }
}

resource "aws_iam_role_policy" "eks_demo_lifecycle_permissions" {
  name   = "eks-demo-lifecycle"
  role   = aws_iam_role.eks_demo_lifecycle.id
  policy = data.aws_iam_policy_document.eks_demo_lifecycle_permissions.json
}
