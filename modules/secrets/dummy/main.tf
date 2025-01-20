#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

#
# This is the dummy secrets module.  It is used for testing purposes only
# where you don't want to use a real secrets manager.  This module will
# return an object with the raw_secrets passed in copied to secrets.  If
# a raw_secret does not exist, a random_password of length 16 will be returned.
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
#

locals {
  random_password_length = 16
  exclude_keys = [
    "raw_secret",
  ]
  secrets = {
    for k, v in var.cfg.secret.secrets : k => merge(
      # In case the YAML refers to a value that's empty, we check for null.
      # This happens with a randomly generated cluster secret.
      (v != null ?
        {
          for k2, v2 in v : k2 => v2 if !contains(local.exclude_keys, k2)
        }
        :
        {}
      ),
      {
        secret = try(v.raw_secret, random_password.random_secret[k].result)
      }
    )
  }
}

resource "random_password" "random_secret" {
  for_each = toset([for k in keys(var.cfg.secret.secrets) : k])
  length   = local.random_password_length
  # Some special characters need to be escaped, so disable
  special = false
}
