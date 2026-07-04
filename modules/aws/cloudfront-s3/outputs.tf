output "distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution. Use it in each origin bucket's policy condition (AWS:SourceArn) to grant only this distribution access via OAC."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "Distribution domain name (e.g. d111111abcdef8.cloudfront.net). This is the DNS you open in a browser."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "CloudFront's hosted zone ID, for aliasing a custom domain to the distribution with a Route 53 alias record."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "origin_access_control_id" {
  description = "ID of the Origin Access Control shared by all S3 origins."
  value       = aws_cloudfront_origin_access_control.this.id
}
