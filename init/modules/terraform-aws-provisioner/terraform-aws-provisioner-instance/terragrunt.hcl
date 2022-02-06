include {
  path = find_in_parent_folders()
}

locals {
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = merge(
  local.common_vars.inputs,
  {
    "vpc_cidr" : dependency.data.outputs.vpc_cidr
  }
) 

dependencies {
  paths = [
    "../data"
    ]
}