#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

output "public_ip" {
  value = azurerm_public_ip.cml.ip_address
}

output "sas_token" {
  value = data.azurerm_storage_account_sas.cml.sas
}
