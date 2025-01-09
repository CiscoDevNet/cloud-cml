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
        secret = data.vault_kv_secret_v2.vault_secret[k].data[v.field]
      }
    )
  }
}

# Note we're using the v2 version of the key value secret engine
# https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
data "vault_kv_secret_v2" "vault_secret" {
  for_each = tomap(var.cfg.secret.secrets)
  mount    = var.cfg.secret.vault.kv_secret_v2_mount
  name     = each.value.path
}
