terraform {
  backend "s3" {
    bucket       = "resume-site-tfstate-ACCOUNT_ID_REDACTED"
    key          = "site/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
