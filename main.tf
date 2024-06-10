terraform {
  required_version = "~> 1.8.4" # Ensures that the Terraform version is compatible

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.32.0" # Specifies the minimum required version of the AWS provider
    }
  }
}

provider "aws" {
  profile = "NAME-OF-YOUR-PROFILE" # Change to your own profile name
  region  = "${local.region}" # Uses the region from local variables
}

#------------------------------  Lambda Module  ---------------------------------#
module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "update_bucket_policy" # Lambda function name
  description   = "My awesome lambda function" # Description of the Lambda function
  handler       = "lambda_bucket_policy.lambda_handler" # Lambda function handler
  runtime       = "python3.11" # Runtime environment for the Lambda function
  source_path   = "./lambda/lambda_bucket_policy.py" # Path to the Lambda function source code
  policy = aws_iam_policy.policy.arn # Attach the IAM policy to the Lambda function
  timeout = 10 # Lambda function timeout in seconds
  attach_policy = true # Attach the IAM policy
  environment_variables = {
    BUCKET_NAME = join(",", local.bucket_names) # Environment variable for bucket names
  }
  tags = {
    Name = "update_bucket_policy" # Tags for the Lambda function
  }
}

resource "aws_iam_policy" "policy" {
  name        = "PutBucketPolicy" # Name of the IAM policy
  path        = "/"
  description = "Put Bucket Policy to update Cloudflare IPs" # Description of the IAM policy

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VisualEditor0"
        Effect = "Allow"
        Action = [
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy"
        ],
        Resource = [for bucket in local.bucket_names : "arn:aws:s3:::${bucket}"] # Specifies the S3 bucket resources
      },
    ]
  })
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role" # Name of the IAM role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com" # Allows Lambda service to assume this role
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name # Attach the role to the Lambda execution role
  policy_arn = aws_iam_policy.policy.arn # IAM policy ARN
}

module "s3_buckets" {
  source = "terraform-aws-modules/s3-bucket/aws"
  for_each = { for bucket in local.bucket_names : bucket => bucket } # Creates a bucket for each entry in bucket names
  force_destroy = true # Forcefully destroy the bucket if not empty
  bucket = each.key
  block_public_acls = false
  block_public_policy = false
  ignore_public_acls = false
  restrict_public_buckets = false
  website = {
    index_document = "index.html" # Set index document for the website
  }
  versioning = {
    enabled = false # Enable or disable versioning based on requirement
  }
  tags = {
    Name = each.key # Tags for the S3 bucket
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  for_each = { for bucket in local.bucket_names : bucket => bucket }

  bucket = each.key
  policy = format(local.public_read_policy_template, each.key) # Apply the public read policy template
  lifecycle {
    ignore_changes = [policy] # Ignore changes to the policy
  }
}

resource "aws_cloudwatch_event_rule" "weekly_trigger" {
  name                = "weekly-lambda-trigger" # Name of the CloudWatch event rule
  description         = "Trigger Lambda function weekly" # Description of the event rule
  schedule_expression = "cron(0 12 ? * MON *)" # Schedule the event to trigger at 12:00 PM every Monday
}

resource "aws_cloudwatch_event_target" "lambda_weekly_target" {
  rule      = aws_cloudwatch_event_rule.weekly_trigger.name # CloudWatch event rule name
  target_id = "LambdaTarget" # Target ID for the event rule
  arn       = module.lambda_function.lambda_function_arn # ARN of the Lambda function to trigger
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch" # ID of the permission statement
  action        = "lambda:InvokeFunction" # Allow the invocation of the Lambda function
  function_name = module.lambda_function.lambda_function_name # Name of the Lambda function
  principal     = "events.amazonaws.com" # Principal service (CloudWatch events)
  source_arn    = aws_cloudwatch_event_rule.weekly_trigger.arn # Source ARN for the event rule
}
