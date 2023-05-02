#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

variable "access_key" {
  type        = string
  description = "AWS access key / credential for the provisioning user"
}

variable "secret_key" {
  type        = string
  description = "AWS secret key matching the access key"
}
