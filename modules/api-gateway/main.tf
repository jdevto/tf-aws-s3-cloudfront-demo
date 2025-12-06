# =============================================================================
# API GATEWAY FOR LAMBDA
# =============================================================================

# API Gateway REST API
resource "aws_api_gateway_rest_api" "services" {
  name        = "${var.project_name}-api"
  description = "API Gateway for Lambda services"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api"
  })
}

# API Gateway Resource for /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  parent_id   = aws_api_gateway_rest_api.services.root_resource_id
  path_part   = "api"
}

# API Gateway Resource for /api/services
resource "aws_api_gateway_resource" "services" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "services"
}

# API Gateway Method
resource "aws_api_gateway_method" "services" {
  rest_api_id   = aws_api_gateway_rest_api.services.id
  resource_id   = aws_api_gateway_resource.services.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Method for OPTIONS (CORS)
resource "aws_api_gateway_method" "services_options" {
  rest_api_id   = aws_api_gateway_rest_api.services.id
  resource_id   = aws_api_gateway_resource.services.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "services" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  resource_id = aws_api_gateway_resource.services.id
  http_method = aws_api_gateway_method.services.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# API Gateway Integration for OPTIONS (CORS)
resource "aws_api_gateway_integration" "services_options" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  resource_id = aws_api_gateway_resource.services.id
  http_method = aws_api_gateway_method.services_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response for GET
resource "aws_api_gateway_method_response" "services" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  resource_id = aws_api_gateway_resource.services.id
  http_method = aws_api_gateway_method.services.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# API Gateway Method Response for OPTIONS
resource "aws_api_gateway_method_response" "services_options" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  resource_id = aws_api_gateway_resource.services.id
  http_method = aws_api_gateway_method.services_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# API Gateway Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "services_options" {
  rest_api_id = aws_api_gateway_rest_api.services.id
  resource_id = aws_api_gateway_resource.services.id
  http_method = aws_api_gateway_method.services_options.http_method
  status_code = aws_api_gateway_method_response.services_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.services.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "services" {
  rest_api_id = aws_api_gateway_rest_api.services.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.services.id,
      aws_api_gateway_method.services.id,
      aws_api_gateway_method.services_options.id,
      aws_api_gateway_integration.services.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "services" {
  deployment_id = aws_api_gateway_deployment.services.id
  rest_api_id   = aws_api_gateway_rest_api.services.id
  stage_name    = "prod"
}
