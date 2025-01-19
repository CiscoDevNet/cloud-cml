#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_providers {
    cml2 = {
      source  = "ciscodevnet/cml2"
      version = "~> 0.8.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
