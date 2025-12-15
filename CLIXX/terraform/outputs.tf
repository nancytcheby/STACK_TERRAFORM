# Output the Clixx DB identifier and endpoint
output "clixx_db_identifier" {
  description = "Identifier of the restored Clixx database"
  value       = length(aws_db_instance.clixx_db) > 0 ? aws_db_instance.clixx_db[0].id : null
}

output "clixx_db_endpoint" {
  description = "Endpoint address of the restored Clixx database"
  value       = length(aws_db_instance.clixx_db) > 0 ? aws_db_instance.clixx_db[0].address : null
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

# Key Pair outputs (Story: Key Pair)

output "clixx_key_pair_name" {
  description = "Name of the EC2 key pair for Clixx"
  value       = aws_key_pair.clixx_key.key_name
}

# Private key PEM is managed externally (clixx-key.pem file)
# -----------------------
# Load Balancer outputs (Story 6)
# -----------------------

output "clixx_alb_arn" {
  description = "ARN of the Clixx Application Load Balancer"
  value       = aws_lb.clixx_alb.arn
}

output "clixx_alb_dns_name" {
  description = "DNS name of the Clixx ALB to use in Route53 CNAME"
  value       = aws_lb.clixx_alb.dns_name
}

# -----------------------
# Auto Scaling Group outputs (Story: ASG)
# -----------------------

output "clixx_asg_name" {
  description = "Name of the Clixx Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.name
}

output "clixx_asg_arn" {
  description = "ARN of the Clixx Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.arn
}

output "clixx_asg_desired_capacity" {
  description = "Desired capacity of the Clixx ASG"
  value       = aws_autoscaling_group.clixx_asg.desired_capacity
}
# Bootstrap outputs (Story 7)

output "clixx_bootstrap_user_data_b64" {
  description = "Base64-encoded user data for use in Launch Template"
  value       = local.clixx_bootstrap_user_data_b64
  sensitive   = true
}

# SSH Key outputs
output "clixx_key_private_pem" {
  description = "Private key PEM content for SSH access to instances"
  value       = tls_private_key.clixx_key.private_key_pem
  sensitive   = true
}

# Instance IDs for Inspector scanning
output "clixx_instance_ids" {
  description = "List of EC2 instance IDs in the ASG"
  value       = data.aws_instances.clixx_asg_instances.ids
}

# VPC ID output
output "clixx_vpc_id" {
  description = "VPC ID used by Clixx infrastructure"
  value       = local.vpc_id
}

# Subnet IDs outputs
output "clixx_public_subnet_ids" {
  description = "Public subnet IDs"
  value       = local.public_subnet_ids
}

output "clixx_private_subnet_ids" {
  description = "Private subnet IDs"
  value       = local.private_subnet_ids
}