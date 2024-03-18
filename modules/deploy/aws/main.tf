#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  # Late binding required as the token is only known within the module.
  # (Azure specific)
  vars = templatefile("${path.module}/../data/vars.sh", {
    cfg = merge(
        var.options.cfg,
        # Need to have this as it's referenced in the template.
        # (Azure specific)
        { sas_token = "undefined" }
      )
    }
  )

  # Ensure there's no tabs in the template file! Also ensure that the list of
  # reference platforms has no single quotes in the file names or keys (should
  # be reasonable, but you never know...)
  cloud_config = templatefile("${path.module}/../data/cloud-config.txt", {
    vars     = local.vars
    cfg      = var.options.cfg
    copyfile = var.options.copyfile
    del      = var.options.del
    extras   = var.options.extras
    path     = path.module
  })

  cml_ingress = [
    {
      "description" : "allow SSH",
      "from_port" : 1122,
      "to_port" : 1122
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    },
    {
      "description" : "allow CML termserver",
      "from_port" : 22,
      "to_port" : 22
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    },
    {
      "description" : "allow Cockpit",
      "from_port" : 9090,
      "to_port" : 9090
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    },
    {
      "description" : "allow HTTP",
      "from_port" : 80,
      "to_port" : 80
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    },
    {
      "description" : "allow HTTPS",
      "from_port" : 443,
      "to_port" : 443
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    }
  ]
  cml_patty_range = [
    {
      "description" : "allow PATty TCP",
      "from_port" : 2000,
      "to_port" : 7999
      "protocol" : "tcp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    },
    {
      "description" : "allow PATty UDP",
      "from_port" : 2000,
      "to_port" : 7999
      "protocol" : "udp",
      "cidr_blocks" : var.options.cfg.common.allowed_ipv4_subnets,
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    }
  ]
}

resource "aws_security_group" "sg-tf" {
  name        = "tf-sg-cml-${var.options.rand_id}"
  description = "CML required ports inbound/outbound"
  vpc_id = aws_vpc.main-vpc.id
  egress = [
    {
      "description" : "any",
      "from_port" : 0,
      "to_port" : 0
      "protocol" : "-1",
      "cidr_blocks" : [
        "0.0.0.0/0"
      ],
      "ipv6_cidr_blocks" : [],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    }
  ]
  ingress = var.options.use_patty ? concat(local.cml_ingress, local.cml_patty_range) : local.cml_ingress
}

### Non default VPC configuration
#------------- VPC ----------------------------------------
resource "aws_vpc" "main-vpc" {
  cidr_block = var.options.cfg.aws.public-vpc-ipv4-subnet
  tags = {
    Name = "CML-vpc"
  }
}

#-------------Public Subnets, IGW and Routing----------------------------------------
resource "aws_internet_gateway" "public_igw" {
    vpc_id = aws_vpc.main-vpc.id
    tags = {"Name" = "CML-igw"}
}
resource "aws_subnet" "public_subnet" {
    availability_zone = var.options.cfg.aws.availability_zone
    cidr_block = var.options.cfg.aws.public-interface-ipv4-subnet
    vpc_id = aws_vpc.main-vpc.id
    map_public_ip_on_launch = true
    tags = {"Name" = "CML-public"}
}
resource "aws_route_table" "for_public_subnet" {
    vpc_id = aws_vpc.main-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.public_igw.id
    }
    tags = {"Name" = "CML-public"}
}
  
resource "aws_route_table_association" "public_subnet" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.for_public_subnet.id
}

resource "aws_network_interface" "pub_int_cml" {
    subnet_id = aws_subnet.public_subnet.id
    security_groups = [ aws_security_group.sg-tf.id ]
    tags = {Name = "CML-pub-int"}
}

resource "aws_eip" "server_eip" {
  network_interface = aws_network_interface.pub_int_cml.id
  tags = {"Name" = "CML-eip", "device" = "server"}
}


resource "aws_instance" "cml" {
  instance_type          = var.options.cfg.aws.flavor
  ami                    = data.aws_ami.ubuntu.id
  iam_instance_profile   = var.options.cfg.aws.profile
  key_name               = var.options.cfg.common.key_name
  tags                   = {Name = "CML-controller"}
  ebs_optimized          = "true"
  instance_market_options {
  market_type = "spot"
  spot_options {
      #max_price = 1.20
      instance_interruption_behavior = "stop"
      spot_instance_type = "persistent"
    }
  }
  root_block_device {
    volume_size = var.options.cfg.common.disk_size
    volume_type = "gp3"
  }
  network_interface {
        network_interface_id = aws_network_interface.pub_int_cml.id
        device_index = 0
  } 
  user_data = data.cloudinit_config.aws_ud.rendered
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Owner ID of Canonical
}

data "cloudinit_config" "aws_ud" {
  gzip          = true
  base64_encode = true  # always true if gzip is true

  part {
    filename     = "userdata.txt"
    content_type = "text/x-shellscript"

    content = var.options.cml
  }

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"

    content = local.cloud_config
  }
}
