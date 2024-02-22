#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.56.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.82.0"
    }
  }
  required_version = ">= 1.1.0"
}
