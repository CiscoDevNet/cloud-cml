#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

output "public_ip" {
  # value = aws_instance.cml_controller.private_ip
  value = aws_instance.cml_controller.public_ip
}

output "sas_token" {
  value = "undefined"
}
