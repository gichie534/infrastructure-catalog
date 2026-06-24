provider "aws" {
  region = var.region
}

# A minimal standard queue with long polling enabled. Real consumers tune the timeouts and attach
# their own IAM policies referencing the queue ARN.
module "sqs" {
  source = "../../"

  name                      = var.name
  receive_wait_time_seconds = 10

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
