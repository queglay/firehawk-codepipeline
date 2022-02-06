# This is a module example of how to use data resources as variable inputs to other modules.
# See an example here https://github.com/gruntwork-io/terragrunt/issues/254

provider "aws" {}

data "aws_region" "current" {}
locals {
  common_tags = var.common_tags
}
data "aws_vpc" "primary" {
  default = false
  tags    = local.common_tags
}