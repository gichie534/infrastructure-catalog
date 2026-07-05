provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the ALB and related resources."
  type        = string
  default     = "example-alb-lambda"
}

# An internet-facing ALB in front of a Lambda target. Proves the module's target_type = "lambda"
# path: it creates a lambda target group (no port/protocol/vpc_id), grants Elastic Load Balancing
# permission to invoke the function, and registers the function ARN with the group.

# Use the account's default VPC and its subnets so the example is self-contained. An ALB needs
# subnets in at least two AZs; the default VPC provides one per AZ.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# A tiny Python function that answers with the ALB target-group response shape. Zipped inline so the
# example is self-contained and applies with no build step.
data "archive_file" "package" {
  type        = "zip"
  output_path = "${path.module}/function.zip"

  source {
    filename = "index.py"
    content  = <<-PY
      def handler(event, context):
          return {
              "statusCode": 200,
              "statusDescription": "200 OK",
              "headers": {"Content-Type": "text/plain; charset=utf-8"},
              "body": "hello from lambda\n",
          }
    PY
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "app" {
  function_name = var.name
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  handler = "index.handler"
  runtime = "python3.12"

  depends_on = [aws_iam_role_policy_attachment.basic]
}

module "alb" {
  source = "../../"

  name       = var.name
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)

  # A single lambda target group. Pass the function ARN as the one target_id; the module registers
  # it and creates the ELB invoke permission. Unmatched requests forward here (no listener rules).
  target_groups = {
    app = {
      target_type = "lambda"
      target_ids  = [aws_lambda_function.app.arn]
    }
  }

  default_target_group_key = "app"

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.alb.dns_name
}

output "function_name" {
  description = "Name of the Lambda function fronted by the ALB."
  value       = aws_lambda_function.app.function_name
}
