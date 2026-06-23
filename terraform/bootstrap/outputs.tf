output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state for the site stage"
  value       = aws_s3_bucket.tfstate.id
}
