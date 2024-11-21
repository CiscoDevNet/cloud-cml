#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  raw_cfg = yamldecode(file(var.cfg_file))
  cfg = merge(
    {
      for k, v in local.raw_cfg : k => v if k != "secret"
    },
    {
      secrets = module.secrets.secrets
    }
  )
  extras = var.cfg_extra_vars == null ? "" : (
    fileexists(var.cfg_extra_vars) ? file(var.cfg_extra_vars) : var.cfg_extra_vars
  )
}

module "secrets" {
  source = "./modules/secrets"
  cfg    = local.raw_cfg
}

module "deploy" {
  source = "./modules/deploy"
  cfg    = local.cfg
  extras = local.extras
}

provider "cml2" {
  address        = "https://${module.deploy.public_ip}"
  username       = local.cfg.secrets.app.username
  password       = local.cfg.secrets.app.secret
  skip_verify    = true
  dynamic_config = true
}

module "ready" {
  source = "./modules/readyness"
  depends_on = [
    module.deploy.public_ip
  ]
}
