# ---------------------------------------------------------------
# Opportunity contact form backend
# ---------------------------------------------------------------

# DynamoDB table for submitted opportunities
resource "aws_dynamodb_table" "opportunities" {
  name         = "site-opportunities"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "owner_sub"
    type = "S"
  }

  # Lets a logged-in recruiter query "my submissions" by their Cognito sub
  # instead of scanning the whole table.
  global_secondary_index {
    name            = "owner_sub-index"
    hash_key        = "owner_sub"
    projection_type = "ALL"
  }
}

# SES domain verification
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "ses_verification" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Lambda package
data "archive_file" "opportunity" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/opportunity"
  output_path = "${path.module}/lambda/opportunity.zip"
}

# IAM role for the Lambda
data "aws_iam_policy_document" "opportunity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "opportunity" {
  name               = "resume-site-opportunity"
  assume_role_policy = data.aws_iam_policy_document.opportunity_trust.json
}

resource "aws_iam_role_policy_attachment" "opportunity_basic_execution" {
  role       = aws_iam_role.opportunity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "opportunity_permissions" {
  statement {
    sid       = "DynamoWrite"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan"]
    resources = [aws_dynamodb_table.opportunities.arn]
  }

  statement {
    sid       = "SESSend"
    effect    = "Allow"
    actions   = ["ses:SendEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "opportunity_permissions" {
  name   = "resume-site-opportunity"
  role   = aws_iam_role.opportunity.id
  policy = data.aws_iam_policy_document.opportunity_permissions.json
}

# Lambda function
resource "aws_lambda_function" "opportunity" {
  function_name    = "resume-site-opportunity"
  role             = aws_iam_role.opportunity.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.opportunity.output_path
  source_code_hash = data.archive_file.opportunity.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      OPPORTUNITIES_TABLE = aws_dynamodb_table.opportunities.name
      NOTIFY_EMAIL        = var.notify_email
      FROM_EMAIL          = "opportunity@${var.domain_name}"
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "opportunity" {
  name          = "resume-site-opportunity"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${var.domain_name}"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "opportunity" {
  api_id                 = aws_apigatewayv2_api.opportunity.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.opportunity.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "opportunity_jwt" {
  api_id           = aws_apigatewayv2_api.opportunity.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "resume-site-cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.portal.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.recruiters.id}"
  }
}

resource "aws_apigatewayv2_route" "opportunity_post" {
  api_id             = aws_apigatewayv2_api.opportunity.id
  route_key          = "POST /contact"
  target             = "integrations/${aws_apigatewayv2_integration.opportunity.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.opportunity_jwt.id
}

resource "aws_apigatewayv2_route" "opportunity_options" {
  api_id    = aws_apigatewayv2_api.opportunity.id
  route_key = "OPTIONS /contact"
  target    = "integrations/${aws_apigatewayv2_integration.opportunity.id}"
}

resource "aws_apigatewayv2_stage" "opportunity" {
  api_id      = aws_apigatewayv2_api.opportunity.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "opportunity_apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opportunity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.opportunity.execution_arn}/*/*"
}
