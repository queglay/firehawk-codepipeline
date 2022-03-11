# This template creates an S3 bucket and a role with access to share with other AWS account ARNS.  By default the current account id (assumed to be your main account) is added to the list of ARNS to able assume the role (even though it is unnecessary, since it has access through another seperate policy) and access the bucket to demonstrate the role, but other account ID's / ARNS can be listed as well.

provider "aws" {
  #  if you haven't installed and configured the aws cli, you will need to provide your aws access key and secret key.
  # in a dev environment these version locks below can be disabled.  in production, they should be locked based on the suggested versions from terraform init.
  version = "~> 4.3.0"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# # See https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa for the origin of some of this code.

data "aws_vpc" "primary" {
  default = false
  tags    = var.common_tags
}
data "aws_internet_gateway" "gw" {
  tags = var.common_tags
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }
  tags = {
    area = "public"
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }
  tags = {
    area = "private"
  }
}
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

locals {
  common_tags        = var.common_tags
  extra_tags         = { "role" : "codebuild" }
  public_subnet_arns = "[ ${join(",", [for s in data.aws_subnet.public : format("%q", s.arn)])} ]"
  log_group = "firehawk-codebuild-createapp"
}

resource "aws_security_group" "codebuild_createapp" {
  name        = "codebuild-createapp"
  vpc_id      = data.aws_vpc.primary.id
  description = "CodeBuild Deployer Security Group"
  tags        = merge(tomap({ "Name" : "codebuild-createapp" }), var.common_tags, local.extra_tags)

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "all outgoing traffic"
  }
}

variable "bucket_extension" {
  type        = string
  description = "The suffix used to generate the bucket name for the codebuild cache."
}

resource "aws_s3_bucket" "codebuild_cache" {
  bucket = "createapp-cache.${var.bucket_extension}"
}

resource "aws_s3_bucket_acl" "acl_config" {
  bucket = aws_s3_bucket.codebuild_cache.id
  acl    = "private"
}

resource "aws_iam_role" "firehawk_codebuild_createapp_role" {
  name = "CodeBuildCreateAppRoleFirehawk"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_service_role_policy" {
  name   = "CodeBuildServicePolicyFirehawkCreateApp"
  role   = aws_iam_role.firehawk_codebuild_createapp_role.name
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:DescribeLogGroups",
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchLogsPolicy",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CodeCommitPolicy",
            "Effect": "Allow",
            "Action": [
                "codecommit:GitPull"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3GetObjectPolicy",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3PutObjectPolicy",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECRPullPolicy",
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECRAuthPolicy",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3BucketIdentity",
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_codebuild_project" "firehawk_createapp" {
  name                   = "firehawk-createapp"
  description            = "firehawk_createapp_project"
  build_timeout          = "90"
  service_role           = aws_iam_role.firehawk_codebuild_createapp_role.arn
  concurrent_build_limit = 1
  artifacts {
    type = "NO_ARTIFACTS" # may need BuildArtifact
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild_cache.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "public.ecr.aws/n0r4f8d0/test-repo"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_deployer_sg_id"
      value = aws_security_group.codebuild_createapp.id
    }

    environment_variable {
      name  = "TF_VAR_vpc_id_main_provisioner"
      value = data.aws_vpc.primary.id
    }

  }
  logs_config {
    cloudwatch_logs {
      group_name = local.log_group
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/firehawkvfx/firehawk.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = "main"

  vpc_config {
    vpc_id = data.aws_vpc.primary.id

    subnets = toset(data.aws_subnets.private.ids)

    security_group_ids = [
      aws_security_group.codebuild_createapp.id,
    ]
  }

}
