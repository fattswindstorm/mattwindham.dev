---
title: "Building a Personal Site on AWS for $0.50/month"
date: 2026-06-01
description: "How I built a fully automated, secure portfolio site on AWS using Terraform, CloudFront, and GitHub Actions OIDC — with no stored credentials and nearly zero ongoing cost."
---

Most personal sites either cost too much or cut too many corners on security. I wanted mine to be the opposite: production-grade infrastructure, but almost free to run. Here's how it works.

## The stack

- **Astro** — static site generator. Zero JavaScript by default, fast builds, great for content-heavy pages.
- **S3** — private bucket, no public access. The only way to read objects is through CloudFront.
- **CloudFront** — serves the site, handles HTTPS, enforces security headers, rewrites directory-style URLs to `index.html`.
- **Terraform** — every AWS resource is code. Nothing was clicked in the console.
- **GitHub Actions + OIDC** — deployments happen automatically on merge. No stored access keys anywhere.

## Why OIDC instead of access keys

The standard approach for CI/CD is to create an IAM user, generate an access key, and paste it into GitHub Secrets. The problem: that key is long-lived, broadly scoped, and one leaked secret away from a bad day.

OIDC federation works differently. GitHub Actions requests a short-lived token from AWS at the start of each workflow run, proves which repo it's coming from, and AWS hands back temporary credentials scoped to exactly the role you specify. No secret to leak, no rotation dance, no "oops I committed my `.env` file" scenarios.

The Terraform for the trust relationship is about 30 lines and lives in a separate stage (`terraform/github-oidc/`) that's explicitly excluded from the automated pipeline — so the CI role can never widen its own permissions.

## Keeping the S3 bucket private

CloudFront uses an **Origin Access Control** to authenticate requests to S3. The bucket policy only allows reads where the `AWS:SourceArn` matches this specific distribution's ARN — not just any CloudFront distribution, but this one exactly.

All four S3 Block Public Access settings are enabled. `BucketOwnerEnforced` ownership means no ACLs can grant public access even by accident.

## CloudFront function for URL rewriting

Astro's directory build output generates `about/index.html` instead of `about.html`. CloudFront doesn't automatically append `index.html` to paths the way S3 static website hosting does — that feature only works with public S3 hosting, which defeats the whole private-bucket approach.

The fix is a CloudFront Function (runs at the edge, sub-millisecond, included in the CloudFront free tier) that rewrites incoming URIs:

```js
if (uri.endsWith('/')) {
  request.uri += 'index.html';
} else if (!uri.includes('.')) {
  request.uri += '/index.html';
}
```

The same function also handles `www` → apex redirects with a 301 before the rewrite logic runs.

## Security headers

CloudFront's `Managed-SecurityHeadersPolicy` adds HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and `X-XSS-Protection` to every response automatically. No Lambda@Edge, no custom code — one ID in the Terraform resource.

## Cost

At normal traffic levels, the cost breakdown is:

| Resource | Cost |
|---|---|
| CloudFront | $0 (free tier) |
| S3 | $0 (free tier) |
| Lambda | $0 (free tier) |
| Route 53 hosted zone | $0.50/month |
| Domain registration | ~$17/year |

The only thing that would push this above a dollar is a traffic spike large enough to exceed CloudFront's 1TB/month free tier, which would take a genuinely viral post or a serious bot problem. Geo-blocking the noisiest scanner regions keeps that under control.

## What I'd do differently

The one manual step in the whole setup was domain registration — Amazon Registrar doesn't have a Terraform provider, so the initial registration was a console click. Everything downstream (ACM cert, DNS validation records, Route 53 alias records, CloudFront distribution) is fully Terraform-managed and reproducible.

If I were starting fresh, I'd evaluate whether Cloudflare's free tier is worth the DNS migration for the additional WAF and bot protection. At this traffic level it's hard to justify the complexity, but it's a straightforward tradeoff.

The full source is on [GitHub](https://github.com/fattswindstorm/mattwindham.dev).
