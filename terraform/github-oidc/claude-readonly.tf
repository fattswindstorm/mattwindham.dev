# ---------------------------------------------------------------
# claude-readonly: standing, purpose-built read-only role for account
# diagnostics (billing investigations, IAM/CloudTrail audits, etc.) -
# reuses the account's single GitHub Actions OIDC provider (defined in
# main.tf).
#
# Trust condition matches on `sub` (ref:refs/heads/main), the same pattern
# already used by github_actions_trust below, rather than job_workflow_ref
# scoped to one specific file. An earlier version tried scoping this to
# just aws-diagnostic.yml via job_workflow_ref - despite a trust policy
# that matched GitHub's documented claim format exactly, AssumeRoleWithWebIdentity
# consistently failed with "Not authorized," while the sub-based pattern
# below is proven working in this exact repo/environment. Trading some
# scoping precision (any workflow run on main can assume this, not just
# the one diagnostic workflow) for something that actually works - this
# matches the same trust posture already accepted for
# github-actions-resume-site, which has far more powerful permissions than
# this read-only role does.
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
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
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
