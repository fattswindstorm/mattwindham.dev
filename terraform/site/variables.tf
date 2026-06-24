variable "aws_region" {
  description = "AWS region for the site resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Custom domain for the site (must already have a Route 53 hosted zone)"
  type        = string
  default     = "mattwindham.dev"
}
