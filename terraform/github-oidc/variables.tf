variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI/CD role, as owner/name"
  type        = string
  default     = "fattswindstorm/resume-site"
}
