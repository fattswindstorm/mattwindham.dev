# ---------------------------------------------------------------
# TEMPORARY - added 2026-07-17 to investigate a reported $31M AWS bill.
# Strictly read-only (no Put/Create/Delete/Update anywhere) so it's safe to
# add even mid-incident. Remove once the investigation is closed.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "incident_diagnostic" {
  statement {
    sid    = "CostExplorerReadOnly"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostAndUsageWithResources",
      "ce:GetCostForecast",
      "ce:GetDimensionValues",
      "ce:GetTags",
      "ce:GetAnomalies",
      "ce:GetAnomalyMonitors",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IamAuditReadOnly"
    effect = "Allow"
    actions = [
      "iam:ListUsers",
      "iam:ListAccessKeys",
      "iam:ListRoles",
      "iam:GetAccountSummary",
      "iam:ListAttachedUserPolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListMFADevices",
      "iam:GetAccessKeyLastUsed",
      "iam:GenerateCredentialReport",
      "iam:GetCredentialReport",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3AccountWideReadOnly"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketAcl",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchMetricsReadOnly"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudTrailReadOnly"
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BudgetsReadOnly"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudgetAction",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "incident_diagnostic" {
  name   = "resume-site-incident-diagnostic-TEMP"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.incident_diagnostic.json
}
