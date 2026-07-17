# ---------------------------------------------------------------
# claude-readonly: standing, purpose-built read-only role for account
# diagnostics (billing investigations, IAM/CloudTrail audits, etc.) -
# reuses the account's single GitHub Actions OIDC provider (defined in
# main.tf), scoped via job_workflow_ref to just the diagnostic workflow
# below so nothing else in this repo can assume it.
# ---------------------------------------------------------------

data "aws_iam_policy_document" "claude_readonly_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:job_workflow_ref"
      values = [
        "${var.github_repo}/.github/workflows/aws-diagnostic.yml@refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "claude_readonly" {
  name               = "claude-readonly"
  assume_role_policy = data.aws_iam_policy_document.claude_readonly_trust.json
}

# AWS-managed ReadOnlyAccess rather than a hand-scoped policy - this role
# is isolated to diagnostics only (can't deploy or modify anything), so the
# broad-but-still-read-only scope is appropriate here and avoids repeating
# today's AccessDenied-whack-a-mole the next time an investigation needs a
# permission nobody anticipated.
resource "aws_iam_role_policy_attachment" "claude_readonly" {
  role       = aws_iam_role.claude_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
