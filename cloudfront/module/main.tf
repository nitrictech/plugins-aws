
locals {
  s3_origin_id = "publicOrigin"

  # Collect all origin paths into a flat list
  origin_paths = flatten([
    for origin_name, origin in var.suga.origins : [
      for route in origin.routes : {
        origin_name = origin_name
        path        = route.path
        base_path   = route.base_path
        type        = origin.type
        domain_name = origin.domain_name
        id          = origin.id
        resources   = origin.resources
      }
    ]
  ])

  # Find default origin (path == "/")
  default_origin = {
    for entry in local.origin_paths : entry.origin_name => entry
    if entry.path == "/"
  }

  s3_bucket_origins = {
    for k, v in var.suga.origins : k => v
    if contains(keys(v.resources), "aws_s3_bucket")
  }
  lambda_origins = {
    for k, v in var.suga.origins : k => v
    if contains(keys(v.resources), "aws_lambda_function")
  }
  non_vpc_origins = {
    for k, v in var.suga.origins : k => v
    if !contains(keys(v.resources), "aws_lb")
  }
  vpc_origins = {
    for k, v in var.suga.origins : k => v
    if contains(keys(v.resources), "aws_lb")
  }

  # Create cache behaviors for non-root paths
  non_root_origin_paths = {
    for i, entry in local.origin_paths : "${entry.origin_name}-${i}" => entry
    if entry.path != "/"
  }

  # Group paths by origin for the CloudFront function
  all_paths = [for entry in local.origin_paths : entry.path]
}

resource "aws_cloudfront_vpc_origin" "vpc_origin" {
  for_each = local.vpc_origins

  vpc_origin_endpoint_config {
    name = each.key
    arn  = each.value.resources["aws_lb"]
    # Use standard HTTP port for shared listener
    http_port = 80
    # Doesn't matter what we set this to, it's not used
    # But 0 is not a legal value
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}



resource "aws_cloudfront_origin_access_control" "lambda_oac" {
  count = length(local.lambda_origins) > 0 ? 1 : 0

  name                              = "${var.suga.stack_id}-lambda-oac"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  count = length(local.s3_bucket_origins) > 0 ? 1 : 0

  name                              = "${var.suga.stack_id}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Allow cloudfront to execute the function urls of any provided AWS lambda functions
resource "aws_lambda_permission" "allow_cloudfront_to_execute_lambda" {
  for_each = local.lambda_origins

  function_name = each.value.resources["aws_lambda_function"]
  principal     = "cloudfront.amazonaws.com"
  action        = "lambda:InvokeFunctionUrl"
  source_arn    = aws_cloudfront_distribution.distribution.arn
}

resource "aws_s3_bucket_policy" "allow_bucket_access" {
  for_each = local.s3_bucket_origins

  bucket = replace(each.value.id, "arn:aws:s3:::", "")

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${each.value.id}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_function" "api-url-rewrite-function" {
  name    = "${var.suga.stack_id}-api-url-rewrite-function"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrite API URLs routed to Suga services"
  publish = true
  code = templatefile("${path.module}/scripts/url-rewrite.js", {
    base_paths = join(",", local.all_paths)
  })
}

# Lambda@Edge function for auth preservation and webhook signing
resource "aws_iam_role" "lambda_edge_origin_request" {
  count = length(local.lambda_origins) > 0 ? 1 : 0
  name  = "${var.suga.stack_id}-lambda-edge-origin-request-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_origin_request_basic" {
  count      = length(local.lambda_origins) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_edge_origin_request[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "origin_request_lambda" {
  count       = length(local.lambda_origins) > 0 ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda-origin-request.zip"

  source {
    content  = file("${path.module}/scripts/origin-request.js")
    filename = "index.js"
  }
}

resource "aws_lambda_function" "origin_request" {
  count            = length(local.lambda_origins) > 0 ? 1 : 0
  region           = "us-east-1"
  filename         = data.archive_file.origin_request_lambda[0].output_path
  function_name    = "${var.suga.stack_id}-cloudfront-origin-request"
  role             = aws_iam_role.lambda_edge_origin_request[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.origin_request_lambda[0].output_base64sha256
  runtime          = "nodejs22.x"
  timeout          = 5
  memory_size      = 128
  publish          = true

  timeouts {
    delete = "20m"
  }
}

resource "aws_lambda_permission" "allow_cloudfront_origin_request" {
  count         = length(local.lambda_origins) > 0 ? 1 : 0
  region        = "us-east-1"
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:GetFunction"
  function_name = aws_lambda_function.origin_request[0].function_name
  principal     = "edgelambda.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.distribution.arn
}

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  count = var.waf_enabled ? 1 : 0

  name   = "${var.suga.name}-cloudfront-waf"
  scope  = "CLOUDFRONT"
  region = "us-east-1"

  default_action {
    allow {}
  }

  # Rate limiting rule for DDoS protection
  dynamic "rule" {
    for_each = var.rate_limit_enabled ? [1] : []

    content {
      name     = "RateLimitRule"
      priority = 1

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_requests_per_5min
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "RateLimitRule"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.waf_managed_rules

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "rule_action_override" {
            for_each = rule.value.rule_action_overrides
            content {
              name = rule_action_override.key
              action_to_use {
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [1] : []
                  content {}
                }
                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [1] : []
                  content {}
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.suga.name}-cloudfront-waf"
    sampled_requests_enabled   = true
  }
}

# Determine the hosted zone domain based on whether custom_domain is root
locals {
  domain_parts = try(split(".", var.custom_domain), null)
  # If custom_domain_is_root is true, use the domain itself; otherwise extract parent domain
  hosted_zone_domain = try(var.custom_domain_is_root ? var.custom_domain : join(".", slice(local.domain_parts, 1, length(local.domain_parts))), null)
}

# Lookup the hosted zone
data "aws_route53_zone" "parent" {
  count = var.custom_domain != null ? 1 : 0
  name  = "${local.hosted_zone_domain}."
}

# Create Route53 A record for the custom domain
resource "aws_route53_record" "cloudfront_alias" {
  count   = var.custom_domain != null ? 1 : 0
  zone_id = data.aws_route53_zone.parent[0].zone_id
  name    = var.custom_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# Request ACM certificate for custom domain
resource "aws_acm_certificate" "cloudfront_cert" {
  count             = var.custom_domain != null ? 1 : 0
  region            = "us-east-1" # CloudFront requires certificates in us-east-1
  domain_name       = var.custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_cache_policy" "default_cache_policy" {
  count   = var.default_cache_policy_id == null ? 1 : 0
  name    = "SugaDefaultCachePolicy"
  comment = "Default cache policy for CloudFront distribution for Suga Applications"

  # Set TTL defaults to respect cache control headers
  default_ttl = 0
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      # Cache reasonable headers (with the exception of the Host header as serverless platforms we use do not support it)
      headers {
        items = [
          # We don't need this to forward the auth header, but we'll include it
          # in the cache key to prevent leaking cached data between users where auth headers are present
          # This is to guard against where cache-control headers are not set correctly by the origin
          "Authorization",
          "x-method-override",
          "origin",
          "x-http-method",
          "x-http-method-override"
        ]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

locals {
  default_cache_policy_id = var.default_cache_policy_id != null ? var.default_cache_policy_id : aws_cloudfront_cache_policy.default_cache_policy[0].id
}

# Create DNS validation records
resource "aws_route53_record" "cert_validation" {
  for_each = var.custom_domain != null ? {
    for dvo in aws_acm_certificate.cloudfront_cert[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  zone_id = data.aws_route53_zone.parent[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60

  allow_overwrite = true
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "cloudfront_cert" {
  count                   = var.custom_domain != null ? 1 : 0
  region                  = "us-east-1"
  certificate_arn         = aws_acm_certificate.cloudfront_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled    = true
  web_acl_id = var.waf_enabled ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null
  aliases    = var.custom_domain != null ? [var.custom_domain] : []

  dynamic "origin" {
    for_each = local.non_vpc_origins

    content {
      # TODO: Only have services return their domain name instead?
      domain_name              = origin.value.domain_name
      origin_id                = origin.key
      origin_access_control_id = contains(keys(origin.value.resources), "aws_lambda_function") ? aws_cloudfront_origin_access_control.lambda_oac[0].id : contains(keys(origin.value.resources), "aws_s3_bucket") ? aws_cloudfront_origin_access_control.s3_oac[0].id : null
      # Use the first route's base_path for the origin itself (for default behavior)
      origin_path = length(origin.value.routes) > 0 ? origin.value.routes[0].base_path : ""

      dynamic "custom_origin_config" {
        # Lambda functions with OAC should not have custom_origin_config
        for_each = !contains(keys(origin.value.resources), "aws_s3_bucket") ? [1] : []

        content {
          origin_read_timeout    = 30
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2", "SSLv3"]
          http_port              = 80
          https_port             = 443
        }
      }
    }
  }

  dynamic "origin" {
    for_each = local.vpc_origins

    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.key
      # Concatenate fargate's base path with any additional configured base_path
      # fargate provides "/<service-name>", add configured base_path if present
      # Use the first route's base_path for the origin itself (for default behavior)
      origin_path = try(
        length(origin.value.routes) > 0 && origin.value.routes[0].base_path != null && origin.value.routes[0].base_path != "" ?
        "${origin.value.resources["aws_lb:path"]}/${trimprefix(origin.value.routes[0].base_path, "/")}" :
        origin.value.resources["aws_lb:path"],
        ""
      )
      vpc_origin_config {
        vpc_origin_id = aws_cloudfront_vpc_origin.vpc_origin[origin.key].id
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    # separate out as lambda@edge cannot be used with VPC origins
    # create behaviors for VPC origins with non-root paths
    for_each = {
      for key, entry in local.non_root_origin_paths : key => entry
      if contains(keys(entry.resources), "aws_lb")
    }

    content {
      path_pattern = "${ordered_cache_behavior.value.path}*"

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.api-url-rewrite-function.arn
      }

      allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = ordered_cache_behavior.value.origin_name

      # See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-origin-cache-headers
      # Use AWS managed cache policy - UseOriginCacheHeaders
      # This policy honors the cache headers from the origin
      # cache_policy_id = "83da9c7e-98b4-4e11-a168-04f0df8e2c65"
      # FIXME: Disabling cache policy for now
      # as adding origin cache headers appears to cause issues with Lambda function URLs
      cache_policy_id = local.default_cache_policy_id

      # See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html#managed-origin-request-policy-all-viewer
      # Use AWS managed origin request policy - AllViewer
      # This forwards all headers, query strings, and cookies to the origin
      origin_request_policy_id = var.default_origin_request_policy_id

      # Legacy configuration for custom cache behavior
      # forwarded_values {
      #   query_string = true
      #   cookies {
      #     forward = "all"
      #   }
      #   headers = ["Authorization"]
      # }

      viewer_protocol_policy = "https-only"
    }
  }

  dynamic "ordered_cache_behavior" {
    # create behaviors for non-VPC origins with non-root paths
    for_each = {
      for key, entry in local.non_root_origin_paths : key => entry
      if !contains(keys(entry.resources), "aws_lb")
    }

    content {
      path_pattern = "${ordered_cache_behavior.value.path}*"

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.api-url-rewrite-function.arn
      }

      # Add Lambda@Edge for auth preservation and webhook signing (only if a Lambda origin)
      dynamic "lambda_function_association" {
        for_each = contains(keys(ordered_cache_behavior.value.resources), "aws_lambda_function") ? [1] : []
        content {
          event_type   = "origin-request"
          lambda_arn   = aws_lambda_function.origin_request[0].qualified_arn
          include_body = true
        }
      }

      allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = ordered_cache_behavior.value.origin_name

      # See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-origin-cache-headers
      # Use AWS managed cache policy - UseOriginCacheHeaders
      # This policy honors the cache headers from the origin
      # cache_policy_id = "83da9c7e-98b4-4e11-a168-04f0df8e2c65"
      # FIXME: Disabling cache policy for now
      # as adding origin cache headers appears to cause issues with Lambda function URLs
      cache_policy_id = local.default_cache_policy_id

      # See: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html#managed-origin-request-policy-all-viewer
      # Use AWS managed origin request policy - AllViewer
      # This forwards all headers, query strings, and cookies to the origin
      origin_request_policy_id = var.default_origin_request_policy_id

      # Legacy configuration for custom cache behavior
      # forwarded_values {
      #   query_string = true
      #   cookies {
      #     forward = "all"
      #   }
      #   headers = ["Authorization"]
      # }

      viewer_protocol_policy = "https-only"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = keys(local.default_origin)[0]
    viewer_protocol_policy = "redirect-to-https"

    # Add Lambda@Edge for auth preservation and webhook signing (only if not a Lambda origin and Lambda@Edge exists)
    dynamic "lambda_function_association" {
      for_each = length(local.default_origin) > 0 && contains(keys(local.default_origin[keys(local.default_origin)[0]].resources), "aws_lambda_function") ? [1] : []

      content {
        event_type   = "origin-request"
        lambda_arn   = aws_lambda_function.origin_request[0].qualified_arn
        include_body = true
      }
    }

    # Legacy configuration for custom cache behavior
    # forwarded_values {
    #   query_string = true
    #   cookies {
    #     forward = "all"
    #   }
    #   headers = ["Authorization"]
    # }

    # Use AWS managed cache policy - UseOriginCacheHeaders
    # This policy honors the cache headers from the origin
    # cache_policy_id = "83da9c7e-98b4-4e11-a168-04f0df8e2c65"
    # FIXME: Disabling cache policy for now
    # as adding origin cache headers appears to cause issues with Lambda function URLs
    cache_policy_id = local.default_cache_policy_id

    # Use AWS managed origin request policy - AllViewer
    # This forwards all headers, query strings, and cookies to the origin
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_type != "none" ? var.geo_restriction_locations : []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain == null ? true : false
    acm_certificate_arn            = var.custom_domain != null ? aws_acm_certificate_validation.cloudfront_cert[0].certificate_arn : null
    ssl_support_method             = var.custom_domain != null ? "sni-only" : null
    minimum_protocol_version       = var.custom_domain != null ? "TLSv1.2_2021" : null
  }
}
