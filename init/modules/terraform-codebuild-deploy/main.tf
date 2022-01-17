# This template creates an S3 bucket and a role with access to share with other AWS account ARNS.  By default the current account id (assumed to be your main account) is added to the list of ARNS to able assume the role (even though it is unnecessary, since it has access through another seperate policy) and access the bucket to demonstrate the role, but other account ID's / ARNS can be listed as well.

provider "aws" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  common_tags = var.common_tags
  # bucket_name = var.bucketlogs_bucket
}

# # See https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa for the origin of some of this code.

# resource "aws_s3_bucket" "log_bucket" {
#   bucket = local.bucket_name
#   acl    = "log-delivery-write"
#   versioning {
#     enabled = true
#   }
#   # Enable server-side encryption by default
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

data "aws_vpc" "primary" {
  default = false
  tags    = var.common_tags
}
data "aws_internet_gateway" "gw" {
  tags = var.common_tags
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.primary.id
  tags   = map("area", "public")
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id       = each.value
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.primary.id
  tags   = map("area", "private")
}

data "aws_subnet" "private" {
  for_each = data.aws_subnet_ids.private.ids
  id       = each.value
}

variable "bucket_extension" {
  type = string
  description = "The suffix used to generate the bucket name for the codebuild cache."
}

resource "aws_s3_bucket" "deployer_cache" {
  bucket = "deployer_cache.${var.bucket_extension}"
  acl    = "private"
}

resource "aws_iam_role" "firehawk_codebuild_deployer_role" {
  name = "firehawk_codebuild_deployer_role"

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

resource "aws_iam_role_policy" "firehawk_codebuild_deployer_policy" {
  role = aws_iam_role.firehawk_codebuild_deployer_role.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:Subnet": "${tolist(data.aws_subnet_ids.private.arn)}",
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.deployer_cache.arn}",
        "${aws_s3_bucket.deployer_cache.arn}/*"
      ]
    }
  ]
}
POLICY
}

# resource "aws_codebuild_project" "firehawk_deployer" {
#   name          = "firehawk-deployer"
#   description   = "firehawk_deployer_project"
#   build_timeout = "5"
#   service_role  = aws_iam_role.firehawk_codebuild_deployer_role.arn

#   artifacts {
#     type = "NO_ARTIFACTS"
#   }

#   cache {
#     type     = "S3"
#     location = aws_s3_bucket.deployer_cache.bucket
#   }

#   environment {
#     compute_type                = "BUILD_GENERAL1_SMALL"
#     image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
#     # type                        = "LINUX_CONTAINER"
#     image_pull_credentials_type = "CODEBUILD"

#     # environment_variable {
#     #   name  = "SOME_KEY1"
#     #   value = "SOME_VALUE1"
#     # }

#     # environment_variable {
#     #   name  = "SOME_KEY2"
#     #   value = "SOME_VALUE2"
#     #   type  = "PARAMETER_STORE"
#     # }
#   }

#   logs_config {
#     cloudwatch_logs {
#       group_name  = "firehawk-deploy"
#       # stream_name = "log-stream"
#     }
#   }

#   source {
#     type            = "GITHUB"
#     location        = "https://github.com/firehawkvfx/firehawk.git"
#     git_clone_depth = 1

#     git_submodules_config {
#       fetch_submodules = false
#     }
#   }

#   source_version = "dev"

#   vpc_config {
#     vpc_id = data.aws_vpc.primary.id

#     subnets = data.aws_subnet_ids.public.ids

#     # security_group_ids = [
#     #   aws_security_group.example1.id,
#     #   aws_security_group.example2.id,
#     # ]
#   }

#   # tags = {
#   #   Environment = "Test"
#   # }
# }


# variable "vpc_id" {}
# variable "public_subnets" {}
# variable "private_subnets" {}

# resource "aws_codebuild_project" "project-with-cache" {
#   name           = "test-project-cache"
#   description    = "test_codebuild_project_cache"
#   build_timeout  = "5"
#   queued_timeout = "5"

#   service_role = aws_iam_role.example.arn

#   artifacts {
#     type = "NO_ARTIFACTS"
#   }

#   cache {
#     type  = "LOCAL"
#     modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
#   }

#   environment {
#     compute_type                = "BUILD_GENERAL1_SMALL"
#     image                       = "aws/codebuild/standard:1.0"
#     type                        = "LINUX_CONTAINER"
#     image_pull_credentials_type = "CODEBUILD"

#     environment_variable {
#       name  = "SOME_KEY1"
#       value = "SOME_VALUE1"
#     }
#   }

#   source {
#     type            = "GITHUB"
#     location        = "https://github.com/mitchellh/packer.git"
#     git_clone_depth = 1
#   }

#   tags = {
#     Environment = "Test"
#   }
# }