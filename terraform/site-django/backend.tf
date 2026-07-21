terraform {
  backend "s3" {
    bucket       = "resume-site-tfstate-955752000541"
    key          = "site-django/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
