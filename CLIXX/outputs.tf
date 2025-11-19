data "aws_caller_identity" "current" {}

output "current_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "current_assumed_role_arn" {
  value = data.aws_caller_identity.current.arn
}

output "clixx_db_identifier" {
  description = "Identifier of the restored Clixx database"
  value       = aws_db_instance.clixx_db.id
}

output "clixx_db_endpoint" {
  description = "Endpoint address of the restored Clixx database"
  value       = aws_db_instance.clixx_db.address
}
