output "bucket_name" {
  description = "Name of the S3 bucket holding site content"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_domain_name" {
  description = "Default *.cloudfront.net domain serving the site"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "site_url" {
  description = "Custom domain serving the site"
  value       = "https://${var.domain_name}"
}

output "cognito_user_pool_id" {
  description = "Recruiter portal user pool ID - paste into web/src/lib/cognito-config.ts"
  value       = aws_cognito_user_pool.recruiters.id
}

output "cognito_app_client_id" {
  description = "Recruiter portal app client ID - paste into web/src/lib/cognito-config.ts"
  value       = aws_cognito_user_pool_client.portal.id
}

output "cognito_hosted_ui_domain" {
  description = "Hosted UI domain used for the Google OAuth handshake - paste into web/src/lib/cognito-config.ts"
  value       = "${aws_cognito_user_pool_domain.recruiters.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_idp_response_redirect_uri" {
  description = "Redirect URI to register in Google Cloud Console as an authorized redirect URI"
  value       = "https://${aws_cognito_user_pool_domain.recruiters.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/idpresponse"
}

output "acm_certificate_arn" {
  description = "Wildcard-SAN ACM cert ARN, consumed by terraform/eks-demo/ via remote state for the demo/argocd-demo subdomains"
  value       = aws_acm_certificate.site.arn
}
