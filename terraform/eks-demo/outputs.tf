output "cluster_name" {
  description = "EKS cluster name, for `aws eks update-kubeconfig`"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA cert"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN to annotate the aws-load-balancer-controller service account with"
  value       = aws_iam_role.alb_controller.arn
}

output "acm_certificate_arn" {
  description = "Wildcard ACM cert ARN (passed through from terraform/site/'s remote state) for the ALB Ingress annotations"
  value       = data.terraform_remote_state.site.outputs.acm_certificate_arn
}

output "public_subnet_ids" {
  description = "Public subnet IDs (needed for the ALB Ingress subnet annotation)"
  value       = aws_subnet.public[*].id
}

output "vpc_id" {
  description = "VPC ID, passed to the AWS Load Balancer Controller Helm install"
  value       = aws_vpc.this.id
}
