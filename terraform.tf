#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_providers {
    cml2 = {
      source  = "CiscoDevNet/cml2"
      version = ">=0.8.0"
    }
  }
  required_version = ">= 1.1.0"
}
