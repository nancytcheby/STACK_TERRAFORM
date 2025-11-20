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

