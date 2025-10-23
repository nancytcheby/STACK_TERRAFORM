
bucket_name      = "stack-buck3-nancy"
dest_bucket_name = "stack-buck3-nancy-replica-083587468058"
region           = "us-east-1"
dest_region      = "us-west-2"
enable_crr       = true

# Cross-account specifics
dest_account_id = "083587468058"
dest_role_arn   = "arn:aws:iam::083587468058:role/engineer"