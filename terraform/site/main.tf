data "aws_caller_identity" "current" {}

locals {
  bucket_name = "resume-site-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_function" "rewrite_index" {
  name    = "${local.bucket_name}-rewrite-index"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect www to apex, and append index.html for directory-style requests (Astro's directory build output)"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var host = request.headers.host.value;

      if (host.startsWith('www.')) {
        var apexHost = host.slice(4);
        var qs = '';
        for (var key in request.querystring) {
          qs += (qs === '' ? '?' : '&') + key + '=' + request.querystring[key].value;
        }
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: { value: 'https://' + apexHost + request.uri + qs }
          }
        };
      }

      var uri = request.uri;

      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }

      return request;
    }
  EOT
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

data "aws_route53_zone" "primary" {
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_acm_certificate" "site" {
  domain_name = var.domain_name
  # "*.${var.domain_name}" covers demo.${var.domain_name} and argocd-demo.${var.domain_name}
  # for the on-demand EKS/ArgoCD demo (terraform/eks-demo/), so that ephemeral
  # stack never has to issue/wait on its own ACM cert.
  subject_alternative_names = ["www.${var.domain_name}", "*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  # Keyed by the validation record's own name, not the SAN's domain_name - an
  # apex and its wildcard (e.g. mattwindham.dev and *.mattwindham.dev) get
  # issued the identical validation CNAME, so keying by domain_name creates
  # two Terraform resources fighting over one real DNS record. distinct()
  # collapses the identical apex/wildcard entries in the list before the map
  # is built - keying directly by resource_record_name would instead error
  # at plan time ("Duplicate object key"), since a single for-expression map
  # can't tolerate two source elements producing the same key.
  # trimsuffix on the map key only - resource_record_name is FQDN-form with a
  # trailing dot, but Route53's own name attribute normalizes it away, and the
  # state was moved to dot-free keys. Keeping the dot in the key here would
  # mismatch existing state and show as a spurious destroy+recreate.
  for_each = {
    for r in distinct([
      for dvo in aws_acm_certificate.site.domain_validation_options : {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    ]) : trimsuffix(r.name, ".") => r
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.site.id
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = aws_s3_bucket.site.id
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    compress                   = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
    }
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  origin {
    domain_name = trimsuffix(trimprefix(aws_apigatewayv2_api.log_viewer.api_endpoint, "https://"), "/")
    origin_id   = "log-viewer"

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_verify.result
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    path_pattern               = "/admin*"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "log-viewer"
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    compress                   = true
  }

  origin {
    domain_name = trimsuffix(trimprefix(aws_apigatewayv2_api.opportunity.api_endpoint, "https://"), "/")
    origin_id   = "opportunity"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/contact*"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "opportunity"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                 = true
  }

  origin {
    domain_name = trimsuffix(trimprefix(aws_apigatewayv2_api.correspondence.api_endpoint, "https://"), "/")
    origin_id   = "correspondence"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  ordered_cache_behavior {
    path_pattern             = "/threads*"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "correspondence"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                 = true
  }

  ordered_cache_behavior {
    path_pattern             = "/settings*"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "correspondence"
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                 = true
  }

  ordered_cache_behavior {
    path_pattern           = "/lab*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "correspondence"
    viewer_protocol_policy = "redirect-to-https"
    # Short-TTL (not Managed-CachingDisabled): GET /lab/status is public and
    # polled by the site-wide easter egg - a few seconds of cache absorbs
    # any realistic polling burst for near-zero cost. POST /lab/trigger and
    # /lab/teardown are never cached regardless (not in cached_methods).
    cache_policy_id          = aws_cloudfront_cache_policy.lab_status_short_ttl.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                 = true
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["CN", "PK", "RU", "UA"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# --- Visitor log capture ---

resource "aws_s3_bucket" "logs" {
  bucket = "resume-site-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    # CloudFront log delivery grants access via ACL, so this bucket can't
    # use BucketOwnerEnforced like the site bucket does.
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs, aws_s3_bucket_public_access_block.logs]

  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# --- Visitor log dashboard (Lambda behind /admin*) ---

data "archive_file" "log_viewer" {
  type        = "zip"
  source_file = "${path.module}/lambda/log_viewer/handler.py"
  output_path = "${path.module}/lambda/log_viewer.zip"
}

data "aws_iam_policy_document" "log_viewer_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "log_viewer" {
  name               = "resume-site-log-viewer"
  assume_role_policy = data.aws_iam_policy_document.log_viewer_trust.json
}

resource "aws_iam_role_policy_attachment" "log_viewer_basic_execution" {
  role       = aws_iam_role.log_viewer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "log_viewer_permissions" {
  statement {
    sid     = "ReadAccessLogs"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "log_viewer_permissions" {
  name   = "resume-site-log-viewer-s3-read"
  role   = aws_iam_role.log_viewer.id
  policy = data.aws_iam_policy_document.log_viewer_permissions.json
}

resource "random_password" "origin_verify" {
  length  = 32
  special = false
}

resource "aws_lambda_function" "log_viewer" {
  function_name    = "resume-site-log-viewer"
  role             = aws_iam_role.log_viewer.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  timeout          = 15
  filename         = data.archive_file.log_viewer.output_path
  source_code_hash = data.archive_file.log_viewer.output_base64sha256

  environment {
    variables = {
      LOGS_BUCKET          = aws_s3_bucket.logs.id
      LOGS_PREFIX          = "cloudfront/"
      DASHBOARD_USERNAME   = var.dashboard_username
      DASHBOARD_PASSWORD   = var.dashboard_password
      ORIGIN_VERIFY_SECRET = random_password.origin_verify.result
    }
  }
}

resource "aws_apigatewayv2_api" "log_viewer" {
  name          = "resume-site-log-viewer"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "log_viewer" {
  api_id                 = aws_apigatewayv2_api.log_viewer.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.log_viewer.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "log_viewer" {
  api_id    = aws_apigatewayv2_api.log_viewer.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.log_viewer.id}"
}

resource "aws_apigatewayv2_stage" "log_viewer" {
  api_id      = aws_apigatewayv2_api.log_viewer.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "log_viewer_apigateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_viewer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.log_viewer.execution_arn}/*/*"
}
