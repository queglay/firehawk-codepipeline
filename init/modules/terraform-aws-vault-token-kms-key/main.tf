resource "random_pet" "env" {
  length = 2
}
locals {
  common_tags      = var.common_tags
  aws_kms_key_tags = merge(tomap({"Name": "vault-kms-token-${random_pet.env.id}"}), local.common_tags)
}

resource "aws_kms_key" "vault" {
  description             = "Vault token secret key"
  deletion_window_in_days = 10
  tags                    = local.aws_kms_key_tags
}

resource "aws_kms_alias" "alias" {
  name          = "alias/firehawk/resourcetier/${var.resourcetier}/vault_kms_token_key_alias"
  target_key_id = aws_kms_key.vault.key_id
}

resource "aws_ssm_parameter" "vault_kms_token" {
  name      = "/firehawk/resourcetier/${var.resourcetier}/vault_kms_token_key_id"
  type      = "SecureString"
  overwrite = true
  value     = aws_kms_key.vault.id
  tags      = merge(tomap({"Name": "vault_kms_token_key_id"}), local.common_tags)
}

data "aws_ssm_parameter" "vault_kms_token" {
  depends_on = [aws_ssm_parameter.vault_kms_token]
  name       = "/firehawk/resourcetier/${var.resourcetier}/vault_kms_token_key_id"
}

data "aws_kms_key" "vault" {
  key_id = data.aws_ssm_parameter.vault_kms_token.value
}

# Ensure this encrypted secret exists for later use when vault is initialised.
resource "aws_secretsmanager_secret" "vault_root_token" {
  name       = "/firehawk/resourcetier/${var.resourcetier}/vault_root_token"
  kms_key_id = aws_kms_key.vault.id
}
