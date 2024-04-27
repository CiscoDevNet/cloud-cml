#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

data "conjur_secret" "conjur_secret" {
  for_each = toset(var.cfg.secret.list)
  name     = each.value
}
