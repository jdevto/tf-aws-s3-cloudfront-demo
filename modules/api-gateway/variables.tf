variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to invoke"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
