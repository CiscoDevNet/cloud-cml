#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

output "public_ip" {
  value = azurerm_linux_virtual_machine.cml.public_ip_address
}

output "sas_token" {
	value = data.azurerm_storage_account_sas.cml.sas
}
