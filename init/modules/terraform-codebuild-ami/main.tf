# This template creates an S3 bucket and a role with access to share with other AWS account ARNS.  By default the current account id (assumed to be your main account) is added to the list of ARNS to able assume the role (even though it is unnecessary, since it has access through another seperate policy) and access the bucket to demonstrate the role, but other account ID's / ARNS can be listed as well.

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

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

# data "aws_vpc" "primary" {
#   default = false
#   tags    = var.common_tags
# }

# data "aws_subnets" "public" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.primary.id]
#   }
#   tags = {
#     area = "public"
#   }
# }
# data "aws_subnet" "public" {
#   for_each = toset(data.aws_subnets.public.ids)
#   id       = each.value
# }
# data "aws_subnets" "private" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.primary.id]
#   }
#   tags = {
#     area = "private"
#   }
# }
# data "aws_subnet" "private" {
#   for_each = toset(data.aws_subnets.private.ids)
#   id       = each.value
# }

locals {
  common_tags        = var.common_tags
  extra_tags         = { "role" : "codebuild" }
  # public_subnet_arns = "[ ${join(",", [for s in data.aws_subnet.public : format("%q", s.arn)])} ]"
  log_group          = "firehawk-codebuild-ami"
}

# resource "aws_security_group" "codebuild_ami" {
#   name        = "codebuild-ami"
#   vpc_id      = data.aws_vpc.primary.id
#   description = "CodeBuild Deployer Security Group"
#   tags        = merge(tomap({ "Name" : "codebuild-ami" }), var.common_tags, local.extra_tags)

#   egress {
#     protocol    = "-1"
#     from_port   = 0
#     to_port     = 0
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "all outgoing traffic"
#   }
# }

resource "aws_s3_bucket" "codebuild_cache" {
  bucket = "amibuild-cache.${var.bucket_extension}"
}

resource "aws_s3_bucket_acl" "acl_config" {
  bucket = aws_s3_bucket.codebuild_cache.id
  acl    = "private"
}

resource "aws_iam_role" "firehawk_codebuild_ami_role" {
  name = "CodeBuildAmiBuildRoleFirehawk"
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
  name   = "CodeBuildServicePolicyFirehawkBuildAmi"
  role   = aws_iam_role.firehawk_codebuild_ami_role.name
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


# resource "aws_iam_role_policy" "firehawk_codebuild_ami_policy" {
#   role = aws_iam_role.firehawk_codebuild_ami_role.name

#   policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Resource": [
#         "*"
#       ],
#       "Action": [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ]
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "ec2:CreateNetworkInterface",
#         "ec2:DescribeDhcpOptions",
#         "ec2:DescribeNetworkInterfaces",
#         "ec2:DeleteNetworkInterface",
#         "ec2:DescribeSubnets",
#         "ec2:DescribeSecurityGroups",
#         "ec2:DescribeVpcs"
#       ],
#       "Resource": "*"
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "ec2:CreateNetworkInterfacePermission"
#       ],
#       "Resource": [
#         "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*"
#       ],
#       "Condition": {
#         "StringEquals": {
#           "ec2:Subnet": ${local.public_subnet_arns},
#           "ec2:AuthorizedService": "codebuild.amazonaws.com"
#         }
#       }
#     },
#     {
#       "Effect": "Allow",
#       "Action": [
#         "s3:*"
#       ],
#       "Resource": [
#         "${aws_s3_bucket.codebuild_cache.arn}",
#         "${aws_s3_bucket.codebuild_cache.arn}/*"
#       ]
#     }
#   ]
# }
# POLICY
# }

resource "aws_codebuild_webhook" "git_push" {
  project_name = aws_codebuild_project.firehawk_amibuild.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "main"
    }
  }
}

resource "aws_codebuild_project" "firehawk_amibuild" {
  name                   = "firehawk-amibuild"
  description            = "firehawk_amibuild_project"
  build_timeout          = "90"
  service_role           = aws_iam_role.firehawk_codebuild_ami_role.arn
  concurrent_build_limit = 1
  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild_cache.bucket
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    # image                       = "public.ecr.aws/n0r4f8d0/test-repo"
    # image                       = "aws/codebuild/standard:1.0"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # environment_variable {
    #   name  = "TF_VAR_deployer_sg_id"
    #   value = aws_security_group.codebuild_ami.id
    # }

    # environment_variable {
    #   name  = "TF_VAR_vpc_id_main_provisioner"
    #   value = data.aws_vpc.primary.id
    # }

  }
  logs_config {
    cloudwatch_logs {
      group_name = local.log_group
      # stream_name = "log-stream"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/firehawkvfx/packer-firehawk-amis.git"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = "main"

  # vpc_config {
  #   vpc_id = data.aws_vpc.primary.id

  #   subnets = toset(data.aws_subnets.private.ids)

  #   security_group_ids = [
  #     aws_security_group.codebuild_ami.id,
  #   ]
  # }
}
