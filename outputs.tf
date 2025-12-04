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
  description = "Lambda Function URL for fetching services"
  value       = aws_lambda_function_url.services.function_url
}
