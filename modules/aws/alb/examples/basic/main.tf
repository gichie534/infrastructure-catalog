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
  default     = "example-alb"
}

# Latest Amazon Linux 2023 AMI via the SSM public parameter — keeps the example region-portable.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

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

# Security group for the instances: accept HTTP only from the ALB, allow all egress.
resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "HTTP from the ALB to the app instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app" }
}

# Two instances, each running a tiny HTTP server that answers ANY path with its own identity — so
# path-forwarded requests like /a/foo (ALB does not strip the prefix) still get a 200.
resource "aws_instance" "app" {
  for_each = {
    a = "app-a"
    b = "app-b"
  }

  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf install -y python3
    cat >/opt/app.py <<'PY'
    from http.server import BaseHTTPRequestHandler, HTTPServer
    NAME = "${each.value}"
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            body = ("hello from %s\n" % NAME).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def log_message(self, *a):
            pass
    HTTPServer(("0.0.0.0", 80), H).serve_forever()
    PY
    cat >/etc/systemd/system/webapp.service <<'UNIT'
    [Unit]
    Description=demo web app
    After=network.target
    [Service]
    ExecStart=/usr/bin/python3 /opt/app.py
    Restart=always
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now webapp
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = { Name = "${var.name}-${each.value}" }
}

module "alb" {
  source = "../../"

  name       = var.name
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)

  target_groups = {
    a = {
      port              = 80
      target_ids        = [aws_instance.app["a"].id]
      health_check_path = "/"
    }
    b = {
      port              = 80
      target_ids        = [aws_instance.app["b"].id]
      health_check_path = "/"
    }
  }

  listener_rules = {
    path_a = { priority = 10, target_group_key = "a", path_patterns = ["/a", "/a/*"] }
    path_b = { priority = 20, target_group_key = "b", path_patterns = ["/b", "/b/*"] }
    host_a = { priority = 30, target_group_key = "a", host_headers = ["a.example.com"] }
    host_b = { priority = 40, target_group_key = "b", host_headers = ["b.example.com"] }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = module.alb.dns_name
}

output "target_group_arns" {
  description = "Target group ARNs by key."
  value       = module.alb.target_group_arns
}
