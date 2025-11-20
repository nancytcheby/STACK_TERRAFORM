data "aws_caller_identity" "current" {}
# Output the current AWS account ID and assumed role ARN
output "current_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "current_assumed_role_arn" {
  value = data.aws_caller_identity.current.arn
}

# Output the Clixx DB identifier and endpoint
output "clixx_db_identifier" {
  description = "Identifier of the restored Clixx database"
  value       = aws_db_instance.clixx_db.id
}

output "clixx_db_endpoint" {
  description = "Endpoint address of the restored Clixx database"
  value       = aws_db_instance.clixx_db.address
}
# Output the security group ID used by the Clixx DB
output "clixx_db_security_group_id" {
  description = "Security group ID used by the Clixx DB"
  value       = aws_security_group.clixx_db_sg.id
}

# EFS outputs (Story 2)

output "clixx_efs_id" {
  description = "ID of the Clixx EFS file system"
  value       = aws_efs_file_system.clixx_efs.id
}

output "clixx_efs_mount_target_ids" {
  description = "IDs of the EFS mount targets for Clixx"
  value       = [for mt in aws_efs_mount_target.clixx_efs_mt : mt.id]
}

# Target Group outputs (Story 4)

output "clixx_target_group_arn" {
  description = "ARN of the Clixx Target Group"
  value       = aws_lb_target_group.clixx_tg.arn
}

output "clixx_target_group_name" {
  description = "Name of the Clixx Target Group"
  value       = aws_lb_target_group.clixx_tg.name
}

# -----------------------
# Load Balancer outputs (Story 5)
# -----------------------

output "clixx_alb_arn" {
  description = "ARN of the Clixx Application Load Balancer"
  value       = aws_lb.clixx_alb.arn
}

output "clixx_alb_dns_name" {
  description = "DNS name of the Clixx ALB to use in Route53 CNAME"
  value       = aws_lb.clixx_alb.dns_name
}
