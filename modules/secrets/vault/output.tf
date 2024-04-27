#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

output "secrets" {
  value = { for i in data.vault_kv_secret_v2.vault_secrets : 
    # Do not include the mount point and /data/ in the key
    trimprefix(i.path, format("%s/data/", var.cfg.secret.vault.kv_secret_v2_mount)) => 
    i.data[var.cfg.secret.vault.field_key] }
  sensitive = true
}
