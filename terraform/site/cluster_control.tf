# ---------------------------------------------------------------
# Admin trigger + public status endpoint for the on-demand EKS/ArgoCD demo.
# Routes live on the correspondence API to share its JWT authorizer (same
# pattern as settings.tf), except GET /lab/status which is deliberately
# unauthenticated - it's what the site-wide easter egg polls.
# ---------------------------------------------------------------

resource "aws_dynamodb_table" "eks_demo_status" {
  name         = "site-eks-demo-status"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# GitHub PAT used to dispatch the spin-up/teardown workflows. Fine-grained,
# scoped to "Actions: Read and write" on this one repo only. Fine-grained
# PATs cap at 1-year expiry - this needs manual rotation roughly yearly.
resource "aws_secretsmanager_secret" "github_dispatch_token" {
  name = "resume-site/github-dispatch-token"
}

resource "aws_secretsmanager_secret_version" "github_dispatch_token" {
  secret_id     = aws_secretsmanager_secret.github_dispatch_token.id
  secret_string = var.github_dispatch_token
}

# Lambda package
data "archive_file" "cluster_control" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cluster_control"
  output_path = "${path.module}/lambda/cluster_control.zip"
}

# IAM
data "aws_iam_policy_document" "cluster_control_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_control" {
  name               = "resume-site-cluster-control"
  assume_role_policy = data.aws_iam_policy_document.cluster_control_trust.json
}

resource "aws_iam_role_policy_attachment" "cluster_control_basic_execution" {
  role       = aws_iam_role.cluster_control.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "cluster_control_permissions" {
  statement {
    sid    = "StatusTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.eks_demo_status.arn]
  }

  statement {
    sid       = "GithubDispatchTokenRead"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.github_dispatch_token.arn]
  }
}

resource "aws_iam_role_policy" "cluster_control_permissions" {
  name   = "resume-site-cluster-control"
  role   = aws_iam_role.cluster_control.id
  policy = data.aws_iam_policy_document.cluster_control_permissions.json
}

# Lambda function
resource "aws_lambda_function" "cluster_control" {
  function_name    = "resume-site-cluster-control"
  role             = aws_iam_role.cluster_control.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.cluster_control.output_path
  source_code_hash = data.archive_file.cluster_control.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      STATUS_TABLE            = aws_dynamodb_table.eks_demo_status.name
      GITHUB_TOKEN_SECRET_ARN = aws_secretsmanager_secret.github_dispatch_token.arn
      GITHUB_REPO             = var.github_repo
    }
  }
}

resource "aws_lambda_permission" "cluster_control_apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cluster_control.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.correspondence.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "cluster_control" {
  api_id                 = aws_apigatewayv2_api.correspondence.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.cluster_control.invoke_arn
  payload_format_version = "2.0"
}

# Deliberately no authorization_type/authorizer_id - public, read-only,
# non-sensitive by construction (see handler.py's _get_status).
resource "aws_apigatewayv2_route" "lab_status" {
  api_id    = aws_apigatewayv2_api.correspondence.id
  route_key = "GET /lab/status"
  target    = "integrations/${aws_apigatewayv2_integration.cluster_control.id}"
}

resource "aws_apigatewayv2_route" "lab_trigger" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "POST /lab/trigger"
  target             = "integrations/${aws_apigatewayv2_integration.cluster_control.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_route" "lab_teardown" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "POST /lab/teardown"
  target             = "integrations/${aws_apigatewayv2_integration.cluster_control.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

# Short-TTL cache for the public status poll - cheap absorption of any
# realistic burst of anonymous polling (the easter egg + admin page both
# poll this) without needing auth or WAF on a route that must stay public.
# POST /lab/trigger and /lab/teardown are never cached regardless (only
# GET/HEAD are ever in a behavior's cached_methods).
resource "aws_cloudfront_cache_policy" "lab_status_short_ttl" {
  name        = "${local.bucket_name}-lab-status-short-ttl"
  min_ttl     = 0
  default_ttl = 10
  max_ttl     = 15

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}
