---
title: "Site Updates: Visitor Dashboard, Security Hardening, and One-Tap Deploys"
date: 2026-06-25
description: "How I added a private visitor log dashboard, tightened security with geo-blocking and CloudFront headers, and set up a deployment approval gate I can trigger from my phone."
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

## Branch protection

The last piece: a GitHub Rulesets rule on `main` that requires all changes to go through pull requests. Direct pushes to main are blocked. This isn't strictly necessary on a solo project, but it means every change has a CI check (Terraform plan or site build) as part of the record, and the deployment approval gate always fires.

All source for this site is on [GitHub](https://github.com/fattswindstorm/mattwindham.dev).
