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

variable "location" {
  type        = string
  description = "Azure region for the lab"
  default     = "polandcentral"
}

variable "dns_name_label" {
  type        = string
  description = "Globally unique DNS label for the container"
  default = "lab9b-dns-794uhtrui89"
}

resource "azurerm_resource_group" "az104_rg9" {
  name     = "az104-rg9"
  location = var.location
}

resource "azurerm_container_group" "aci" {
  name                = "az104-c1"
  location            = azurerm_resource_group.az104_rg9.location
  resource_group_name = azurerm_resource_group.az104_rg9.name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = var.dns_name_label

  container {
    name   = "az104-c1"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    cpu    = 1
    memory = 1.5

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}