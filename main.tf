#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  cfg_file = file("config.yml")
  cfg      = yamldecode(local.cfg_file)
}

module "deploy" {
  source               = "./module-cml2-deploy-aws"
  region               = local.cfg.aws.region
  instance_type        = local.cfg.aws.flavor
  key_name             = local.cfg.aws.key_name
  iam_instance_profile = local.cfg.aws.profile
  disk_size            = local.cfg.aws.disk_size
  cfg                  = local.cfg_file
}

provider "cml2" {
  address        = "https://${module.deploy.public_ip}"
  username       = local.cfg.app.user
  password       = local.cfg.app.pass
  use_cache      = false
  skip_verify    = true
  dynamic_config = true
}

module "ready" {
  source = "./module-cml2-readyness"
  depends_on = [
    module.deploy.public_ip
  ]
}
