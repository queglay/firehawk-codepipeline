data "aws_vpc" "thisvpc" {
  default = false
  tags    = var.common_tags
}

resource "aws_security_group" "provisioner" {
  name        = var.name
  vpc_id      = data.aws_vpc.thisvpc.id
  description = "Provisioner Security Group"
  tags        = merge(map("Name", var.name), var.common_tags, local.extra_tags)

  # ingress {
  #   protocol    = "-1"
  #   from_port   = 0
  #   to_port     = 0
  #   cidr_blocks = [data.aws_vpc.thisvpc.cidr_block]
  #   description = "All incoming traffic from vpc"
  # }
  # ingress {
  #   protocol    = "tcp"
  #   from_port   = 8200
  #   to_port     = 8200
  #   cidr_blocks = local.permitted_cidr_list
  #   description = "Vault UI forwarding"
  # }
  # ingress {
  #   protocol    = "tcp"
  #   from_port   = 22
  #   to_port     = 22
  #   cidr_blocks = local.permitted_cidr_list
  #   description = "SSH"
  # }
  # ingress {
  #   protocol    = "icmp"
  #   from_port   = 8
  #   to_port     = 0
  #   cidr_blocks = local.permitted_cidr_list
  #   description = "ICMP ping traffic"
  # }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "all outgoing traffic"
  }
}

locals {
  extra_tags = {
    role  = "provisioner"
    route = "public"
  }
  permitted_cidr_list = ["${var.onsite_public_ip}/32", var.remote_cloud_public_ip_cidr, var.remote_cloud_private_ip_cidr]
}