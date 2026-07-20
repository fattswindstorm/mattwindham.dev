# ---------------------------------------------------------------
# Recruiter portal authentication (Cognito)
# ---------------------------------------------------------------
# Email/password + Google sign-in for the recruiter portal. Apple and
# Microsoft were considered and deliberately left out for now (Apple
# requires a paid developer account; Microsoft can be added later as a
# generic OIDC identity provider without touching anything below).

resource "aws_cognito_user_pool" "recruiters" {
  name = "resume-site-recruiters"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  deletion_protection      = "ACTIVE"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # schema is immutable after pool creation - AWS rejects any update to it
  # outright ("cannot modify or remove schema items"), even when the diff is
  # cosmetic (e.g. import not populating string_attribute_constraints).
  # Confirmed via `aws cognito-idp describe-user-pool` that the live email/name
  # attributes match what's declared above - not actual drift.
  lifecycle {
    ignore_changes = [schema]
  }
}

# AWS-provided Hosted UI domain - just a redirect waypoint for the Google
# OAuth handshake, not a page recruiters spend any real time on.
resource "aws_cognito_user_pool_domain" "recruiters" {
  domain       = "mattwindham-auth"
  user_pool_id = aws_cognito_user_pool.recruiters.id
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.recruiters.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_client" "portal" {
  name         = "resume-site-portal"
  user_pool_id = aws_cognito_user_pool.recruiters.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO", aws_cognito_identity_provider.google.provider_name]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = ["https://${var.domain_name}/portal/callback"]
  logout_urls   = ["https://${var.domain_name}/portal/login"]

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # generate_secret is create-time-only and Cognito's own DescribeUserPoolClient
  # doesn't return it, so terraform import can't populate it - without this,
  # Terraform treats it as unknown and force-replaces this resource on every
  # plan, which would generate a new client ID and log out every current
  # session. Confirmed via `aws cognito-idp describe-user-pool-client` that
  # the real client has no secret, matching generate_secret = false above -
  # this is a known-good value, not an actual drift.
  lifecycle {
    ignore_changes = [generate_secret]
  }
}

# Matt adds his own account to this group after registering through the
# portal like everyone else - Terraform can't pre-populate it because his
# Cognito `sub` doesn't exist until he signs up.
resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.recruiters.id
  description  = "Site owner account(s) that can read and reply to all opportunity threads"
}
