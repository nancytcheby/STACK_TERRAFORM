# -----------------------------------------
# Story 2: Create EFS for Clixx in Dev
# -----------------------------------------

# EFS file system
resource "aws_efs_file_system" "clixx_efs" {
  creation_token = var.clixx_efs_name
  encrypted      = true
  throughput_mode = "bursting"

  tags = {
    Name = var.clixx_efs_name
  }
}

# EFS mount targets in the specified subnets
resource "aws_efs_mount_target" "clixx_efs_mt" {
  for_each = toset(var.clixx_efs_subnet_ids)

  file_system_id = aws_efs_file_system.clixx_efs.id
  subnet_id      = each.value
  security_groups = [
    aws_security_group.clixx_db_sg.id
  ]
}
