#!/bin/bash
# ECS-Optimized AMI Setup Script

# Update system packages
sudo yum update -y

# Install additional utilities
sudo yum install -y git wget curl unzip jq

# Install AWS CLI v2 (if not present)
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install CloudWatch agent
sudo yum install -y amazon-cloudwatch-agent

# ECS agent configuration (ECS-optimized AMI already has this, but ensure it's configured)
sudo systemctl enable ecs
sudo systemctl start ecs

# Docker is already installed on ECS-optimized AMI, ensure it's running
sudo systemctl enable docker
sudo systemctl start docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Install SSM agent for Systems Manager access
sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# Configure system settings for containers
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Set TCP keepalive settings for better container networking
sudo /sbin/sysctl -w net.ipv4.tcp_keepalive_time=200 net.ipv4.tcp_keepalive_intvl=200 net.ipv4.tcp_keepalive_probes=5

# Clean up
sudo yum clean all
sudo rm -rf /var/cache/yum

echo "ECS-Optimized AMI setup complete!"
