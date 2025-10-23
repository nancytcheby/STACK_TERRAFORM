output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "versioning_status" {
  value       = var.enable_versioning ? "Enabled" : "Suspended"
  description = "Requested S3 versioning status"
}

output "cloudtrail_log_bucket" {
  value       = var.enable_object_level_logging ? aws_s3_bucket.cloudtrail_logs[0].id : null
  description = "Bucket storing CloudTrail object-level logs"
}

output "website_endpoint" {
  value = (
    length(aws_s3_bucket_website_configuration.static) > 0 ?
    aws_s3_bucket_website_configuration.static[0].website_endpoint :
    length(aws_s3_bucket_website_configuration.redirect) > 0 ?
    aws_s3_bucket_website_configuration.redirect[0].website_endpoint :
    null
  )
  description = "S3 static website endpoint (if hosting or redirect is enabled)"
}

output "sqs_queue_url" {
  value       = var.enable_event_notifications ? aws_sqs_queue.s3_events[0].url : null
  description = "SQS queue URL receiving S3 events"
}

output "sqs_queue_arn" {
  value       = var.enable_event_notifications ? aws_sqs_queue.s3_events[0].arn : null
  description = "SQS queue ARN receiving S3 events"
}

# CONTROL_SCRIPT_TERRAFORM: Lifecycle_Output_Nancy_Tcheby_v1.0

output "lifecycle_rule_status" {
  description = "Status of the lifecycle rule (Enabled/Disabled)"
  value       = try(aws_s3_bucket_lifecycle_configuration.this[0].rule[0].status, "Not configured")
}

output "lifecycle_transition_days" {
  description = "Days until transition to STANDARD_IA and GLACIER"
  value       = try("${var.transition_to_ia_days} / ${var.transition_to_glacier_days}", "Not configured")
}

output "source_bucket_name" {
  description = "Primary/source S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "source_bucket_arn" {
  value = aws_s3_bucket.this.arn
}

# --- Cross-Region Replication (CRR) ---
output "replication_enabled" {
  description = "Whether CRR resources were created"
  value       = var.enable_crr
}

output "replica_bucket_name" {
  description = "Destination (replica) bucket name, or null if CRR disabled"
  value       = try(aws_s3_bucket.replica[0].id, null)
}

output "replica_bucket_arn" {
  value = try(aws_s3_bucket.replica[0].arn, null)
}

output "replica_region" {
  description = "Replica bucket region"
  value       = var.dest_region
}

output "replication_role_arn" {
  description = "IAM role S3 assumes for replication"
  value       = try(aws_iam_role.replication[0].arn, null)
}

# List of rule IDs from the replication configuration (helpful to confirm filters)
output "replication_rule_ids" {
  value = try(aws_s3_bucket_replication_configuration.this[0].rule[*].id, [])
}

# Useful if you set account_id/access_control_translation (cross-account)
output "dest_account_id" {
  value       = try(var.dest_account_id, null)
  description = "Destination AWS account ID (if cross-account)"
}

# --- Storage Class Analysis (S3 Analytics) ---
output "analytics_enabled" {
  value       = var.enable_storage_class_analysis
  description = "Whether bucket analytics is configured"
}

output "analytics_config_name" {
  value       = try(aws_s3_bucket_analytics_configuration.default[0].name, null)
  description = "Name of the S3 analytics configuration"
}

output "analytics_export_bucket" {
  value       = try(aws_s3_bucket.analytics_export[0].id, null)
  description = "Bucket receiving analytics CSV reports (if enabled)"
}

