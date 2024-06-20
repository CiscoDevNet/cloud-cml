#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# Common variables

variable "cfg_file" {
  type        = string
  description = "Name of the YAML config file to use"
  default     = "config.yml"
}

variable "cfg_extra_vars" {
  type        = string
  description = "extra variable definitions, typically empty"
  default     = null
}

# AWS related vars

variable "aws_access_key" {
  type        = string
  description = "AWS access key / credential for the provisioning user"
  default     = "notset"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key matching the access key"
  default     = "notset"
}

# Azure related vars

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = "notset"
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure tenant ID"
  default     = "notset"
}
