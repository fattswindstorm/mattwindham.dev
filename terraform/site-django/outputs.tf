output "staging_url" {
  description = "Staging URL for pre-cutover verification"
  value       = "https://${var.staging_subdomain}.${var.domain_name}"
}

output "alb_dns_name" {
  description = "ALB's own DNS name - what CloudFront's default behavior origin will point at in Phase 3"
  value       = aws_lb.this.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL, for the image-build CI workflow"
  value       = aws_ecr_repository.django_site.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name, for the CI deploy step"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name, for the CI deploy step"
  value       = aws_ecs_service.django.name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.this.address
}
