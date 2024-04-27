#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

#
# This is the dummy secrets module.  It is used for testing purposes only
# where you don't want to use a real secrets manager.  This module will
# return an object with the raw_secrets passed in copied to secrets
#

locals {
  exclude_keys = [
    "raw_secret",
    "path",
    "field",
  ]
  secrets = {
    for k, v in var.cfg.secret.secrets : k => merge(
      {
        for k2, v2 in v : k2 => v2 if ! contains(local.exclude_keys, k2) 
      },{
        secret = v.raw_secret
      }
    )
  }
}
