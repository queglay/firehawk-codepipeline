### This role and profile allows instances access to S3 buckets to aquire and push back downloaded softwre to provision with.  It also has prerequisites for consul and vault access.
resource "aws_iam_role" "instance_role" {
  name               = var.provisioner_iam_profile_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge(var.common_tags, tomap({ "role" : "provisioner" }))
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]
}
resource "aws_iam_instance_profile" "instance_profile" {
  name = aws_iam_role.instance_role.name
  role = aws_iam_role.instance_role.name
}
data "aws_iam_policy_document" "assume_role" { # Determines the services able to assume the role.  Any entity assuming this role will be able to authenticate to vault.
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
# Policy Allowing Read and write access to S3
module "iam_policies_s3_read_write" {
  source      = "github.com/firehawkvfx/firehawk-main.git//modules/aws-iam-policies-s3-read-write"
  name        = "S3ReadWrite_${var.conflictkey}"
  iam_role_id = aws_iam_role.instance_role.id
}
# Policy to query the identity of the current role.  Required for Vault.
module "iam_policies_get_caller_identity" {
  source      = "github.com/firehawkvfx/firehawk-main.git//modules/aws-iam-policies-get-caller-identity"
  name        = "STSGetCallerIdentity_${var.conflictkey}"
  iam_role_id = aws_iam_role.instance_role.id
}
# Adds policies necessary for running Consul
module "consul_iam_policies_for_client" {
  source      = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.8.0"
  iam_role_id = aws_iam_role.instance_role.id
}
module "iam_policies_ssm_manage_channels" {
  source      = "github.com/firehawkvfx/firehawk-main.git//modules/aws-iam-policies-ssm-manage-channels"
  name        = "SSMManageChannels_${var.conflictkey}"
  iam_role_id = aws_iam_role.instance_role.id
}
module "iam_policies_provisioner_firehawk" {
  source      = "github.com/firehawkvfx/firehawk-main.git//modules/aws-iam-policies-provisioner-firehawk"
  name        = "ProvisionerFirehawk_${var.conflictkey}"
  iam_role_id = aws_iam_role.instance_role.id
}

data "aws_ssm_parameter" "vault_kms_token" {
  name = "/firehawk/resourcetier/${var.resourcetier}/vault_kms_token_key_id"
}

data "aws_kms_key" "vault_root_token" {
  key_id = data.aws_ssm_parameter.vault_kms_token.value
}

data "aws_iam_policy_document" "vault_root_token_kms" {
  count = var.enable_auto_vault_init ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [data.aws_kms_key.vault_root_token.arn]
  }
}

resource "aws_iam_role_policy" "vault_root_token_kms" {
  count = var.enable_auto_vault_init ? 1 : 0
  name  = "vault_root_token_kms"
  role  = aws_iam_role.instance_role.id
  policy = element(
    concat(
      data.aws_iam_policy_document.vault_root_token_kms.*.json,
      [""],
    ),
    0,
  )

  # # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # # when you try to do a terraform destroy.
  # lifecycle {
  #   create_before_destroy = true
  # }
}

