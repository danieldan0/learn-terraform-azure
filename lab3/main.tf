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

resource "azurerm_resource_group" "rg3" {
  name     = "az104-rg3"
  location = "polandcentral"
}

resource "azurerm_managed_disk" "disk1" {
  name                 = "az104-disk1"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 32
  create_option        = "Empty"
}

resource "azurerm_managed_disk" "disk2" {
  name                 = "az104-disk2"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 32
  create_option        = "Empty"
}

resource "azurerm_storage_account" "staccount" {
  name                     = "az104staccountlab3"
  resource_group_name      = azurerm_resource_group.rg3.name
  location                 = azurerm_resource_group.rg3.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  
}

resource "azurerm_storage_share" "fileshare" {
  name                 = "fs-cloudshell"
  storage_account_name = azurerm_storage_account.staccount.name
  quota                = 1024
}

resource "azurerm_managed_disk" "disk3" {
  name                 = "az104-disk3"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 32
  create_option        = "Empty"
}

resource "azurerm_managed_disk" "disk4" {
  name                 = "az104-disk4"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = 32
  create_option        = "Empty"
}

resource "azurerm_managed_disk" "disk5" {
  name                 = "az104-disk5"
  location             = azurerm_resource_group.rg3.location
  resource_group_name  = azurerm_resource_group.rg3.name
  storage_account_type = "StandardSSD_LRS"
  disk_size_gb         = 32
  create_option        = "Empty"
}

output "resource_group_name" {
  value = azurerm_resource_group.rg3.name
}

output "location" {
  value = azurerm_resource_group.rg3.location
}

output "disks" {
  value = [
    azurerm_managed_disk.disk1.name,
    azurerm_managed_disk.disk2.name,
    azurerm_managed_disk.disk3.name,
    azurerm_managed_disk.disk4.name,
    azurerm_managed_disk.disk5.name
  ]
}