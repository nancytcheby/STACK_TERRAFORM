resource "aws_db_instance" "clixx_db" {
  identifier = "clixx-db-dev"

  # STORY 1: restore from an existing snapshot
  snapshot_identifier = var.clixx_db_snapshot_identifier

  instance_class = var.clixx_db_instance_class

  # Network configuration
  db_subnet_group_name   = var.clixx_db_subnet_group_name
  vpc_security_group_ids = var.clixx_db_security_group_ids

  # General settings
  apply_immediately  = true
  skip_final_snapshot = true
  publicly_accessible = true
}
