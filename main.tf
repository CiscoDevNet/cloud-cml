#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  cfg    = yamldecode(file(var.cfg_file))
  extras = var.cfg_extra_vars == null ? "" : (
    fileexists(var.cfg_extra_vars) ? file(var.cfg_extra_vars) : var.cfg_extra_vars
  )
}

module "deploy" {
  source = "./modules/deploy"
  cfg    = local.cfg
  extras = local.extras
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
  source = "./modules/readyness"
  depends_on = [
    module.deploy.public_ip
  ]
}
