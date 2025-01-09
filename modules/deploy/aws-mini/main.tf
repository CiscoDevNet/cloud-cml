#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  # Late binding required as the token is only known within the module.
  # (Azure specific)
  vars = templatefile("${path.module}/../data/vars.sh", {
    cfg = merge(
      var.options.cfg,
      # Need to have this as it's referenced in the template (Azure specific)
      { sas_token = "undefined" }
    )
    }
  )

  cml_config_controller = templatefile("${path.module}/../data/virl2-base-config.yml", {
    hostname      = var.options.cfg.common.controller_hostname,
    is_controller = true
    is_compute    = true
    cfg = merge(
      var.options.cfg,
      # Need to have this as it's referenced in the template (Azure specific)
      { sas_token = "undefined" }
    )
    }
  )

  # Ensure there's no tabs in the template file! Also ensure that the list of
  # reference platforms has no single quotes in the file names or keys (should
  # be reasonable, but you never know...)
  cloud_config = templatefile("${path.module}/../data/cloud-config.txt", {
    vars          = local.vars
    cml_config    = local.cml_config_controller
    cfg           = var.options.cfg
    cml           = var.options.cml
    common        = var.options.common
    copyfile      = var.options.copyfile
    del           = var.options.del
    interface_fix = var.options.interface_fix
    license       = var.options.license
    extras        = var.options.extras
    hostname      = var.options.cfg.common.controller_hostname
    path          = path.module
  })
}

data "aws_subnet" "selected_subnet" {
  id = var.options.cfg.aws.subnet_id
}

data "aws_security_group" "selected_security_group" {
  id = var.options.cfg.aws.sg_id
}

resource "aws_network_interface" "pub_int_cml" {
  subnet_id       = data.aws_subnet.selected_subnet.id
  security_groups = [data.aws_security_group.selected_security_group.id]
}

# If no EIP is needed/wanted, then 
# - change public_ip to private_ip in output.tf
# - delete the resource block if no EIP is wanted/needed
# In this case, the machine that runs Terraform / the provisioning must be able
# to reach the private IP address and the security group must permit HTTPS to
# the controller.
resource "aws_eip" "server_eip" {
  network_interface = aws_network_interface.pub_int_cml.id
}

resource "aws_instance" "cml_controller" {
  instance_type        = var.options.cfg.aws.flavor
  ami                  = data.aws_ami.ubuntu.id
  iam_instance_profile = var.options.cfg.aws.profile
  key_name             = var.options.cfg.common.key_name
  tags                 = { Name = "CML-controller-${var.options.rand_id}" }
  ebs_optimized        = "true"
  root_block_device {
    volume_size = var.options.cfg.common.disk_size
    volume_type = "gp3"
    encrypted   = var.options.cfg.aws.enable_ebs_encryption
  }
  network_interface {
    network_interface_id = aws_network_interface.pub_int_cml.id
    device_index         = 0
  }
  user_data = data.cloudinit_config.cml_controller.rendered
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Owner ID of Canonical
}

data "cloudinit_config" "cml_controller" {
  gzip          = true
  base64_encode = true # always true if gzip is true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = local.cloud_config
  }
}

