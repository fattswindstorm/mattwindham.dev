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
