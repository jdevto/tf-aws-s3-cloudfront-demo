# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_region" "current" {
}

# CloudFront managed cache policies
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# CloudFront managed response headers policies
data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

# CloudFront managed origin request policies
data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

# =============================================================================
# RANDOM ID FOR BUCKET NAME
# =============================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# =============================================================================
# S3 BUCKET FOR STATIC ASSETS
# =============================================================================

# S3 Bucket for static assets
resource "aws_s3_bucket" "static" {
  bucket = var.bucket_name != null ? var.bucket_name : "${var.project_name}-${random_id.bucket_suffix.hex}"

  force_destroy = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-static-bucket"
  })
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket object ownership
resource "aws_s3_bucket_ownership_controls" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Upload static files to S3 (regular files)
resource "aws_s3_object" "static_files" {
  for_each = merge(
    {
      "index.html"     = "${path.module}/static/index.html"
      "error-403.html" = "${path.module}/static/error-403.html"
      "error-404.html" = "${path.module}/static/error-404.html"
      "error-405.html" = "${path.module}/static/error-405.html"
      "style.css"      = "${path.module}/static/style.css"
      "favicon.ico"    = "${path.module}/static/favicon.ico"
      "robots.txt"     = "${path.module}/static/robots.txt"
      "icons.json"     = "${path.module}/static/icons.json"
    },
    # Upload all icons
    {
      for icon_path in fileset("${path.module}/static/icons", "**/*.svg") :
      "icons/${icon_path}" => "${path.module}/static/icons/${icon_path}"
    }
  )

  bucket = aws_s3_bucket.static.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)

  content_type = (
    each.key == "index.html" ? "text/html" :
    each.key == "error-403.html" ? "text/html" :
    each.key == "error-404.html" ? "text/html" :
    each.key == "error-405.html" ? "text/html" :
    each.key == "style.css" ? "text/css" :
    each.key == "favicon.ico" ? "image/x-icon" :
    each.key == "robots.txt" ? "text/plain" :
    each.key == "icons.json" ? "application/json" :
    endswith(each.key, ".svg") ? "image/svg+xml" : "application/octet-stream"
  )

  cache_control = (
    each.key == "index.html" ? "public, max-age=86400" :
    "public, max-age=31536000, immutable"
  )

  tags = merge(local.tags, { Name = "${var.project_name}-static-${each.key}" })
}

# Upload script.js with Lambda URL injected
resource "aws_s3_object" "script_js" {
  bucket = aws_s3_bucket.static.id
  key    = "script.js"
  content = templatefile("${path.module}/static/script.js.tpl", {
    cloudfront_url = "https://${aws_cloudfront_distribution.this.domain_name}"
  })
  content_type  = "application/javascript"
  cache_control = "public, max-age=31536000, immutable"

  tags = merge(local.tags, {
    Name = "${var.project_name}-static-script.js"
  })

  depends_on = [
    module.lambda_function_url,
    module.api_gateway
  ]
}

# S3 Bucket policy for CloudFront OAC
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_object.static_files,
    aws_cloudfront_distribution.this
  ]
}

# =============================================================================
# LAMBDA FUNCTION FOR FETCHING SERVICES
# =============================================================================

# IAM role for Lambda
resource "aws_iam_role" "lambda_services" {
  name = "${var.project_name}-lambda-services-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${var.project_name}-lambda-services-role"
  })
}

# IAM policy for Lambda to read SSM parameters
resource "aws_iam_role_policy" "lambda_services" {
  name = "${var.project_name}-lambda-services-policy"
  role = aws_iam_role.lambda_services.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParametersByPath",
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/aws/service/global-infrastructure/*",
          "arn:aws:ssm:*::parameter/aws/service/global-infrastructure/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda function code
data "archive_file" "lambda_services" {
  type        = "zip"
  output_path = "${path.module}/lambda/services.zip"
  source {
    content  = file("${path.module}/lambda/services.py")
    filename = "services.py"
  }
}

# Lambda function for Lambda Function URL
resource "aws_lambda_function" "services" {
  count = var.api_type == "lambda_function_url" ? 1 : 0

  provider = aws.ap_southeast_2

  filename         = data.archive_file.lambda_services.output_path
  function_name    = "${var.project_name}-services"
  role             = aws_iam_role.lambda_services.arn
  handler          = "services.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = data.archive_file.lambda_services.output_base64sha256
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      TARGET_REGION = "ap-southeast-6" # Region to list services for
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-lambda-services"
  })
}

# Lambda function for API Gateway
resource "aws_lambda_function" "services_api_gateway" {
  count = var.api_type == "api_gateway" ? 1 : 0

  filename         = data.archive_file.lambda_services.output_path
  function_name    = "${var.project_name}-services"
  role             = aws_iam_role.lambda_services.arn
  handler          = "services.lambda_handler"
  runtime          = "python3.13"
  source_code_hash = data.archive_file.lambda_services.output_base64sha256
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      TARGET_REGION = "ap-southeast-6" # Region to list services for
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-lambda-services"
  })
}

# Lambda Function URL Module (conditional - only if api_type is lambda_function_url)
module "lambda_function_url" {
  count = var.api_type == "lambda_function_url" ? 1 : 0

  source = "./modules/lambda-function-url"

  providers = {
    aws = aws.ap_southeast_2
  }

  lambda_function_name = aws_lambda_function.services[0].function_name
}

# API Gateway Module (conditional - only if api_type is api_gateway)
module "api_gateway" {
  count = var.api_type == "api_gateway" ? 1 : 0

  source = "./modules/api-gateway"

  project_name         = var.project_name
  lambda_function_name = aws_lambda_function.services_api_gateway[0].function_name
  lambda_invoke_arn    = aws_lambda_function.services_api_gateway[0].invoke_arn
  tags                 = local.tags
}

# =============================================================================
# CLOUDFRONT
# =============================================================================

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Cache Policy for Lambda API with stale-while-revalidate
resource "aws_cloudfront_cache_policy" "lambda_api" {
  name        = "${var.project_name}-lambda-api-cache"
  comment     = "Cache policy for Lambda API with stale-while-revalidate"
  default_ttl = 300 # 5 minutes
  max_ttl     = 600 # 10 minutes (stale-while-revalidate window)
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = "origin-s3"
  }

  origin {
    domain_name = var.api_type == "lambda_function_url" ? module.lambda_function_url[0].domain_name : module.api_gateway[0].api_domain_name
    origin_id   = "origin-lambda"
    origin_path = var.api_type == "api_gateway" ? "/prod" : ""

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} CloudFront distribution"

  default_root_object = var.index_document

  default_cache_behavior {
    allowed_methods        = var.allowed_methods
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "origin-s3"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Custom cache behavior for Lambda API with stale-while-revalidate
  ordered_cache_behavior {
    path_pattern           = "/api/services"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "origin-lambda"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = aws_cloudfront_cache_policy.lambda_api.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Custom error responses
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/${var.error_document_404}"
  }

  custom_error_response {
    error_code         = 405
    response_code      = 405
    response_page_path = "/${var.error_document_405}"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 403
    response_page_path = "/${var.error_document_403}"
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction != null ? var.geo_restriction.type : "none"
      locations        = var.geo_restriction != null ? var.geo_restriction.locations : []
    }
  }

  # Viewer certificate - use default CloudFront certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Custom domain (requires manual ACM certificate setup if needed)
  aliases = var.domain_name != null ? [var.domain_name] : []

  # CloudFront logging
  dynamic "logging_config" {
    for_each = var.log_bucket_name != null ? [1] : []
    content {
      bucket          = var.log_bucket_name
      include_cookies = false
      prefix          = "cloudfront/"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-cloudfront"
  })
}

# =============================================================================
# ROUTE53 DNS RECORDS
# =============================================================================

# Route53 A record
resource "aws_route53_record" "cloudfront_a" {
  count = var.domain_name != null && var.hosted_zone_id != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record
resource "aws_route53_record" "cloudfront_aaaa" {
  count = var.domain_name != null && var.hosted_zone_id != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
