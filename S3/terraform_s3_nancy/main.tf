# CONTROL_SCRIPT_TERRAFORM:

# Creating_and_Configuring_an_S3_Bucket_Nancy_Tcheby_v1.0

#######################
#Create the S3 bucket
#######################

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    {
      Project = "S3-Terraform-Demo"
      Owner   = var.owner
    },
    var.bucket_tags
  )
}

# 2) Ownership controls
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 3) Block public access by default
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  # Keep ACLs blocked; we’ll use a bucket policy if making the website public
  block_public_acls  = true
  ignore_public_acls = true

  # If hosting a public website via bucket policy, these must be false
  block_public_policy     = var.enable_website && var.make_website_public ? false : true
  restrict_public_buckets = var.enable_website && var.make_website_public ? false : true
}

# CONTROL_SCRIPT_TERRAFORM: Enable_Transfer_Acceleration_Nancy_Tcheby_v1.0
resource "aws_s3_bucket_accelerate_configuration" "this" {
  count  = var.enable_transfer_acceleration ? 1 : 0
  bucket = aws_s3_bucket.this.id
  status = "Enabled"
}


# CONTROL_SCRIPT_TERRAFORM: Enabling_Versioning_and_Default_Encryption_Nancy_Tcheby_v1.0

#######################
# 4) Versioning
########################
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# 5) Default encryption for new objects
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.default_encryption == "none" ? 0 : 1
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.default_encryption == "aws:kms" ? "aws:kms" : "AES256"
      kms_master_key_id = var.default_encryption == "aws:kms" ? var.kms_key_arn : null
    }
  }
}

# CONTROL_SCRIPT_TERRAFORM: Enabling_Server_Access_and_Object_Level_Logging_Nancy_Tcheby_v1.0

#######################
# server access logging
########################
locals {
  resolved_log_bucket = coalesce(var.log_bucket_name, "${var.bucket_name}-logs")
}

# 1) Dedicated log bucket (only if enabled)
resource "aws_s3_bucket" "logs" {
  count  = var.enable_server_access_logging ? 1 : 0
  bucket = local.resolved_log_bucket

  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
    Type    = "AccessLogs"
  }
}

# 2) Ownership controls for the log bucket
resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.enable_server_access_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 3) Block public access on the log bucket
resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = var.enable_server_access_logging ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4) ACL so S3 can deliver logs into the log bucket
resource "aws_s3_bucket_acl" "logs" {
  count      = var.enable_server_access_logging ? 1 : 0
  bucket     = aws_s3_bucket.logs[0].id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

# 5) Enable logging on your main bucket
resource "aws_s3_bucket_logging" "this" {
  count         = var.enable_server_access_logging ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = var.log_prefix
}

#########################
# Object-level logging
#########################

# Who am I? 
data "aws_caller_identity" "current" {}

# Decide the CloudTrail log bucket name
locals {
  trail_log_bucket = coalesce(var.trail_log_bucket_name, "${var.bucket_name}-ct-logs")
}

# 1) CloudTrail log bucket (only if enabled)
resource "aws_s3_bucket" "cloudtrail_logs" {
  count  = var.enable_object_level_logging ? 1 : 0
  bucket = local.trail_log_bucket

  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
    Type    = "CloudTrailLogs"
  }
}

# 2) Keeping the log bucket private
resource "aws_s3_bucket_ownership_controls" "cloudtrail_logs" {
  count  = var.enable_object_level_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  count                   = var.enable_object_level_logging ? 1 : 0
  bucket                  = aws_s3_bucket.cloudtrail_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3) Bucket policy allowing CloudTrail to deliver logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  count  = var.enable_object_level_logging ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AWSCloudTrailWrite",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:PutObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs[0].id}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "AWSCloudTrailAclCheck",
        Effect    = "Allow",
        Principal = { Service = "cloudtrail.amazonaws.com" },
        Action    = "s3:GetBucketAcl",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs[0].id}"
      }
    ]
  })
  depends_on = [aws_s3_bucket_ownership_controls.cloudtrail_logs]
}

# 4) CloudTrail trail with S3 OBJECT data events
resource "aws_cloudtrail" "s3_object_data_events" {
  count                         = var.enable_object_level_logging ? 1 : 0
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs[0].id
  is_multi_region_trail         = false
  include_global_service_events = false
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false
    data_resource {
      type = "AWS::S3::Object"
      # Trailing slash means "all objects under this bucket"
      values = ["arn:aws:s3:::${aws_s3_bucket.this.id}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# CONTROL_SCRIPT_TERRAFORM: Configuring_Static_Website_Hosting_and_Redirects_Requests_Nancy_Tcheby_v1.0

#########################
# Static website hosting
##########################

resource "aws_s3_bucket_website_configuration" "static" {
  count  = var.enable_website && var.website_redirect_host == null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.website_index
  }
  error_document {
    key = var.website_error
  }
}
#######################################
# Redirect ALL requests to another host
########################################

resource "aws_s3_bucket_website_configuration" "redirect" {
  count  = var.enable_website && var.website_redirect_host != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  redirect_all_requests_to {
    host_name = var.website_redirect_host

  }
}

# Adding public read access ( for testing/demo purposes only)

resource "aws_s3_bucket_policy" "website_public_read" {
  count  = var.enable_website && var.make_website_public ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowPublicReadForWebsite",
      Effect    = "Allow",
      Principal = "*",
      Action    = "s3:GetObject",
      Resource  = "arn:aws:s3:::${aws_s3_bucket.this.id}/*"
    }]
  })
}

# CONTROL_SCRIPT_TERRAFORM: Enabling_Event_Notifications_Nancy_Tcheby_v1.0

####################################################
# Set Up a Destination to Receive Event Notifications
#####################################################

# SQS Queue to receive event notifications
resource "aws_sqs_queue" "s3_events" {
  count                      = var.enable_event_notifications ? 1 : 0
  name                       = "${var.bucket_name}-s3-events"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30
  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
  }
}

# Allow S3 to send messages to the queue
resource "aws_sqs_queue_policy" "allow_s3" {
  count     = var.enable_event_notifications ? 1 : 0
  queue_url = aws_sqs_queue.s3_events[0].url
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3SendMessage",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.s3_events[0].arn,
        Condition = {
          ArnEquals = { "aws:SourceArn" = "arn:aws:s3:::${aws_s3_bucket.this.id}" }
        }
      }
    ]
  })
}

# S3 bucket notification → SQS
resource "aws_s3_bucket_notification" "this" {
  count  = var.enable_event_notifications ? 1 : 0
  bucket = aws_s3_bucket.this.id

  queue {
    queue_arn     = aws_sqs_queue.s3_events[0].arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix = length(var.notify_prefix) > 0 ? var.notify_prefix : null
    filter_suffix = length(var.notify_suffix) > 0 ? var.notify_suffix : null
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}
#########################
# Object Lock Bucket
#########################

locals {
  object_lock_bucket = coalesce(var.object_lock_bucket_name, "${var.bucket_name}-olock")
}

resource "aws_s3_bucket" "object_lock" {
  count               = var.enable_object_lock ? 1 : 0
  bucket              = local.object_lock_bucket
  object_lock_enabled = true

  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
    Type    = "ObjectLockDemo"
  }
}

resource "aws_s3_bucket_ownership_controls" "object_lock" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.object_lock[0].id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_public_access_block" "object_lock" {
  count                   = var.enable_object_lock ? 1 : 0
  bucket                  = aws_s3_bucket.object_lock[0].id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "object_lock" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.object_lock[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "object_lock_default" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.object_lock[0].id
  rule {
    default_retention {
      mode = var.object_lock_mode # GOVERNANCE or COMPLIANCE
      days = var.object_lock_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.object_lock]
}

###########################################################################
# CONTROL_SCRIPT_TERRAFORM: Lifecycle_Rules_for_S3_Bucket_Nancy_Tcheby_v1.0
###########################################################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "standard-lifecycle"
    status = "Enabled"

    # Filter by prefix if provided; empty string = whole bucket
    filter {
      prefix = var.lifecycle_prefix
    }

    # Transition current objects to cheaper storage over time
    transition {
      days          = var.transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.transition_to_glacier_days
      storage_class = "GLACIER"
    }

    # Expire current objects completely after N days
    expiration {
      days = var.expire_after_days
    }

    # Manage noncurrent (old) versions
    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_transition_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expire_days
    }

    # Housekeeping for abandoned uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_multipart_days
    }
  }
}

############################################
# CONTROL_SCRIPT_TERRAFORM:
# Cross_Region_Replication_Nancy_Tcheby_v1.0
############################################

# Resolve destination bucket name
locals {
  replica_bucket = coalesce(var.dest_bucket_name, "${var.bucket_name}-replica")
}

# ---- Destination bucket in replica region ----
resource "aws_s3_bucket" "replica" {
  count    = var.enable_crr ? 1 : 0
  provider = aws.replica
  bucket   = local.replica_bucket
  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
    Type    = "Replica"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_crr ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id
  versioning_configuration { status = "Enabled" }
}

# ---- Replication role & policy (same-account by default; extend for KMS if needed) ----
data "aws_iam_policy_document" "replication_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = var.enable_crr ? 1 : 0
  name               = "${var.bucket_name}-replication-role"
  assume_role_policy = data.aws_iam_policy_document.replication_trust.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }
  statement {
    actions   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
  statement {
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"]
    resources = ["${aws_s3_bucket.replica[0].arn}/*"]
  }
  # If using KMS, add source Decrypt/Describe and destination Encrypt/ReEncrypt/GenerateDataKey here.
}

resource "aws_iam_policy" "replication" {
  count  = var.enable_crr ? 1 : 0
  name   = "${var.bucket_name}-replication-policy"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.enable_crr ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

# ---- Replication configuration (works for same-account & cross-account) ----
resource "aws_s3_bucket_replication_configuration" "this" {
  count  = var.enable_crr ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-to-${local.replica_bucket}"
    status = "Enabled"

    dynamic "filter" {
      for_each = length(var.replica_prefix) > 0 ? [1] : []
      content { prefix = var.replica_prefix }
    }

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = var.replica_storage_class

      # Set account ONLY when cross-account (empty string means same-account)
      account = var.dest_account_id != "" ? var.dest_account_id : null

      # Required for cross-account. Make it conditional so same-account stays valid.
      dynamic "access_control_translation" {
        for_each = var.dest_account_id != "" ? [1] : []
        content { owner = "Destination" }
      }

      # If destination uses KMS, set and grant perms on that key:
      # replica_kms_key_id = var.replica_kms_key_arn
    }

  }

  depends_on = [
    aws_s3_bucket_versioning.this,
    aws_s3_bucket_versioning.replica,
    aws_s3_bucket_policy.replica_allow_replication, # count=0 for same-account is fine
  ]
}

# ---- Destination bucket policy: ONLY for cross-account ----
resource "aws_s3_bucket_policy" "replica_allow_replication" {
  count    = var.enable_crr && var.dest_account_id != "" ? 1 : 0
  provider = aws.replica
  bucket   = aws_s3_bucket.replica[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowReplicationFromSourceAccountRole",
        Effect    = "Allow",
        Principal = { AWS = aws_iam_role.replication[0].arn }, # role in SOURCE account
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner",
          "s3:PutObjectAcl"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.replica[0].id}/*"
      }
    ]
  })
}




#########################
# Storage Class Analysis
#########################

resource "aws_s3_bucket" "analytics_export" {
  count  = var.enable_analytics_exports ? 1 : 0
  bucket = "${var.bucket_name}-analytics"
  tags = {
    Project = "S3-Terraform-Demo"
    Owner   = var.owner
    Type    = "S3Analytics"
  }
}

# Analytics configuration on the SOURCE bucket
resource "aws_s3_bucket_analytics_configuration" "default" {
  count  = var.enable_storage_class_analysis ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "default-analysis"

  # Optional scope (by prefix and/or tags)
  dynamic "filter" {
    for_each = (try(length(var.analytics_prefix), 0) > 0 || try(length(var.analytics_tags), 0) > 0) ? [1] : []
    content {
      prefix = try(var.analytics_prefix, null)
      tags   = try(var.analytics_tags, null) # map(string), e.g. { env = "prod" }
    }
  }

  # Optional: export analytics results to S3 as CSV
  dynamic "storage_class_analysis" {
    for_each = var.enable_analytics_exports ? [1] : []
    content {
      data_export {
        destination {
          s3_bucket_destination {
            bucket_arn = aws_s3_bucket.analytics_export[0].arn
            format     = "CSV"
            prefix     = "reports/"
          }
        }
        output_schema_version = "V_1"
      }
    }
  }
}