# =============================================================================
# LAMBDA FUNCTION URL
# =============================================================================

# Lambda Function URL
resource "aws_lambda_function_url" "services" {
  function_name      = var.lambda_function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
    max_age       = 3600
  }
}
