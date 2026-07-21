# Generated once and stored in Secrets Manager - never passes through CI
# logs or a GitHub secret, unlike the Google OAuth credentials (which
# already exist as repo secrets and are just reused here).
resource "random_password" "django_secret_key" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret" "django_secret_key" {
  name = "site-django/secret-key"
}

resource "aws_secretsmanager_secret_version" "django_secret_key" {
  secret_id     = aws_secretsmanager_secret.django_secret_key.id
  secret_string = random_password.django_secret_key.result
}

# Google OAuth credentials themselves are passed in as sensitive Terraform
# variables (same values already used by terraform/site's Cognito setup,
# via the existing GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET repo secrets) -
# stored here in Secrets Manager so the ECS task definition's `secrets`
# block can reference them, rather than plaintext environment variables.
resource "aws_secretsmanager_secret" "google_client_id" {
  name = "site-django/google-client-id"
}

resource "aws_secretsmanager_secret_version" "google_client_id" {
  secret_id     = aws_secretsmanager_secret.google_client_id.id
  secret_string = var.google_client_id
}

resource "aws_secretsmanager_secret" "google_client_secret" {
  name = "site-django/google-client-secret"
}

resource "aws_secretsmanager_secret_version" "google_client_secret" {
  secret_id     = aws_secretsmanager_secret.google_client_secret.id
  secret_string = var.google_client_secret
}
