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
    name             = var.name
    role             = "provisioner"
    route            = "public"
    deployment_group = "firehawk-provisioner-deploy-group"
  })
  public_ip           = element(concat(aws_instance.provisioner.*.public_ip, list("")), 0)
  private_ip          = element(concat(aws_instance.provisioner.*.private_ip, list("")), 0)
  public_dns          = element(concat(aws_instance.provisioner.*.public_dns, list("")), 0)
  id                  = element(concat(aws_instance.provisioner.*.id, list("")), 0)
  provisioner_address = var.route_public_domain_name ? "provisioner.${var.public_domain_name}" : local.public_ip
}
resource "aws_instance" "provisioner" {
  count                  = var.create_vpc ? 1 : 0
  ami                    = var.provisioner_ami_id
  instance_type          = var.instance_type
  subnet_id              = tolist(var.public_subnet_ids)[0]
  tags                   = merge(map("Name", var.name), local.provisioner_tags)
  user_data              = data.template_file.user_data_provisioner.rendered
  iam_instance_profile   = try(data.terraform_remote_state.provisioner_profile.outputs.instance_profile_name, null)
  vpc_security_group_ids = [try(data.terraform_remote_state.provisioner_security_group.outputs.security_group_id, null)]
  root_block_device {
    delete_on_termination = true
    volume_size           = 24
  }
}
data "template_file" "user_data_provisioner" {
  template = file("${path.module}/user-data-provisioner.sh")
  vars = {
    max_revisions = 2 # the number of code revisions to store on the instance
  }
}