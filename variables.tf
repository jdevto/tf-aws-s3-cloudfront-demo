# =============================================================================
# VARIABLES
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "s3-cloudfront-demo"
}

variable "domain_name" {
  description = "Custom domain name for CloudFront distribution"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "bucket_name" {
  description = "S3 bucket name (auto-generated if null)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "index_document" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "error_document_404" {
  description = "Error document for 404 errors"
  type        = string
  default     = "error-404.html"
}

variable "error_document_405" {
  description = "Error document for 405 errors"
  type        = string
  default     = "error-405.html"
}

variable "error_document_403" {
  description = "Error document for 403 errors"
  type        = string
  default     = "error-403.html"
}

variable "log_bucket_name" {
  description = "S3 bucket name for CloudFront access logs (optional)"
  type        = string
  default     = null
}

variable "allowed_methods" {
  description = "Allowed HTTP methods for CloudFront distribution"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "geo_restriction" {
  description = "Geo restriction configuration for CloudFront"
  type = object({
    type      = string
    locations = list(string)
  })
  default = null
}

variable "api_type" {
  description = "Type of API endpoint to use: 'lambda_function_url' or 'api_gateway'"
  type        = string
  default     = "lambda_function_url"
  validation {
    condition     = contains(["lambda_function_url", "api_gateway"], var.api_type)
    error_message = "api_type must be either 'lambda_function_url' or 'api_gateway'"
  }
}
