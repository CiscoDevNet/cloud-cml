#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

provider "aws" {
  secret_key = var.aws_secret_key
  access_key = var.aws_access_key
  region     = var.cfg.aws.region
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  # Configuration options
}

resource "random_id" "id" {
  byte_length = 4
}

locals {
  options = {
    cfg       = var.cfg
    cml       = file("${path.module}/data/cml.sh")
    copyfile  = file("${path.module}/data/copyfile.sh")
    del       = file("${path.module}/data/del.sh")
    extras    = var.extras
    use_patty = length(regexall("patty\\.sh", join(" ", var.cfg.app.customize))) > 0
    rand_id   = random_id.id.hex
  }
}

module "aws" {
  source  = "./aws"
  count   = var.cfg.target == "aws" ? 1 : 0
  options = local.options
}

module "azure" {
  source  = "./azure"
  count   = var.cfg.target == "azure" ? 1 : 0
  options = local.options
}

