#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_providers {
    conjur = {
      source = "localhost/cyberark/conjur"
    }
  }
  required_version = ">= 1.1.0"
}
