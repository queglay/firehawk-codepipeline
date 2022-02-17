data "aws_region" "current" {}

data "terraform_remote_state" "provisioner_security_group" { # read the arn with data.terraform_remote_state.packer_profile.outputs.instance_role_arn, or read the profile name with data.terraform_remote_state.packer_profile.outputs.instance_profile_name
  backend = "s3"
  config = {
    bucket = "state.terraform.${var.bucket_extension_vault}"
    key    = "init/modules/terraform-aws-sg-provisioner/terraform.tfstate"
    region = data.aws_region.current.name
  }
}
data "terraform_remote_state" "provisioner_profile" { # read the arn with data.terraform_remote_state.packer_profile.outputs.instance_role_arn, or read the profile name with data.terraform_remote_state.packer_profile.outputs.instance_profile_name
  backend = "s3"
  config = {
    bucket = "state.terraform.${var.bucket_extension_vault}"
    key    = "init/modules/terraform-aws-iam-profile-provisioner/terraform.tfstate"
    region = data.aws_region.current.name
  }
}
locals {
  provisioner_tags = merge(var.common_tags, {
    name  = var.name
    role  = "provisioner"
    route = "public"
    deployment_group = "firehawk-provisioner-deploy-group"
  })
  public_ip       = element(concat(aws_instance.provisioner.*.public_ip, list("")), 0)
  private_ip      = element(concat(aws_instance.provisioner.*.private_ip, list("")), 0)
  public_dns      = element(concat(aws_instance.provisioner.*.public_dns, list("")), 0)
  id              = element(concat(aws_instance.provisioner.*.id, list("")), 0)
  provisioner_address = var.route_public_domain_name ? "provisioner.${var.public_domain_name}" : local.public_ip
}
resource "aws_instance" "provisioner" {
  count                  = var.create_vpc ? 1 : 0
  ami                    = var.provisioner_ami_id
  instance_type          = var.instance_type
  key_name               = var.aws_key_name # The PEM key is disabled for use in production, can be used for debugging.  Instead, signed SSH certificates should be used to access the host.
  subnet_id              = tolist(var.public_subnet_ids)[0]
  tags                   = merge(map("Name", var.name), local.provisioner_tags)
  # user_data              = data.template_file.user_data_auth_client.rendered
  iam_instance_profile   = try(data.terraform_remote_state.provisioner_profile.outputs.instance_profile_name, null)
  vpc_security_group_ids = [ try(data.terraform_remote_state.provisioner_security_group.outputs.security_group_id, null) ]
  root_block_device {
    delete_on_termination = true
    volume_size = 24
  }
}
# data "template_file" "user_data_auth_client" {
#   template = file("${path.module}/user-data-auth-ssh-host-iam.sh")
#   vars = {
#     consul_cluster_tag_key   = var.consul_cluster_tag_key
#     consul_cluster_tag_value = var.consul_cluster_name
#     aws_internal_domain      = var.aws_internal_domain
#     aws_external_domain      = var.aws_external_domain
#     example_role_name        = "provisioner-vault-role"
#     vault_token              = ""
#   }
# }
# resource "aws_route53_record" "provisioner_record" {
#   count   = var.route_public_domain_name && var.create_vpc ? 1 : 0
#   zone_id = element(concat(list(var.route_zone_id), list("")), 0)
#   name    = element(concat(list("provisioner.${var.public_domain_name}"), list("")), 0)
#   type    = "A"
#   ttl     = 300
#   records = [local.public_ip]
# }
