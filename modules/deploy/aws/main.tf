#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  num_computes = var.options.cfg.cluster.enable_cluster ? var.options.cfg.cluster.number_of_compute_nodes : 0
  compute_hostnames = [
    for i in range(1, local.num_computes + 1) :
    format("%s-%d", var.options.cfg.cluster.compute_hostname_prefix, i)
  ]

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
    is_compute    = !var.options.cfg.cluster.enable_cluster || var.options.cfg.cluster.allow_vms_on_controller
    cfg = merge(
      var.options.cfg,
      # Need to have this as it's referenced in the template (Azure specific)
      { sas_token = "undefined" }
    )
    }
  )

  cml_config_compute = [for compute_hostname in local.compute_hostnames : templatefile("${path.module}/../data/virl2-base-config.yml", {
    hostname      = compute_hostname,
    is_controller = false,
    is_compute    = true,
    cfg = merge(
      var.options.cfg,
      # Need to have this as it's referenced in the template.
      # (Azure specific)
      { sas_token = "undefined" }
    )
    }
  )]

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

  cloud_config_compute = [for i in range(0, local.num_computes) : templatefile("${path.module}/../data/cloud-config.txt", {
    vars          = local.vars
    cml_config    = local.cml_config_compute[i]
    cfg           = var.options.cfg
    cml           = var.options.cml
    common        = var.options.common
    copyfile      = var.options.copyfile
    del           = var.options.del
    interface_fix = var.options.interface_fix
    license       = "empty"
    extras        = var.options.extras
    hostname      = local.compute_hostnames[i]
    path          = path.module
  })]

  main_vpc   = length(var.options.cfg.aws.vpc_id) > 0 ? data.aws_vpc.selected[0] : aws_vpc.main_vpc[0]
  main_gw_id = length(var.options.cfg.aws.gw_id) > 0 ? var.options.cfg.aws.gw_id : aws_internet_gateway.public_igw[0].id

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

resource "aws_security_group" "sg_tf" {
  name        = "tf-sg-cml-${var.options.rand_id}"
  description = "CML required ports inbound/outbound"
  tags = {
    Name = "tf-sg-cml-${var.options.rand_id}"
  }
  vpc_id = local.main_vpc.id
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
  ingress = var.options.cfg.common.enable_patty ? concat(local.cml_ingress, local.cml_patty_range) : local.cml_ingress
}

resource "aws_security_group" "sg_tf_cluster_int" {
  name        = "tf-sg-cml-cluster-int-${var.options.rand_id}"
  description = "Allowing all IPv6 traffic on the cluster interface"
  tags = {
    Name = "tf-sg-cml-cluster-int-${var.options.rand_id}"
  }
  vpc_id = local.main_vpc.id
  egress = [
    {
      "description" : "any",
      "from_port" : 0,
      "to_port" : 0
      "protocol" : "-1",
      "cidr_blocks" : [],
      "ipv6_cidr_blocks" : ["::/0"],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    }
  ]
  ingress = [
    {
      "description" : "any",
      "from_port" : 0,
      "to_port" : 0
      "protocol" : "-1",
      "cidr_blocks" : [],
      "ipv6_cidr_blocks" : ["::/0"],
      "prefix_list_ids" : [],
      "security_groups" : [],
      "self" : false,
    }
  ]
}

#----------------- if VPC ID was provided, select it --------------------------
data "aws_vpc" "selected" {
  id    = var.options.cfg.aws.vpc_id
  count = length(var.options.cfg.aws.vpc_id) > 0 ? 1 : 0
}

#------------------- non-default VPC configuration ----------------------------
resource "aws_vpc" "main_vpc" {
  count                            = length(var.options.cfg.aws.vpc_id) > 0 ? 0 : 1
  cidr_block                       = var.options.cfg.aws.public_vpc_ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  tags = {
    Name = "CML-vpc-${var.options.rand_id}"
  }
}

#------------------- public subnet, IGW and routing ---------------------------
resource "aws_internet_gateway" "public_igw" {
  count  = length(var.options.cfg.aws.gw_id) > 0 ? 0 : 1
  vpc_id = local.main_vpc.id
  tags   = { "Name" = "CML-igw-${var.options.rand_id}" }
}

resource "aws_subnet" "public_subnet" {
  availability_zone       = var.options.cfg.aws.availability_zone
  cidr_block              = cidrsubnet(var.options.cfg.aws.public_vpc_ipv4_cidr, 8, 0)
  vpc_id                  = local.main_vpc.id
  map_public_ip_on_launch = true
  tags                    = { "Name" = "CML-public-${var.options.rand_id}" }
}

resource "aws_route_table" "for_public_subnet" {
  vpc_id = local.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.main_gw_id
  }
  tags = { "Name" = "CML-public-rt-${var.options.rand_id}" }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.for_public_subnet.id
}

resource "aws_network_interface" "pub_int_cml" {
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg_tf.id]
  tags            = { Name = "CML-controller-pub-int-${var.options.rand_id}" }
}

resource "aws_eip" "server_eip" {
  network_interface = aws_network_interface.pub_int_cml.id
  tags              = { "Name" = "CML-controller-eip-${var.options.rand_id}", "device" = "server" }
  depends_on        = [aws_instance.cml_controller]
}

#------------- compute subnet, NAT GW, routing and interfaces -----------------

resource "aws_subnet" "compute_nat_subnet" {
  availability_zone = var.options.cfg.aws.availability_zone
  cidr_block        = cidrsubnet(var.options.cfg.aws.public_vpc_ipv4_cidr, 8, 1)
  vpc_id            = local.main_vpc.id
  tags              = { "Name" = "CML-compute-nat-${var.options.rand_id}" }
  count             = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "CML-compute-nat-gw-eip-${var.options.rand_id}"
  }
  count = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_nat_gateway" "compute_nat_gw" {
  allocation_id = aws_eip.nat_eip[0].id // Allocate an EIP 
  subnet_id     = aws_subnet.public_subnet.id
  count         = var.options.cfg.cluster.enable_cluster ? 1 : 0
  tags = {
    Name = "CML-compute-nat-gw-${var.options.rand_id}"
  }
  # Ensure creation after EIP and subnet resources exist
  depends_on = [
    aws_eip.nat_eip,
    aws_subnet.compute_nat_subnet
  ]
}

resource "aws_route_table" "compute_route_table" {
  vpc_id = local.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.compute_nat_gw[0].id
  }
  tags = {
    Name = "CML-cluster-rt-${var.options.rand_id}"
  }
  count = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_route_table_association" "compute_subnet_assoc" {
  subnet_id      = aws_subnet.compute_nat_subnet[0].id
  route_table_id = aws_route_table.compute_route_table[0].id
  count          = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_network_interface" "nat_int_cml_compute" {
  subnet_id       = aws_subnet.compute_nat_subnet[0].id
  security_groups = [aws_security_group.sg_tf.id]
  tags            = { Name = "CML-compute-${count.index + 1}-nat-int-${var.options.rand_id}" }
  count           = local.num_computes
}

#-------------------- cluster subnet and interface ----------------------------

resource "aws_subnet" "cluster_subnet" {
  availability_zone               = var.options.cfg.aws.availability_zone
  cidr_block                      = cidrsubnet(var.options.cfg.aws.public_vpc_ipv4_cidr, 8, 255)
  ipv6_cidr_block                 = cidrsubnet(local.main_vpc.ipv6_cidr_block, 8, 1)
  vpc_id                          = local.main_vpc.id
  tags                            = { "Name" = "CML-cluster-${var.options.rand_id}" }
  count                           = var.options.cfg.cluster.enable_cluster ? 1 : 0
  assign_ipv6_address_on_creation = true
}

resource "aws_network_interface" "cluster_int_cml" {
  subnet_id       = aws_subnet.cluster_subnet[0].id
  security_groups = [aws_security_group.sg_tf_cluster_int.id]
  tags            = { Name = "CML-controller-cluster-int-${var.options.rand_id}" }
  count           = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_network_interface" "cluster_int_cml_compute" {
  subnet_id       = aws_subnet.cluster_subnet[0].id
  security_groups = [aws_security_group.sg_tf_cluster_int.id]
  tags            = { Name = "CML-compute-${count.index + 1}-cluster-int-${var.options.rand_id}" }
  count           = local.num_computes
}

#------------------ IPv6 multicast support for CML clustering -----------------

resource "aws_ec2_transit_gateway" "transit_gateway" {
  description                     = "CML Transit Gateway"
  multicast_support               = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "disable"
  vpn_ecmp_support                = "disable"
  tags = {
    Name = "CML-tgw-${var.options.rand_id}"
  }
  count = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_ec2_transit_gateway_multicast_domain" "cml_mcast_domain" {
  transit_gateway_id              = aws_ec2_transit_gateway.transit_gateway[0].id
  igmpv2_support                  = "enable"
  auto_accept_shared_associations = "enable"
  tags = {
    Name = "CML-mcast-domain-${var.options.rand_id}"
  }
  count = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway[0].id
  vpc_id             = local.main_vpc.id
  subnet_ids         = [aws_subnet.cluster_subnet[0].id]
  ipv6_support       = "enable"
  tags = {
    Name = "CML-tgw-vpc-attachment-${var.options.rand_id}"
  }
  count = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_ec2_transit_gateway_multicast_domain_association" "cml_association" {
  transit_gateway_attachment_id       = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[count.index].id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.cml_mcast_domain[count.index].id
  subnet_id                           = aws_subnet.cluster_subnet[count.index].id
  count                               = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_ec2_transit_gateway_multicast_group_member" "cml_controller_int" {
  group_ip_address                    = "ff02::fb"
  network_interface_id                = aws_network_interface.cluster_int_cml[count.index].id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain_association.cml_association[count.index].transit_gateway_multicast_domain_id
  count                               = var.options.cfg.cluster.enable_cluster ? 1 : 0
}

resource "aws_ec2_transit_gateway_multicast_group_member" "cml_compute_int" {
  group_ip_address                    = "ff02::fb"
  network_interface_id                = aws_network_interface.cluster_int_cml_compute[count.index].id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain_association.cml_association[0].transit_gateway_multicast_domain_id
  count                               = local.num_computes
}

resource "aws_instance" "cml_controller" {
  instance_type        = var.options.cfg.aws.flavor
  ami                  = data.aws_ami.ubuntu.id
  iam_instance_profile = var.options.cfg.aws.profile
  key_name             = var.options.cfg.common.key_name
  tags                 = { Name = "CML-controller-${var.options.rand_id}" }
  ebs_optimized        = "true"
  depends_on           = [aws_route_table_association.public_subnet]
  dynamic "instance_market_options" {
    for_each = var.options.cfg.aws.spot_instances.use_spot_for_controller ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }
  root_block_device {
    volume_size = var.options.cfg.common.disk_size
    volume_type = "gp3"
    encrypted   = var.options.cfg.aws.enable_ebs_encryption
  }
  network_interface {
    network_interface_id = aws_network_interface.pub_int_cml.id
    device_index         = 0
  }
  dynamic "network_interface" {
    for_each = var.options.cfg.cluster.enable_cluster ? [1] : []
    content {
      network_interface_id = aws_network_interface.cluster_int_cml[0].id
      device_index         = 1
    }
  }
  user_data = data.cloudinit_config.cml_controller.rendered
}

resource "aws_instance" "cml_compute" {
  instance_type        = var.options.cfg.aws.flavor_compute
  ami                  = data.aws_ami.ubuntu.id
  iam_instance_profile = var.options.cfg.aws.profile
  key_name             = var.options.cfg.common.key_name
  tags                 = { Name = "CML-compute-${count.index + 1}-${var.options.rand_id}" }
  ebs_optimized        = "true"
  count                = local.num_computes
  depends_on           = [aws_instance.cml_controller, aws_route_table_association.compute_subnet_assoc]
  dynamic "instance_market_options" {
    for_each = var.options.cfg.aws.spot_instances.use_spot_for_computes ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }
  root_block_device {
    volume_size = var.options.cfg.cluster.compute_disk_size
    volume_type = "gp3"
    encrypted   = var.options.cfg.aws.enable_ebs_encryption
  }
  network_interface {
    network_interface_id = aws_network_interface.nat_int_cml_compute[count.index].id
    device_index         = 0
  }
  network_interface {
    network_interface_id = aws_network_interface.cluster_int_cml_compute[count.index].id
    device_index         = 1
  }
  user_data = data.cloudinit_config.cml_compute[count.index].rendered
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
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

data "cloudinit_config" "cml_compute" {
  gzip          = true
  base64_encode = true # always true if gzip is true
  count         = local.num_computes

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"

    content = local.cloud_config_compute[count.index]
  }
}
