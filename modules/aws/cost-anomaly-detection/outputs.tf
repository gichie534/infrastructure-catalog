output "monitor_arns" {
  description = "Map of monitor name to ARN."
  value       = { for key, monitor in aws_ce_anomaly_monitor.this : key => monitor.arn }
}

output "monitor_names" {
  description = "Names of the managed cost monitors."
  value       = keys(aws_ce_anomaly_monitor.this)
}

output "subscription_arns" {
  description = "Map of subscription name to ARN."
  value       = { for key, subscription in aws_ce_anomaly_subscription.this : key => subscription.arn }
}

output "subscription_names" {
  description = "Names of the managed alert subscriptions."
  value       = keys(aws_ce_anomaly_subscription.this)
}

output "subscription_monitor_keys" {
  description = "Map of subscription name to the module-managed monitor keys it covers, after the 'empty means all monitors' default is resolved. Use it to confirm a subscription actually watches what you think it does."
  value       = { for key, subscription in local.subscriptions : key => subscription.resolved_monitor_keys }
}

output "subscription_monitor_arns" {
  description = "Map of subscription name to every monitor ARN it covers — both the monitors this module manages and any adopted via `monitor_arns`."
  value       = { for key, subscription in aws_ce_anomaly_subscription.this : key => subscription.monitor_arn_list }
}
