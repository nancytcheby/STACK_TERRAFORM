# IAM role for EC2 instances to access SSM, EFS, RDS, and other AWS services
resource "aws_iam_role" "ec2_access_role" {
  name_prefix = "EC2-Access-Role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "EC2-Access-Role"
    Environment = var.env
    Project     = "clixx"
  }
}


# IAM policy for EC2 instances
resource "aws_iam_role_policy" "ec2_access_policy" {
  name_prefix = "EC2-Access-Policy-"
  role        = aws_iam_role.ec2_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter",
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeInstanceAssociations",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2messages:*",
          "ssmmessages:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach custom cross-account SSM policy
resource "aws_iam_role_policy_attachment" "clixx_cross_account_ssm_attachment" {
  role       = aws_iam_role.ec2_access_role.name
  policy_arn = aws_iam_policy.clixx_cross_account_ssm_policy.arn
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_access_profile" {
  name_prefix = "EC2-Access-Profile-"
  role        = aws_iam_role.ec2_access_role.name

  tags = {
    Name        = "EC2-Access-Profile"
    Environment = var.env
    Project     = "clixx"
  }
}
