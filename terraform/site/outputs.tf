output "bucket_name" {
  description = "Name of the S3 bucket holding site content"
  value       = aws_s3_bucket.site.id
}

output "cloudfront_domain_name" {
  description = "Default *.cloudfront.net domain serving the site"
  value       = aws_cloudfront_distribution.site.domain_name
}
