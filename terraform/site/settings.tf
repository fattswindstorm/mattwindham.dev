# ---------------------------------------------------------------
# Account settings (email preferences + account deletion)
# Routes live on the correspondence API to share its JWT authorizer.
# ---------------------------------------------------------------

resource "aws_dynamodb_table" "user_settings" {
  name         = "site-user-settings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sub"

  attribute {
    name = "sub"
    type = "S"
  }
}

# Lambda package
data "archive_file" "settings" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/settings"
  output_path = "${path.module}/lambda/settings.zip"
}

# IAM
data "aws_iam_policy_document" "settings_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "settings" {
  name               = "resume-site-settings"
  assume_role_policy = data.aws_iam_policy_document.settings_trust.json
}

resource "aws_iam_role_policy_attachment" "settings_basic_execution" {
  role       = aws_iam_role.settings.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "settings_permissions" {
  statement {
    sid    = "UserSettingsReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.user_settings.arn]
  }

  statement {
    sid    = "OpportunitiesDeleteScan"
    effect = "Allow"
    actions = [
      "dynamodb:Query",
      "dynamodb:DeleteItem",
    ]
    resources = [
      aws_dynamodb_table.opportunities.arn,
      "${aws_dynamodb_table.opportunities.arn}/index/*",
    ]
  }

  statement {
    sid    = "MessagesDelete"
    effect = "Allow"
    actions = [
      "dynamodb:Query",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.messages.arn]
  }

  statement {
    sid       = "CognitoDeleteUser"
    effect    = "Allow"
    actions   = ["cognito-idp:AdminDeleteUser"]
    resources = [aws_cognito_user_pool.recruiters.arn]
  }
}

resource "aws_iam_role_policy" "settings_permissions" {
  name   = "resume-site-settings"
  role   = aws_iam_role.settings.id
  policy = data.aws_iam_policy_document.settings_permissions.json
}

# Lambda function
resource "aws_lambda_function" "settings" {
  function_name    = "resume-site-settings"
  role             = aws_iam_role.settings.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.settings.output_path
  source_code_hash = data.archive_file.settings.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      USER_SETTINGS_TABLE = aws_dynamodb_table.user_settings.name
      OPPORTUNITIES_TABLE = aws_dynamodb_table.opportunities.name
      MESSAGES_TABLE      = aws_dynamodb_table.messages.name
      USER_POOL_ID        = aws_cognito_user_pool.recruiters.id
    }
  }
}

# Plug settings Lambda into the correspondence API (shares JWT authorizer)
resource "aws_apigatewayv2_integration" "settings" {
  api_id                 = aws_apigatewayv2_api.correspondence.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.settings.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "settings_get" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "GET /settings"
  target             = "integrations/${aws_apigatewayv2_integration.settings.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_route" "settings_put" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "PUT /settings"
  target             = "integrations/${aws_apigatewayv2_integration.settings.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_apigatewayv2_route" "account_delete" {
  api_id             = aws_apigatewayv2_api.correspondence.id
  route_key          = "DELETE /settings/account"
  target             = "integrations/${aws_apigatewayv2_integration.settings.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.correspondence_jwt.id
}

resource "aws_lambda_permission" "settings_apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.settings.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.correspondence.execution_arn}/*/*"
}
