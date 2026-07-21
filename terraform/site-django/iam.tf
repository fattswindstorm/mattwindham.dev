data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------
# Task execution role - what ECS itself uses to pull the image, write
# logs, and resolve the `secrets` block's Secrets Manager references
# before the container even starts. Distinct from the task role below,
# which is what the running application code can do.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_execution_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "site-django-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_trust.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    sid    = "ReadTaskSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.django_secret_key.arn,
      aws_secretsmanager_secret.google_client_id.arn,
      aws_secretsmanager_secret.google_client_secret.arn,
      aws_db_instance.this.master_user_secret[0].secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "read-task-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

# ---------------------------------------------------------------
# Task role - the running Django app's own runtime permissions. Only SES
# send access today (django-ses uses the task's credentials via boto3,
# not static keys), mirroring what the old Lambda functions had.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "site-django-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_trust.json
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    sid    = "SesSend"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name   = "site-django-task"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_permissions.json
}
