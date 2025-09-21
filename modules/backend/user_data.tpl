#!/bin/bash
set -euo pipefail
yum update -y || true
yum install -y docker unzip mysql amazon-ssm-agent || true
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

DB_HOST="${db_endpoint}"
DB_NAME="${db_name}"
DB_USER="appuser"
DB_PASS='${db_password}'

# Initialize schema if needed
cat > /tmp/bootstrap.sql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE TABLE IF NOT EXISTS \`$DB_NAME\`.users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
SQL
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" < /tmp/bootstrap.sql || true

# Login to ECR and run backend container with DB env
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY_HOST"
docker pull "$REPO_URI:$IMAGE_TAG"
docker rm -f backend || true
docker run -d --name backend --restart unless-stopped -p 80:80 \
  -e DB_HOST="$DB_HOST" -e DB_NAME="$DB_NAME" -e DB_USER="$DB_USER" -e DB_PASS="$DB_PASS" \
  "$REPO_URI:$IMAGE_TAG"
