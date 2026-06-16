output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "The primary IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (for load balancers, NAT gateways, bastions)."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (for EKS/ECS workloads and other compute)."
  value       = [for s in aws_subnet.private : s.id]
}

output "public_subnets_by_az" {
  description = "Map of availability zone to public subnet ID."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnets_by_az" {
  description = "Map of availability zone to private subnet ID."
  value       = { for az, s in aws_subnet.private : az => s.id }
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Map of availability zone to private route table ID."
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs, or an empty list when NAT is disabled."
  value       = [for ngw in aws_nat_gateway.this : ngw.id]
}

output "nat_public_ips" {
  description = "List of Elastic IPs assigned to the NAT gateways."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}
