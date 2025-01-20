#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

output "secrets" {
  value = (
    var.cfg.secret.manager == "conjur" ?
    try(module.conjur[0].secrets, {}) :
    var.cfg.secret.manager == "vault" ?
    try(module.vault[0].secrets, {}) :
    module.dummy.secrets
  )
  sensitive = true
}
