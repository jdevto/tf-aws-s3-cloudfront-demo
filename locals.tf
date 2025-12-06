# =============================================================================
# LOCALS
# =============================================================================

# Common tags for all resources
locals {
  tags = merge({
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
    Purpose     = "s3-cloudfront-demo"
  }, var.tags)
}
