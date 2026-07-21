# Deliberately narrow coupling to the persistent site stack, same pattern
# terraform/eks-demo/ already uses: read only the wildcard ACM cert ARN
# (covers "*.mattwindham.dev", see terraform/site/main.tf's SAN and
# terraform/site/outputs.tf's acm_certificate_arn output) rather than
# provisioning and DNS-validating a second cert for this stack. Nothing
# else from that state is consumed here.
data "terraform_remote_state" "site" {
  backend = "s3"

  config = {
    bucket = "resume-site-tfstate-955752000541"
    key    = "site/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_route53_zone" "primary" {
  name         = "${var.domain_name}."
  private_zone = false
}
