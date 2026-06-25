# ---------------------------------------------------------------
# Recruiter <-> Matt correspondence (in-site replies to submissions)
# ---------------------------------------------------------------

resource "aws_dynamodb_table" "messages" {
  name         = "site-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "thread_id"
  range_key    = "created_at"

  attribute {
    name = "thread_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }
}

# Lambda package
data "archive_file" "correspondence" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/correspondence"
  output_path = "${path.module}/lambda/correspondence.zip"
}

# IAM role for the Lambda
data "aws_iam_policy_document" "correspondence_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "correspondence" {
  name               = "resume-site-correspondence"
  assume_role_policy = data.aws_iam_policy_document.correspondence_trust.json
}

resource "aws_iam_role_policy_attachment" "correspondence_basic_execution" {
  role       = aws_iam_role.correspondence.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "correspondence_permissions" {
  statement {
    sid    = "ReadOpportunities"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.opportunities.arn,
      "${aws_dynamodb_table.opportunities.arn}/index/*",
    ]
  }

  statement {
    sid       = "MessagesReadWrite"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.messages.arn]
  }

  statement {
    sid       = "SESSend"
    effect    = "Allow"
    actions   = ["ses:SendEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "correspondence_permissions" {
  name   = "resume-site-correspondence"
  role   = aws_iam_role.correspondence.id
  policy = data.aws_iam_policy_document.correspondence_permissions.json
}

# Lambda function
resource "aws_lambda_function" "correspondence" {
  function_name    = "resume-site-correspondence"
  role             = aws_iam_role.correspondence.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.correspondence.output_path
  source_code_hash = data.archive_file.correspondence.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      OPPORTUNITIES_TABLE = aws_dynamodb_table.opportunities.name
      MESSAGES_TABLE      = aws_dynamodb_table.messages.name
      FROM_EMAIL          = "opportunity@${var.domain_name}"
      SITE_URL            = "https://${var.domain_name}"
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "correspondence" {
  name          = "resume-site-correspondence"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${var.domain_name}"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_authorizer" "correspondence_jwt" {
  api_id           = aws_apigatewayv2_api.correspondence.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "resume-site-cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.portal.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.recruiters.id}"
  }
}

resource "aws_apigatewayv2_integration" "correspondence" {
  api_id                 = aws_apigatewayv2_api.correspondence.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.correspondence.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "threads_list" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "GET /threads"
  target             = "integrations/${aws_apigatewayv2_integration.correspondence.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_route" "thread_detail" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "GET /threads/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.correspondence.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_route" "thread_reply" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "POST /threads/{id}/messages"
  target             = "integrations/${aws_apigatewayv2_integration.correspondence.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_stage" "correspondence" {
  api_id      = aws_apigatewayv2_api.correspondence.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "correspondence_apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.correspondence.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.correspondence.execution_arn}/*/*"
}
