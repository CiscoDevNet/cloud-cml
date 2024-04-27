#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# Note we're using the v2 version of the key value secret engine
# https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
data "vault_kv_secret_v2" "vault_secrets" {
  for_each = toset(var.cfg.secret.list)
  mount    = var.cfg.secret.vault.kv_secret_v2_mount
  name     = each.value
}
