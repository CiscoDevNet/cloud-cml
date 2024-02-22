#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_providers {
    cml2 = {
      source  = "CiscoDevNet/cml2"
      version = ">=0.6.2"
    }
  }
  required_version = ">= 1.1.0"
}
