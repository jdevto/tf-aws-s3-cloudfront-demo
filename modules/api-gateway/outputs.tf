output "api_url" {
  description = "Full URL of the API Gateway endpoint"
  value       = "https://${aws_api_gateway_rest_api.services.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/prod/api/services"
}

output "api_domain_name" {
  description = "Domain name of the API Gateway (for CloudFront origin)"
  value       = "${aws_api_gateway_rest_api.services.id}.execute-api.${data.aws_region.current.region}.amazonaws.com"
}

output "api_path" {
  description = "Path for the API endpoint"
  value       = "/prod/api/services"
}
