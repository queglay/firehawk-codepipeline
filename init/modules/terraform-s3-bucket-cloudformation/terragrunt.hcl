include {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = local.common_vars.inputs
prevent_destroy = true

dependencies {
  paths = [
    "../terraform-s3-bucket-logs"
    ]
}

terraform {
  after_hook "after_hook_1" {
    commands = ["apply"]
    execute  = ["bash", "scripts/post-cloudformation"]
  }
}