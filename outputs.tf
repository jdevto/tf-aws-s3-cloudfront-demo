# =============================================================================
# OUTPUTS
# =============================================================================

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.static.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.static.arn
}

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_url" {
  description = "URL to access the website via CloudFront"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "website_url" {
  description = "Website URL (alias for cloudfront_url)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "lambda_function_url" {
  description = "Lambda Function URL for fetching services (only if api_type is lambda_function_url)"
  value       = var.api_type == "lambda_function_url" ? module.lambda_function_url[0].function_url : null
}

output "api_gateway_url" {
  description = "API Gateway URL for fetching services (only if api_type is api_gateway)"
  value       = var.api_type == "api_gateway" ? "https://${module.api_gateway[0].api_domain_name}${module.api_gateway[0].api_path}" : null
}

output "api_endpoint_url" {
  description = "API endpoint URL (Lambda Function URL or API Gateway depending on api_type)"
  value       = var.api_type == "lambda_function_url" ? module.lambda_function_url[0].function_url : "https://${module.api_gateway[0].api_domain_name}${module.api_gateway[0].api_path}"
}
