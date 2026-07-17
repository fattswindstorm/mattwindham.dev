# ---------------------------------------------------------------
# terraform-deployer: replaces the old static-key IAM user of the same
# name. Applies the account-level stacks that don't and shouldn't
# auto-apply via CI (bootstrap/, github-oidc/, billing-alert/) - in
# particular, github-oidc/ defines this account's own IAM roles/policies,
# so letting a CI-assumable role self-apply it would be a privilege
# escalation path. That boundary stays a human, on purpose.
#
# Trust: assumable by any already-authenticated principal in this same
# account (root, an IAM user, or a federated/SSO session), gated by MFA.
# This avoids hardcoding a specific SSO permission-set role ARN, which can
# change if the permission set is ever recreated.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "terraform_deployer_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::ACCOUNT_ID_REDACTED:root"]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "terraform_deployer" {
  name                 = "terraform-deployer"
  assume_role_policy   = data.aws_iam_policy_document.terraform_deployer_trust.json
  max_session_duration = 3600
}

# This role's entire purpose is bootstrapping/managing this account's IAM
# roles and policies, so a broad IAM grant is the role's actual job, not
# scope creep - trying to hand-scope "every IAM action needed to create
# arbitrary future roles as this account's infra evolves" would just mean
# re-editing this file every time a new Lambda/service role is added
# elsewhere, defeating the point of a stable bootstrapping identity.
resource "aws_iam_role_policy_attachment" "terraform_deployer_iam" {
  role       = aws_iam_role.terraform_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

# Needed for terraform/bootstrap/ (the tfstate bucket itself) and general
# state bucket management.
resource "aws_iam_role_policy_attachment" "terraform_deployer_s3" {
  role       = aws_iam_role.terraform_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Needed for terraform/billing-alert/.
data "aws_iam_policy_document" "terraform_deployer_billing" {
  statement {
    sid    = "BudgetsAndCostAllocationTags"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:ModifyBudget",
      "ce:CreateCostAllocationTag",
      "ce:UpdateCostAllocationTagsStatus",
      "ce:ListCostAllocationTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_deployer_billing" {
  name   = "terraform-deployer-billing"
  role   = aws_iam_role.terraform_deployer.id
  policy = data.aws_iam_policy_document.terraform_deployer_billing.json
}
