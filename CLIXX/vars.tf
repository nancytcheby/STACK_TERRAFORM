variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "engineer_role_arn" {
  description = "IAM Role ARN in the DEV account that Terraform will assume"
  type        = string
}

variable "clixx_db_snapshot_identifier" {
  description = "Snapshot ID to restore the Clixx database from"
  type        = string
}

variable "clixx_db_instance_class" {
  description = "Instance class for the restored Clixx DB"
  type        = string
  default     = "db.t3.micro"
}

variable "clixx_db_subnet_group_name" {
  description = "Existing DB subnet group name to use for the Clixx DB"
  type        = string
}

variable "clixx_vpc_id" {
  description = "VPC ID where Clixx DB will be created"
  type        = string
}

variable "clixx_db_allowed_cidr" {
  description = "CIDR block allowed to connect to the Clixx DB on port 3306"
  type        = string
}
