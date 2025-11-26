resource "aws_db_instance" "clixx_db" {
  identifier = "clixx-db-dev"

  # Restore from existing snapshot
  snapshot_identifier = var.clixx_db_snapshot_identifier

  instance_class = var.clixx_db_instance_class

  # Network configuration
  db_subnet_group_name   = var.clixx_db_subnet_group_name

  vpc_security_group_ids = [
    aws_security_group.clixx_db_sg.id
  ]

  # General settings
  apply_immediately   = true
  skip_final_snapshot = true
  publicly_accessible = true
}

