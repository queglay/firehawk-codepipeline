# This template creates an S3 bucket and a role with access to share with other AWS account ARNS.  By default the current account id (assumed to be your main account) is added to the list of ARNS to able assume the role (even though it is unnecessary, since it has access through another seperate policy) and access the bucket to demonstrate the role, but other account ID's / ARNS can be listed as well.

provider "aws" {
  #  if you haven't installed and configured the aws cli, you will need to provide your aws access key and secret key.
  # in a dev environment these version locks below can be disabled.  in production, they should be locked based on the suggested versions from terraform init.
  version = "~> 4.1.0"
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.common_tags, { role = "log bucket" })
  bucket_name = var.bucketlogs_bucket
}

# See https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa for the origin of some of this code.

resource "aws_s3_bucket" "log_bucket" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_acl" "acl_config" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_versioning" "versioning_config" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_config" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}