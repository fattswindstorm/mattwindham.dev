variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the eks-demo lifecycle role, as owner/name"
  type        = string
  default     = "fattswindstorm/mattwindham.dev"
}

variable "cluster_name" {
  description = "EKS cluster name (must match terraform/eks-demo's cluster_name - used to scope this role's EKS/IAM resource ARNs)"
  type        = string
  default     = "eks-demo"
}

variable "billing_alert_email" {
  description = "Email address to notify when the eks-demo budget threshold is crossed"
  type        = string
}
