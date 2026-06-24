# mattwindham.dev

Personal resume / portfolio site, built as a hands-on AWS + DevOps skills showcase.
Infrastructure is 100% Terraform, deployed via GitHub Actions, kept as close to
**$0/month** as possible.

**Live**: https://mattwindham.dev/

## Architecture

```
GitHub Actions (OIDC) --apply--> Terraform --manages--> S3 (private)
                                                              |
                                                   Origin Access Control
                                                              |
                                                              v
                            mattwindham.dev <--HTTPS (ACM cert)-- CloudFront
                                 (Route 53)
```

Three independent Terraform stages, each with its own state:

| Stage | What it does | State |
|---|---|---|
| `terraform/bootstrap/` | Creates the S3 bucket that holds remote Terraform state | local (one-time - can't store the state bucket's own creation inside itself) |
| `terraform/site/` | Private S3 bucket + CloudFront distribution serving the site | remote, S3 native locking |
| `terraform/github-oidc/` | OIDC trust + IAM role so GitHub Actions can deploy without stored credentials | remote, S3 native locking |

## Why this is secure

**No long-lived credentials anywhere.**
- GitHub Actions authenticates to AWS via OIDC federation, requesting a short-lived token at workflow run time instead of using a stored access key. There's no AWS secret sitting in GitHub that could leak.
- Local development pulls AWS credentials on demand from 1Password through a `credential_process` script - fetched fresh per command, never written to disk in plaintext.

**Least privilege, not admin.**
- The GitHub Actions IAM role is scoped to exactly the two S3 buckets this project owns (by ARN) plus a fixed list of CloudFront actions - not `AdministratorAccess`. A compromised or accidentally-approved workflow run still can't touch anything outside this project.
- That role's own trust policy and permissions (`terraform/github-oidc/`) are deliberately excluded from the pipeline it powers, so automation can never widen its own access.

**Private origin, no public bucket.**
- The site bucket has all four S3 Block Public Access settings on and `BucketOwnerEnforced` ownership - no ACLs, no bucket-level public policy.
- The only way to read its objects is through CloudFront's Origin Access Control, and the bucket policy further restricts that to requests carrying *this specific distribution's* ARN, not just any CloudFront distribution.
- All viewer traffic is forced to HTTPS.

**State integrity.**
- Terraform state lives in a versioned, encrypted S3 bucket with `prevent_destroy` set, so a bad `terraform destroy` can't take the state bucket down with it.
- Locking uses Terraform's native S3 lockfile (Terraform >= 1.11) - no separate DynamoDB table to provision or pay for.
- Each stage keeps its own state file, so a mistake in one stage can't corrupt another's.

**Review before changes ship.**
- Every pull request touching `terraform/site/` runs `fmt` / `validate` / `plan` in CI and posts the plan as a PR comment, so the exact AWS diff is visible before anything merges.
- Only a merge to `main` triggers `apply` - there's no path to changing live infrastructure without that diff being reviewed first.

## Cost

S3 + CloudFront fit inside the free tier at this traffic level. The only real cost is
the domain itself: `mattwindham.dev` (~$17/yr) plus a Route 53 hosted zone
(~$0.50/mo). Domain registration was the one step done manually rather than through
Terraform - everything downstream of it (the ACM cert, DNS validation records, and
CloudFront alias) is fully Terraform-managed.
