terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "az104-rg5" {
  name     = "az104-rg5"
  location = "polandcentral"
}

resource "azurerm_virtual_network" "core-services-vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az104-rg5.location
  resource_group_name = azurerm_resource_group.az104-rg5.name
}

resource "azurerm_subnet" "core" {
  name                 = "Core"
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.core-services-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg5.name
}

resource "azurerm_network_interface" "core-services-nic" {
  name                = "CoreServicesNIC"
  location            = azurerm_resource_group.az104-rg5.location
  resource_group_name = azurerm_resource_group.az104-rg5.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.core.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_windows_virtual_machine" "core-services-vm" {
  name                  = "CoreServicesVM"
  resource_group_name   = azurerm_resource_group.az104-rg5.name
  location              = azurerm_resource_group.az104-rg5.location
  size                  = "Standard_D2S_v3"
  admin_username        = "localadmin"
  admin_password        = random_password.password.result
  network_interface_ids = [azurerm_network_interface.core-services-nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  
}

resource "azurerm_virtual_network" "manufacturing-vnet" {
  name                     = "ManufacturingVnet"
  resource_group_name      = azurerm_resource_group.az104-rg5.name
  location                 = azurerm_resource_group.az104-rg5.location
  address_space            = ["172.16.0.0/16"]
}

resource "azurerm_subnet" "manufacturing" {
  name                 = "Manufacturing"
  address_prefixes     = ["172.16.0.0/24"]
  virtual_network_name = azurerm_virtual_network.manufacturing-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg5.name
}

resource "azurerm_network_interface" "manufacturing-nic" {
  name                = "ManufacturingNIC"
  location            = azurerm_resource_group.az104-rg5.location
  resource_group_name = azurerm_resource_group.az104-rg5.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.manufacturing.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "manufacturing-vm" {
  name                  = "ManufacturingVM"
  resource_group_name   = azurerm_resource_group.az104-rg5.name
  location              = azurerm_resource_group.az104-rg5.location
  size                  = "Standard_D2S_v3"
  admin_username        = "localadmin"
  admin_password        = random_password.password.result
  network_interface_ids = [azurerm_network_interface.manufacturing-nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_network_peering" "manufacturing-to-core" {
  name                      = "ManufacturingVnet-to-CoreServicesVnet"
  resource_group_name       = azurerm_resource_group.az104-rg5.name
  virtual_network_name      = azurerm_virtual_network.manufacturing-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.core-services-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "core-to-manufacturing" {
  name                      = "CoreServicesVnet-to-ManufacturingVnet"
  resource_group_name       = azurerm_resource_group.az104-rg5.name
  virtual_network_name      = azurerm_virtual_network.core-services-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.manufacturing-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_subnet" "perimeter" {
  name                 = "perimeter"
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.core-services-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg5.name
}

resource "azurerm_route_table" "rt-core-services" {
  name                = "rt-CoreServices"
  location            = azurerm_resource_group.az104-rg5.location
  resource_group_name = azurerm_resource_group.az104-rg5.name

  route {
    name                   = "PerimetertoCore"
    address_prefix         = "10.0.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.7"
  }
}

output "password" {
  value = azurerm_windows_virtual_machine.core-services-vm.admin_password
  sensitive = true
}