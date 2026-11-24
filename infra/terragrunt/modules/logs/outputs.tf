output "task_logs_bucket" {
  description = "Bucket Airflow writes task logs to."
  value       = module.task_logs.s3_bucket_id
}

output "task_logs_bucket_arn" {
  value = module.task_logs.s3_bucket_arn
}

output "container_log_groups" {
  description = "Container log group per cluster, for Fluent Bit."
  value       = { for cluster, group in aws_cloudwatch_log_group.containers : cluster => group.name }
}
