#!/bin/bash
set -euo pipefail
yum update -y || true
yum install -y docker unzip amazon-ssm-agent || true
# Install AWS CLI v2
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q -o /tmp/awscliv2.zip -d /tmp
/tmp/aws/install || true
systemctl enable docker
systemctl start docker
systemctl enable amazon-ssm-agent || true
systemctl start amazon-ssm-agent || true

AWS_REGION="${aws_region}"
REPO_URI="${ecr_repo_uri}"
IMAGE_TAG="${image_tag}"
REGISTRY_HOST="$(echo "$REPO_URI" | cut -d'/' -f1)"

# Login to ECR and pull image
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_HOST"
docker pull "$REPO_URI:$IMAGE_TAG"

# Run frontend container
docker rm -f frontend || true
docker run -d --name frontend --restart unless-stopped -p 80:80 "$REPO_URI:$IMAGE_TAG"

# Health file (in case container not ready, ensure ALB can check)
echo OK > /root/health || true
