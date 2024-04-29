#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

#
# This is the dummy secrets module.  It is used for testing purposes only
# where you don't want to use a real secrets manager.  This module will
# return an object with the raw_secrets passed in copied to secrets.  If
# a raw_secret does not exist, a random_pet of length 3 will be returned.
# https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet
#

locals {
  random_pet_length = 3
  exclude_keys = [
    "raw_secret",
  ]
  secrets = {
    for k, v in var.cfg.secret.secrets : k => merge(
      {
        for k2, v2 in v : k2 => v2 if !contains(local.exclude_keys, k2)
      },
      {
        secret = try(v.raw_secret, random_pet.random_secret[k].id)
      }
    )
  }
}

resource "random_pet" "random_secret" {
  for_each = tomap(var.cfg.secret.secrets)
  length   = local.random_pet_length
}
