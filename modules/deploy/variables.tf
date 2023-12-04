#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

variable "cfg" {
  type        = any
  description = "JSON configuration of the CML deployment"
}

variable "extras" {
  type        = any
  description = "extra shell variable defininitions"
}

# AWS related vars

variable "aws_access_key" {
  type        = string
  description = "AWS access key / credential for the provisioning user"
  default     = ""
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key matching the access key"
  default     = ""
}

# Azure related vars

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = ""
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure tenant ID"
  default     = ""
}

