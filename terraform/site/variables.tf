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

variable "dashboard_username" {
  description = "Username for the private visitor-log dashboard at /admin"
  type        = string
  sensitive   = true
}

variable "dashboard_password" {
  description = "Password for the private visitor-log dashboard at /admin"
  type        = string
  sensitive   = true
}

variable "notify_email" {
  description = "Email address to notify when an opportunity form is submitted"
  type        = string
  default     = "REDACTED_EMAIL"
}

variable "google_client_id" {
  description = "OAuth 2.0 client ID for the Google identity provider (Google Cloud Console)"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "OAuth 2.0 client secret for the Google identity provider (Google Cloud Console)"
  type        = string
  sensitive   = true
}
