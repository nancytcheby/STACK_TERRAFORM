# --------------------------------------------------
# IAM POLICY — allow EC2 to read SSM from admin acct
# --------------------------------------------------
resource "aws_iam_policy" "clixx_cross_account_ssm_policy" {
  name        = "ClixxCrossAccountSSMPolicy"
  description = "Allow EC2 instances in Dev account to read SSM parameters in Admin account"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = [
          "arn:aws:ssm:us-east-1:135576900189:parameter/database/host",
          "arn:aws:ssm:us-east-1:135576900189:parameter/database/name",
          "arn:aws:ssm:us-east-1:135576900189:parameter/database/user",
          "arn:aws:ssm:us-east-1:135576900189:parameter/database/password",
          "arn:aws:ssm:us-east-1:135576900189:parameter/efs_id",
          "arn:aws:ssm:us-east-1:135576900189:parameter/Clixx_dns"
        ]
      }
    ]
  })

  tags = {
    Project = "Clixx"
    Env     = "dev"
  }
}

# --------------------------------------------------
# IAM ROLE — EC2 WordPress Role
# --------------------------------------------------
resource "aws_iam_role" "ec2_wordpress_role" {
  name = "EC2WordPressRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "Clixx"
    Env     = "dev"
  }
}

# --------------------------------------------------
# INSTANCE PROFILE — used by launch template
# --------------------------------------------------
resource "aws_iam_instance_profile" "ec2_wordpress_profile" {
  name = "EC2WordPressRole"
  role = aws_iam_role.ec2_wordpress_role.name

  tags = {
    Project = "Clixx"
    Env     = "dev"
  }
}

# --------------------------------------------------
# Attach AWS Managed Policy for SSM Agent
# --------------------------------------------------
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance" {
  role       = aws_iam_role.ec2_wordpress_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --------------------------------------------------
# Attach Cross-Account SSM Read Policy
# --------------------------------------------------
resource "aws_iam_role_policy_attachment" "clixx_cross_account_ssm_attachment" {
  role       = aws_iam_role.ec2_wordpress_role.name
  policy_arn = aws_iam_policy.clixx_cross_account_ssm_policy.arn
}

