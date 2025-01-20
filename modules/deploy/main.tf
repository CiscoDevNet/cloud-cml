#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

resource "random_id" "id" {
  byte_length = 4
}

locals {
  options = {
    cfg           = var.cfg
    cml           = file("${path.module}/data/cml.sh")
    common        = file("${path.module}/data/common.sh")
    copyfile      = file("${path.module}/data/copyfile.sh")
    del           = file("${path.module}/data/del.sh")
    interface_fix = file("${path.module}/data/interface_fix.py")
    license       = file("${path.module}/data/license.py")
    extras        = var.extras
    rand_id       = random_id.id.hex
  }
}

