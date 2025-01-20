#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  exclude_keys = [
    "raw_secret",
  ]
  secrets = {
    for k, v in var.cfg.secret.secrets : k => merge(
      {
        for k2, v2 in v : k2 => v2 if !contains(local.exclude_keys, k2)
      },
      {
        secret = data.conjur_secret.conjur_secret[k].value
      }
    )
  }
}

data "conjur_secret" "conjur_secret" {
  for_each = tomap(var.cfg.secret.secrets)
  name     = each.value.path
}
