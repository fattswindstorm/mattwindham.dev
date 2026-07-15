variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Base domain (must match terraform/site/'s domain_name, whose ACM cert this stack consumes)"
  type        = string
  default     = "mattwindham.dev"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the eks-demo lifecycle role, as owner/name"
  type        = string
  default     = "fattswindstorm/mattwindham.dev"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-demo"
}

variable "kubernetes_version" {
  description = "EKS control plane Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired node count at cluster creation"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 2
}

variable "billing_alert_email" {
  description = "Email address to notify when the eks-demo budget threshold is crossed"
  type        = string
  default     = "windham.matt@gmail.com"
}
