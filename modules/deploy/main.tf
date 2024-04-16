#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

resource "random_id" "id" {
  byte_length = 4
}

locals {
  options = {
    cfg           = var.cfg
    cml           = file("${path.module}/data/cml.sh")
    copyfile      = file("${path.module}/data/copyfile.sh")
    del           = file("${path.module}/data/del.sh")
    interface_fix = file("${path.module}/data/interface_fix.py")
    extras        = var.extras
    use_patty     = length(regexall("patty\\.sh", join(" ", var.cfg.app.customize))) > 0
    rand_id       = random_id.id.hex
  }
}

