terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "azurerm" {
  features {}
}

data "http" "client_ip" {
  url = "https://api.ipify.org"
}

resource "azurerm_resource_group" "az104-rg7" {
  name     = "az104-rg7"
  location = "germanywestcentral"
}

resource "random_string" "storage_account_name" {
    length  = 8
    lower   = true
    upper   = false
    numeric = true
    special = false
}

resource "azurerm_storage_account" "az104storage" {
  name                     = "staz104${random_string.storage_account_name.result}"
  resource_group_name      = azurerm_resource_group.az104-rg7.name
  location                 = azurerm_resource_group.az104-rg7.location
  account_tier             = "Standard"
  account_replication_type = "RAGRS"

  public_network_access_enabled = true
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = [chomp(data.http.client_ip.response_body)]
    virtual_network_subnet_ids = [azurerm_subnet.vnet1_default.id]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  depends_on = [azurerm_subnet.vnet1_default]
}

resource "azurerm_storage_management_policy" "cooling" {
  storage_account_id = azurerm_storage_account.az104storage.id

  rule {
    name    = "Movetocool"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.az104storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "data_retention" {
  storage_container_resource_manager_id = azurerm_storage_container.data.resource_manager_id
  immutability_period_in_days           = 180
}

resource "azurerm_storage_blob" "sample_data" {
  name                   = "securitytest/orange.jpg"
  storage_account_name   = azurerm_storage_account.az104storage.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  access_tier            = "Hot"
  source                 = "${path.module}/orange.jpg"
}

locals {
  sas_start  = formatdate("YYYY-MM-DD'T'HH:mm'Z'", timeadd(timestamp(), "-24h"))
  sas_expiry = formatdate("YYYY-MM-DD'T'HH:mm'Z'", timeadd(timestamp(), "+24h"))
}

data "azurerm_storage_account_sas" "read_blob" {
  connection_string = azurerm_storage_account.az104storage.primary_connection_string
  https_only        = true
  start             = local.sas_start
  expiry            = local.sas_expiry
  signed_version    = "2020-02-10"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

output "blob_sas_url" {
  description = "Blob SAS URL granting read access from now until tomorrow."
  value       = "https://${azurerm_storage_account.az104storage.name}.blob.core.windows.net/${azurerm_storage_container.data.name}/${azurerm_storage_blob.sample_data.name}${data.azurerm_storage_account_sas.read_blob.sas}"
  sensitive   = true
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  location            = azurerm_resource_group.az104-rg7.location
  resource_group_name = azurerm_resource_group.az104-rg7.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "vnet1_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104-rg7.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_storage_share" "share1" {
  name                = "share1"
  storage_account_name = azurerm_storage_account.az104storage.name
  quota               = 100
  access_tier         = "TransactionOptimized"
}

resource "azurerm_storage_share_directory" "testfolder" {
  name             = "testfolder"
  storage_share_id = azurerm_storage_share.share1.id
}

resource "azurerm_storage_share_file" "uploaded" {
  name              = "testfile.txt"
  storage_share_id  = azurerm_storage_share_directory.testfolder.storage_share_id
  path              = azurerm_storage_share_directory.testfolder.name
  source            = "${path.module}/testfile.txt"
  content_type      = "text/plain"
}