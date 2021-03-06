# This template creates an S3 bucket and a role with access to share with other AWS account ARNS.  By default the current account id (assumed to be your main account) is added to the list of ARNS to able assume the role (even though it is unnecessary, since it has access through another seperate policy) and access the bucket to demonstrate the role, but other account ID's / ARNS can be listed as well.

provider "aws" {}

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(var.common_tags, { role = "cloudformation bucket" })
  bucket_name = var.cloudformation_bucket
  s3_bucket_domain_name = aws_s3_bucket.cloudformation_bucket.bucket_domain_name
}

# See https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa for the origin of some of this code.

resource "aws_s3_bucket" "cloudformation_bucket" {
  bucket = local.bucket_name
  # acl    = "log-delivery-write"
}

resource "aws_s3_bucket_versioning" "versioning_config" {
  bucket = aws_s3_bucket.cloudformation_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_config" {
  bucket = aws_s3_bucket.cloudformation_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "update_scripts" {
  for_each = fileset("${path.module}/templates/", "*")
  bucket   = aws_s3_bucket.cloudformation_bucket.id
  key      = each.value
  source   = "${path.module}/templates/${each.value}"
  etag     = filemd5("${path.module}/templates/${each.value}")
}