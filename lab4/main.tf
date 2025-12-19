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

resource "azurerm_resource_group" "az104-rg4" {
  name     = "az104-rg4"
  location = "polandcentral"
}

resource "azurerm_virtual_network" "core-services-vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.az104-rg4.location
  resource_group_name = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_subnet" "shared-services-subnet" {
  name                 = "SharedServicesSubnet"
  address_prefixes     = ["10.20.10.0/24"]
  virtual_network_name = azurerm_virtual_network.core-services-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_subnet" "database-subnet" {
  name                 = "DatabaseSubnet"
  address_prefixes     = ["10.20.20.0/24"]
  virtual_network_name = azurerm_virtual_network.core-services-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_virtual_network" "manufacturing-vnet" {
  name                     = "ManufacturingVnet"
  resource_group_name      = azurerm_resource_group.az104-rg4.name
  location                 = azurerm_resource_group.az104-rg4.location
  address_space            = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "sensor-subnet1" {
  name                 = "SensorSubnet1"
  address_prefixes     = ["10.30.10.0/24"]
  virtual_network_name = azurerm_virtual_network.manufacturing-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_subnet" "sensor-subnet2" {
  name                 = "SensorSubnet2"
  address_prefixes     = ["10.30.20.0/24"]
  virtual_network_name = azurerm_virtual_network.manufacturing-vnet.name
  resource_group_name  = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_application_security_group" "asg-web" {
  name                = "asg-web"
  location            = azurerm_resource_group.az104-rg4.location
  resource_group_name = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_network_security_group" "mynsgsecure" {
  name                = "myNSGSecure"
  location            = azurerm_resource_group.az104-rg4.location
  resource_group_name = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_subnet_network_security_group_association" "nsg-association" {
  subnet_id                 = azurerm_subnet.shared-services-subnet.id
  network_security_group_id = azurerm_network_security_group.mynsgsecure.id
}

resource "azurerm_network_security_rule" "allow-asg" {
  name                        = "AllowASG"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.az104-rg4.name
  network_security_group_name = azurerm_network_security_group.mynsgsecure.name
  source_application_security_group_ids = [azurerm_application_security_group.asg-web.id]
}

resource "azurerm_network_security_rule" "deny-internet-outbound" {
  name                        = "DenyInternetOutbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.az104-rg4.name
  network_security_group_name = azurerm_network_security_group.mynsgsecure.name
}

resource "azurerm_dns_zone" "mydnszone" {
  name                = "dancontoso.com"
  resource_group_name = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_dns_a_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.mydnszone.name
  resource_group_name = azurerm_resource_group.az104-rg4.name
  ttl                 = 1
  records             = ["10.1.1.4"]
}

resource "azurerm_private_dns_zone" "myprivatednszone" {
  name                = "private.dancontoso.com"
  resource_group_name = azurerm_resource_group.az104-rg4.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "manufacturing-link" {
  name                  = "manufacturing-link"
  resource_group_name   = azurerm_resource_group.az104-rg4.name
  private_dns_zone_name = azurerm_private_dns_zone.myprivatednszone.name
  virtual_network_id    = azurerm_virtual_network.manufacturing-vnet.id
}

resource "azurerm_private_dns_a_record" "sensorvm" {
  name                = "sensorvm"
  zone_name           = azurerm_private_dns_zone.myprivatednszone.name
  resource_group_name = azurerm_resource_group.az104-rg4.name
  ttl                 = 1
  records             = ["10.1.1.14"]
}