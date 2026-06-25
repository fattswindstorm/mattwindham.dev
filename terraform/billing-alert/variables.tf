variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "monthly_budget_limit" {
  description = "Monthly account cost (USD) that triggers the billing alert"
  type        = number
  default     = 10
}

variable "billing_alert_email" {
  description = "Email address to notify when the budget threshold is crossed"
  type        = string
  default     = "REDACTED_EMAIL"
}
