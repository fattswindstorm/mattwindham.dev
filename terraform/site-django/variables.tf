variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Base domain (must match terraform/site/'s domain_name, whose wildcard ACM cert this stack consumes)"
  type        = string
  default     = "mattwindham.dev"
}

variable "staging_subdomain" {
  description = "Subdomain pointed directly at the ALB for pre-cutover verification (Phase 1/2) - independent of the apex/www records CloudFront still owns until Phase 3"
  type        = string
  default     = "django-staging"
}

variable "db_name" {
  description = "Postgres database name"
  type        = string
  default     = "mattwindham"
}

variable "db_username" {
  description = "Postgres master username"
  type        = string
  default     = "mattwindham"
}

variable "google_client_id" {
  description = "OAuth 2.0 client ID for the Google identity provider - same value already used by terraform/site's Cognito setup"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "OAuth 2.0 client secret for the Google identity provider - same value already used by terraform/site's Cognito setup"
  type        = string
  sensitive   = true
}

variable "notify_email" {
  description = "Email address for Django's DEFAULT_FROM_EMAIL / opportunity notifications"
  type        = string
}
