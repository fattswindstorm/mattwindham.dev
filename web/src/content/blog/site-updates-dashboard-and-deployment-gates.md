---
title: "Site Updates: Visitor Dashboard, Security Hardening, and Controlled Deploys"
date: 2026-06-25
description: "Adding a private visitor log dashboard, geo-blocking, security headers, a deployment approval gate, branch protection with a real review workflow, and this blog."
---

Since the [initial launch post](/blog/building-a-personal-site-on-aws), I've been iterating on the site. Here's what changed and why.

## Visitor log dashboard

The first thing I wanted was visibility into who (or what) was hitting the site. CloudFront access logs go to S3 automatically, but reading gzipped W3C-format log files from an S3 bucket isn't exactly convenient.

The solution: a small Lambda function behind `/admin` that reads the newest log files, parses the tab-separated W3C format, and renders an HTML table. HTTP Basic Auth gates access, and a shared-secret header (`X-Origin-Verify`) restricts direct access to requests coming through CloudFront — so the underlying API Gateway endpoint can't be called without the secret that only CloudFront knows.

The first thing the logs showed was a wave of automated scanners — bots from Censys, Shodan, and various credential-stuffing tools probing for `/wp-admin`, `/.env`, and other common targets. Expected, but useful to see.

## Geo-blocking the noisiest scanner regions

After seeing where most of the scan traffic originated, I added a CloudFront geo-restriction blocking CN, PK, RU, and UA. This isn't a security measure in the strong sense — a determined attacker routes around geo-blocks — but it meaningfully cuts the background noise of low-effort automated scanners without affecting any legitimate traffic to a personal portfolio site.

CloudFront geo-restriction is a single Terraform block:

```hcl
restrictions {
  geo_restriction {
    restriction_type = "blacklist"
    locations        = ["CN", "PK", "RU", "UA"]
  }
}
```

## Security headers on all responses

CloudFront's `Managed-SecurityHeadersPolicy` adds HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and `X-XSS-Protection` to responses automatically. I had it on the main site behavior from the start, but missed adding it to the `/admin` behavior when I built the dashboard. A one-line fix:

```hcl
response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
```

Worth noting: this is a good example of why reviewing the CloudFront distribution config as a whole occasionally is useful. Per-behavior settings don't inherit from the default behavior — each ordered behavior is independent.

## Deployment approval gate

The original deploy flow was: merge PR → CI applies automatically. That works fine day-to-day, but it means any merge immediately changes production, with no explicit confirmation step.

I added a GitHub Environment called `production` with myself as a required reviewer. Both the Terraform apply job and the site deploy job now specify `environment: production`. The flow is now:

1. Merge a PR to main → workflow starts
2. Reaches the `apply` or `deploy` job → **pauses**
3. GitHub sends a notification (email or mobile push)
4. Tap the link → single "Approve deployment" button
5. Deploy runs

No code to enter, no app required beyond a browser. This is close to the "approve from notification" pattern I was after. On a phone it's: notification → tap → one button → done.

The GitHub Environments feature handles all of this without any custom infrastructure — it's a repo setting and two lines of YAML. The environment also creates a proper deployment record in GitHub, so the deployments tab shows a history of every production release with who approved it and when.

## Billing alert

With a few new AWS resources added (Lambda, API Gateway, S3 logs bucket), I set up an AWS Budget to email me if monthly spend crosses $10. The site still runs at ~$0.50/month in steady state, but the budget acts as a safety net for misconfigurations that could cause unexpected spend.

The `aws_budgets_budget` Terraform resource handles this cleanly with a `notification` block — no SNS topic required for direct email alerts.

## Blog

The site now has a blog (you're reading it). Built with Astro's Content Layer API — Markdown files in `src/content/blog/`, a listing page at `/blog`, and individual post pages at `/blog/[id]`. Adding a post is dropping a `.md` file in the right directory and opening a PR. The CloudFront URL-rewriting function already handles the directory-style paths, so no infrastructure changes were needed.

## Branch protection and the review workflow

The last piece ties the deployment gate together with a proper code review step. A GitHub Rulesets rule on `main` blocks direct pushes and requires all changes to go through pull requests, with at least one approval before merge.

The intent is a real team-style workflow even on a solo project: code changes come in as PRs from a contributor (in this case, Claude Code), I review the diff and approve, the PR merges, and the deployment gate fires before anything hits production. Two distinct checkpoints — code review and deployment approval — rather than a single unreviewed push-to-deploy.

The practical setup:
- **GitHub Ruleset**: requires PRs on `main`, 1 approval to merge, no force pushes, no branch deletion
- **Bypass**: as repo owner I have `always` bypass, so I can push directly in a genuine emergency without being locked out of my own site
- **GitHub Environment**: the `apply` and `deploy` jobs pause for explicit approval before running — the "tap to deploy" step that happens after the code review

The combination means every change to production has two intentional approval moments: reviewing the code, and then separately confirming the deploy.

All source for this site is on [GitHub](https://github.com/fattswindstorm/mattwindham.dev).
