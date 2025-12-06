# tf-aws-s3-cloudfront-demo

Terraform module for deploying a secure static website using S3 and CloudFront with Origin Access Control. This demo showcases AWS services available in the Asia Pacific (New Zealand) region (ap-southeast-6).

<!-- BEGIN_TF_DOCS -->
## Architecture

```plaintext
User
  │
  ├─→ CloudFront Distribution (Global CDN)
  │     │
  │     ├─→ S3 Bucket (Static Assets)
  │     │     └─→ index.html, CSS, JS, etc.
  │     │
  │     └─→ Lambda Function URL (Dynamic API)
  │           └─→ SSM Parameter Store (Service List)
```

## Features

- **Secure S3 Bucket**: Private bucket with Block Public Access enabled
- **CloudFront CDN**: Global content delivery with edge caching
- **Origin Access Control (OAC)**: Secure S3 access via CloudFront only
- **Dynamic Service Listing**: Lambda function fetches available AWS services from SSM Parameter Store
- **Serverless API**: Lambda Function URL for dynamic content
- **Modern UI**: Responsive design with dynamic content loading

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 6.0 |
| random | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |
| random | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | `"s3-cloudfront-demo"` | no |
| domain_name | Custom domain name for CloudFront distribution | `string` | `null` | no |
| hosted_zone_id | Route53 hosted zone ID for DNS records | `string` | `null` | no |
| price_class | CloudFront price class | `string` | `"PriceClass_100"` | no |
| bucket_name | S3 bucket name (auto-generated if null) | `string` | `null` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |
| index_document | Default root object for CloudFront | `string` | `"index.html"` | no |
| error_document_403 | Error document for 403 errors | `string` | `"error-403.html"` | no |
| error_document_404 | Error document for 404 errors | `string` | `"error-404.html"` | no |
| error_document_405 | Error document for 405 errors | `string` | `"error-405.html"` | no |
| log_bucket_name | S3 bucket name for CloudFront access logs (optional) | `string` | `null` | no |
| allowed_methods | Allowed HTTP methods for CloudFront distribution | `list(string)` | `["GET", "HEAD"]` | no |
| geo_restriction | Geo restriction configuration for CloudFront | `object({type=string, locations=list(string)})` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the S3 bucket |
| bucket_arn | ARN of the S3 bucket |
| distribution_id | ID of the CloudFront distribution |
| distribution_domain_name | Domain name of the CloudFront distribution |
| cloudfront_url | URL to access the website via CloudFront |
| website_url | Website URL (alias for cloudfront_url) |
| lambda_function_url | Lambda Function URL for fetching services |

<!-- END_TF_DOCS -->

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- AWS Account with permissions for:
  - CloudFront distributions
  - S3 buckets and policies
  - Lambda functions and Function URLs
  - SSM Parameter Store (read)
  - IAM roles and policies

### Deployment

1. Clone the repository:

    ```bash
    git clone https://github.com/jdevto/tf-aws-s3-cloudfront-demo.git
    cd tf-aws-s3-cloudfront-demo
    ```

2. Initialize Terraform:

    ```bash
    terraform init
    ```

3. Review the plan:

    ```bash
    terraform plan
    ```

4. Deploy the infrastructure:

    ```bash
    terraform apply
    ```

5. Get the CloudFront URL:

    ```bash
    terraform output cloudfront_url
    ```

6. Open the URL in your browser to see the demo!

## Usage

### Basic Usage

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-6"
}

# Use default configuration
# All resources will be created with default values
```

### Custom Domain

```hcl
variable "domain_name" {
  default = "example.com"
}

variable "hosted_zone_id" {
  default = "Z1234567890ABC"
}
```

**Note**: Custom domains require manual ACM certificate setup in `us-east-1` region for CloudFront. This demo uses the default CloudFront certificate.

## Architecture Details

### S3 Bucket

- Private bucket with Block Public Access enabled
- SSE-S3 encryption at rest
- Versioning enabled
- Object ownership: BucketOwnerPreferred
- Accessible only via CloudFront OAC

### CloudFront Distribution

- Single S3 origin with Origin Access Control
- AWS managed `CachingOptimized` cache policy
- AWS managed `SecurityHeadersPolicy` response headers
- IPv6 enabled
- Compression enabled
- HTTPS redirect (viewer protocol policy)

### Lambda Function

- Python 3.13 runtime
- Fetches services from SSM Parameter Store
- Lambda Function URL for public HTTP access
- CORS enabled for browser access
- IAM role with SSM read permissions

## Cost Notes

- **S3**: Pay for storage and requests (minimal for static sites)
- **CloudFront**: Pay per request and data transfer (PriceClass_100 = US, Canada, Europe)
- **Lambda**: Pay per request (first 1M requests free per month)
- **SSM Parameter Store**: Free for standard parameters

**Estimated Monthly Cost**: $1-5 for demo usage (depending on traffic)

**Note**: No WAF included. Shield Standard is included with CloudFront at no additional cost.

## Testing

### Validate Configuration

```bash
terraform validate
terraform fmt -check -recursive
```

### Test the Website

1. Get the CloudFront URL:

    ```bash
    terraform output cloudfront_url
    ```

2. Open in browser and verify:
   - Static content loads correctly
   - Services list loads dynamically
   - Error page works (try `/nonexistent`)

### Verify Security

```bash
# Try to access S3 bucket directly (should fail)
aws s3 ls s3://$(terraform output -raw bucket_name)/

# Verify CloudFront OAC is configured
aws cloudfront get-distribution-config --id $(terraform output -raw distribution_id)
```

## Cleanup

```bash
terraform destroy
```

**Note**: CloudFront distributions can take 15+ minutes to delete. S3 buckets with versioning may need manual cleanup.

## CI/CD

GitHub Actions workflow automatically validates Terraform code on push and pull requests.

## About

This demo was created for the **AWS Wellington User Group Meetup #77** - December 9, 2025.

Deploy a service or application to the new AWS region: **Asia Pacific (New Zealand) - ap-southeast-6** to be eligible for limited-edition t-shirts and prizes from Ingram Micro!

## License

MIT License - see [LICENSE](LICENSE) file for details.
