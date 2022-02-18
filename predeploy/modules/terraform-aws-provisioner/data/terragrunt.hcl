include {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

dependencies {
  paths = [
    "../../terraform-aws-instance-key-pair"
  ]
}

inputs = local.common_vars.inputs