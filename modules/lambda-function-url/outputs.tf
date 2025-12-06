output "function_url" {
  description = "URL of the Lambda Function URL"
  value       = aws_lambda_function_url.services.function_url
}

output "domain_name" {
  description = "Domain name of the Lambda Function URL (for CloudFront origin)"
  value       = trimprefix(trimsuffix(aws_lambda_function_url.services.function_url, "/"), "https://")
}
