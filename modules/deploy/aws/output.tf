#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

output "public_ip" {
  value = aws_eip.server_eip.public_ip
}

output "sas_token" {
  value = "undefined"
}
