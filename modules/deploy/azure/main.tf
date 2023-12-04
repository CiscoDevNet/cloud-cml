#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  # late binding required as the token is only known within the module
  vars = templatefile("${path.module}/../data/vars.sh", {
    cfg = merge(
      var.options.cfg,
      { sas_token = data.azurerm_storage_account_sas.cml.sas }
    )
    }
  )

  user_data = templatefile("${path.module}/../data/userdata.txt", {
    vars     = local.vars
    cfg      = var.options.cfg
    cml      = var.options.cml
    copyfile = var.options.copyfile
    del      = var.options.del
    extras   = var.options.extras
    path     = path.module
  })

  # vmname     = "cml-${var.options.rand_id}"
}

# this references an existing resource group
data "azurerm_resource_group" "cml" {
  name = var.options.cfg.azure.resource_group
}

# this references an existing storage account within the resource group
data "azurerm_storage_account" "cml" {
  name                = var.options.cfg.azure.storage_account
  resource_group_name = data.azurerm_resource_group.cml.name
}

data "azurerm_storage_account_sas" "cml" {
  connection_string = data.azurerm_storage_account.cml.primary_connection_string
  https_only        = true
  signed_version    = "2022-11-02"

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "1h")

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = true
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

resource "azurerm_network_security_group" "cml" {
  name                = "cml-sg-${var.options.rand_id}"
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name
}

resource "azurerm_network_security_rule" "cml-std" {
  name                        = "cml-std-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = [22, 80, 443, 1122, 9090]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.cml.name
  network_security_group_name = azurerm_network_security_group.cml.name
}

resource "azurerm_network_security_rule" "cml-patty-tcp" {
  count                       = var.options.use_patty ? 1 : 0
  name                        = "patty-tcp-in"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "2000-7999"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.cml.name
  network_security_group_name = azurerm_network_security_group.cml.name
}

resource "azurerm_network_security_rule" "cml-patty-udp" {
  count                       = var.options.use_patty ? 1 : 0
  name                        = "patty-udp-in"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "2000-7999"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.cml.name
  network_security_group_name = azurerm_network_security_group.cml.name
}

resource "azurerm_public_ip" "cml" {
  name                = "cml-pub-ip-${var.options.rand_id}"
  resource_group_name = data.azurerm_resource_group.cml.name
  location            = data.azurerm_resource_group.cml.location
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network" "cml" {
  name                = "cml-network-${var.options.rand_id}"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name
}

resource "azurerm_subnet" "cml" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.cml.name
  virtual_network_name = azurerm_virtual_network.cml.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "cml" {
  name                = "cml-nic-${var.options.rand_id}"
  location            = data.azurerm_resource_group.cml.location
  resource_group_name = data.azurerm_resource_group.cml.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cml.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cml.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "cml" {
  network_interface_id      = azurerm_network_interface.cml.id
  network_security_group_id = azurerm_network_security_group.cml.id
}

resource "azurerm_linux_virtual_machine" "cml" {
  name                = var.options.cfg.common.hostname
  resource_group_name = data.azurerm_resource_group.cml.name
  location            = data.azurerm_resource_group.cml.location

  # size                = "Standard_F2"
  # https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/nested-virtualization
  # https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series
  # Size	vCPU	Memory: GiB	Temp storage (SSD) GiB	Max data disks	Max NICs	Max network bandwidth (Mbps)
  # Standard_D2_v5	2	8	Remote Storage Only	4	2	12500
  # Standard_D4_v5	4	16	Remote Storage Only	8	2	12500
  # Standard_D8_v5	8	32	Remote Storage Only	16	4	12500
  # Standard_D16_v5	16	64	Remote Storage Only	32	8	12500
  # Standard_D32_v5	32	128	Remote Storage Only	32	8	16000
  # Standard_D48_v5	48	192	Remote Storage Only	32	8	24000
  # Standard_D64_v5	64	256	Remote Storage Only	32	8	30000
  # Standard_D96_v5	96	384	Remote Storage Only	32	8	35000
  #
  # https://learn.microsoft.com/en-us/azure/virtual-machines/ddv4-ddsv4-series
  # Size	vCPU	Memory: GiB	Temp storage (SSD) GiB	Max data disks	Max temp storage throughput: IOPS/MBps*	Max NICs	Expected network bandwidth (Mbps)
  # Standard_D2d_v41	2	8	75  	4	9000/125	2	5000
  # Standard_D4d_v4     4	16	150 	8	19000/250	2	10000
  # Standard_D8d_v4     8	32	300 	16	38000/500	4	12500
  # Standard_D16d_v4	16	64	600 	32	75000/1000	8	12500
  # Standard_D32d_v4	32	128	1200	32	150000/2000	8	16000
  # Standard_D48d_v4	48	192	1800	32	225000/3000	8	24000
  # Standard_D64d_v4	64	256	2400	32	300000/4000	8	30000

  size = var.options.cfg.azure.size

  admin_username = "ubuntu"
  network_interface_ids = [
    azurerm_network_interface.cml.id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = data.azurerm_ssh_public_key.cml.public_key
    # public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.options.cfg.common.disk_size
  }

  # https://canonical-azure.readthedocs-hosted.com/en/latest/azure-explanation/daily-vs-release-images/
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(local.user_data)
}

data "azurerm_ssh_public_key" "cml" {
  name                = var.options.cfg.common.key_name
  resource_group_name = data.azurerm_resource_group.cml.name
}
