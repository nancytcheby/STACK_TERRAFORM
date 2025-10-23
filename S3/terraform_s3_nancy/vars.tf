############################
# Core / tagging
############################
variable "region" {
  description = "AWS region for the SOURCE bucket"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name (lowercase, 3-63 chars)"
  type        = string
}

variable "owner" {
  description = "Owner name tag"
  type        = string
  default     = "Nancy Tcheby"
}

variable "bucket_tags" {
  description = "Extra cost allocation tags"
  type        = map(string)
  default = {
    Owner       = "Nancy Tcheby"
    Environment = "Dev"
    Department  = "Cloud Eng Training"
  }
}

############################
# Versioning / encryption
############################
variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "default_encryption" {
  description = "Default encryption for new objects: one of 'none', 'AES256', 'aws:kms'"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["none", "AES256", "aws:kms"], var.default_encryption)
    error_message = "default_encryption must be 'none', 'AES256', or 'aws:kms'."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN (required if default_encryption = 'aws:kms')"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow Terraform to automatically empty and delete the bucket on destroy"
  type        = bool
  default     = false
}

############################
# Server access logging
############################
variable "enable_server_access_logging" {
  description = "Enable S3 server access logging"
  type        = bool
  default     = true
}

variable "log_bucket_name" {
  description = "Optional custom name for the log bucket. If null, will use <bucket_name>-logs"
  type        = string
  default     = null
}

variable "log_prefix" {
  description = "Prefix inside the log bucket where access logs are written"
  type        = string
  default     = "s3-access-logs/"
}

############################
# Object-level logging (CloudTrail)
############################
variable "enable_object_level_logging" {
  description = "Enable CloudTrail Data Events for S3 object-level logging"
  type        = bool
  default     = true
}

variable "trail_name" {
  description = "CloudTrail trail name"
  type        = string
  default     = "s3-object-events-trail"
}

variable "trail_log_bucket_name" {
  description = "S3 bucket to store CloudTrail logs; null -> <bucket_name>-ct-logs"
  type        = string
  default     = null
}

############################
# Static website hosting
############################
variable "enable_website" {
  description = "Enable S3 static website hosting"
  type        = bool
  default     = true
}

variable "website_index" {
  description = "Index document for static website"
  type        = string
  default     = "index.html"
}

variable "website_error" {
  description = "Error document for static website"
  type        = string
  default     = "error.html"
}

variable "website_redirect_host" {
  description = "Redirect all requests to this host (null = no redirect)"
  type        = string
  default     = null
}

variable "make_website_public" {
  description = "Allow public GET to website objects via bucket policy"
  type        = bool
  default     = true
}

############################
# Event notifications → SQS
############################
variable "enable_event_notifications" {
  description = "Enable S3 event notifications to SQS"
  type        = bool
  default     = true
}

variable "notify_prefix" {
  description = "Only fire events for keys starting with this prefix (empty = all)"
  type        = string
  default     = ""
}

variable "notify_suffix" {
  description = "Only fire events for keys ending with this suffix (empty = all)"
  type        = string
  default     = ""
}

############################
# Object Lock (separate demo bucket)
############################
variable "enable_object_lock" {
  description = "Create a separate bucket with S3 Object Lock enabled"
  type        = bool
  default     = true
}

variable "object_lock_bucket_name" {
  description = "Name of the Object Lock demo bucket; null -> <bucket_name>-olock"
  type        = string
  default     = null
}

variable "object_lock_mode" {
  description = "Default Object Lock mode: GOVERNANCE or COMPLIANCE"
  type        = string
  default     = "GOVERNANCE"
}

variable "object_lock_days" {
  description = "Default retention in days for Object Lock"
  type        = number
  default     = 30
}

############################
# Lifecycle rules
############################
variable "enable_lifecycle" {
  description = "Enable lifecycle rules on the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_prefix" {
  description = "Optional object prefix filter for the lifecycle rule (empty = whole bucket)"
  type        = string
  default     = ""
}

variable "transition_to_ia_days" {
  description = "Days after creation to transition to STANDARD_IA"
  type        = number
  default     = 30
}

variable "transition_to_glacier_days" {
  description = "Days after creation to transition to GLACIER"
  type        = number
  default     = 90
}

variable "expire_after_days" {
  description = "Days after creation to permanently delete current objects"
  type        = number
  default     = 365
}

variable "noncurrent_transition_days" {
  description = "Days after becoming noncurrent to transition old versions to GLACIER"
  type        = number
  default     = 30
}

variable "noncurrent_expire_days" {
  description = "Days after becoming noncurrent to delete old versions"
  type        = number
  default     = 365
}

variable "abort_multipart_days" {
  description = "Abort incomplete multipart uploads after N days"
  type        = number
  default     = 7
}

############################
# Cross-Region Replication (CRR)
############################
variable "enable_crr" {
  description = "Enable cross-region replication from source bucket to a destination bucket"
  type        = bool
  default     = true
}

variable "dest_region" {
  description = "Destination region for the replica bucket"
  type        = string
  default     = "us-west-2"
}

variable "dest_bucket_name" {
  description = "Destination bucket name for replication (null -> <bucket_name>-replica)"
  type        = string
  default     = null
}

variable "replica_storage_class" {
  description = "Storage class for replicas"
  type        = string
  default     = "STANDARD"
  validation {
    condition = contains(
      [
        "STANDARD", "STANDARD_IA", "ONEZONE_IA",
        "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE"
      ],
      var.replica_storage_class
    )
    error_message = "replica_storage_class must be a valid S3 storage class."
  }
}

variable "replica_prefix" {
  description = "Only replicate objects with this prefix (empty = all)"
  type        = string
  default     = ""
}

# Cross-account destination (leave empty if same account)
variable "dest_account_id" {
  description = "12-digit AWS account ID that owns the destination bucket (empty = same account)"
  type        = string
  default     = ""
}

############################
# Storage Class Analysis (Analytics)
############################
variable "enable_storage_class_analysis" {
  description = "Enable S3 Storage Class Analysis on the source bucket"
  type        = bool
  default     = true
}

variable "enable_analytics_exports" {
  description = "Export Storage Class Analysis results to an S3 bucket as CSV"
  type        = bool
  default     = true
}

variable "analytics_prefix" {
  description = "Optional prefix scope for analytics (empty = whole bucket)"
  type        = string
  default     = ""
}

variable "analytics_tags" {
  description = "Optional tag filter for analytics"
  type        = map(string)
  default     = {}
}

variable "dest_role_arn" {
  description = "IAM role ARN to assume in the destination account for cross-account replication"
  type        = string
  default     = null
}

# S3 Transfer Acceleration
variable "enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration for bucket"
  type        = bool
  default     = false
}