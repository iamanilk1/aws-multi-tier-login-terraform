locals {
  artifact_bucket_name = "${var.project_name}-cicd-artifacts-${data.aws_caller_identity.current.account_id}-${var.region}"
}

data "aws_caller_identity" "current" {}

# Use existing available connection instead of creating a new one
data "aws_codestarconnections_connection" "github" {
  arn = "arn:aws:codeconnections:ap-south-1:050702562028:connection/674bd67d-3ad6-492a-86d2-2734fde02e0c"
}

resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifact_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:PutObject","s3:GetObject","s3:GetObjectVersion","s3:GetBucketLocation","s3:ListBucket"], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability","ecr:CompleteLayerUpload","ecr:DescribeImages","ecr:DescribeRepositories","ecr:GetDownloadUrlForLayer","ecr:InitiateLayerUpload","ecr:PutImage","ecr:UploadLayerPart"], Resource = "*" },
      { Effect = "Allow", Action = ["autoscaling:StartInstanceRefresh","autoscaling:DescribeAutoScalingGroups","autoscaling:DescribeInstanceRefreshes"], Resource = "*" },
      { Effect = "Allow", Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:DescribeInstanceInformation"
        ], Resource = "*" }
    ]
  })
}

resource "aws_codebuild_project" "frontend" {
  name          = "${var.project_name}-frontend-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "ECR_REPO"
      value = var.ecr_repo_url
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "frontend-${var.image_tag}"
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec-frontend.yml")
  }
}

resource "aws_codebuild_project" "backend" {
  name          = "${var.project_name}-backend-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "ECR_REPO"
      value = var.ecr_repo_url
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "backend-${var.image_tag}"
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec-backend.yml")
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:PutObject","s3:GetObject","s3:GetObjectVersion","s3:GetBucketLocation","s3:ListBucket"], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"] },
      { Effect = "Allow", Action = ["codebuild:BatchGetBuilds","codebuild:StartBuild"], Resource = [aws_codebuild_project.frontend.arn, aws_codebuild_project.backend.arn] },
      { Effect = "Allow", Action = ["codestar-connections:UseConnection"], Resource = data.aws_codestarconnections_connection.github.arn }
    ]
  })
}

resource "aws_codepipeline" "pipeline_frontend" {
  name     = "${var.project_name}-frontend-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo_full_name
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build_Frontend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.frontend.name }
    }
  }
}

resource "aws_codepipeline" "pipeline_backend" {
  name     = "${var.project_name}-backend-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repo_full_name
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build_Backend"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.backend.name }
    }
  }
}

output "artifact_bucket" { value = aws_s3_bucket.artifacts.bucket }
output "pipeline_frontend_name" { value = aws_codepipeline.pipeline_frontend.name }
output "pipeline_backend_name" { value = aws_codepipeline.pipeline_backend.name }
output "github_connection_arn" { value = data.aws_codestarconnections_connection.github.arn }
