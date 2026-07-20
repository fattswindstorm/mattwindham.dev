# Deliberately narrow coupling to the persistent site stack: read only the
# wildcard ACM cert ARN (see terraform/site/main.tf's SAN for "*.${domain_name}"
# and terraform/site/outputs.tf's acm_certificate_arn output). Nothing else
# from that state is consumed here.
data "terraform_remote_state" "site" {
  backend = "s3"

  config = {
    bucket = "resume-site-tfstate-955752000541"
    key    = "site/terraform.tfstate"
    region = "us-east-1"
  }
}

# Reuses the account's single GitHub Actions OIDC provider (created once in
# terraform/github-oidc/main.tf) rather than creating a second one.
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}
