terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
  default     = "localadmin"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Admin password for the VM"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "polandcentral"
}

resource "azurerm_resource_group" "rg" {
  name     = "az104-rg-region1"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-10-vnet"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_public_ip" "pip" {
  name                = "az104-10-pip0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "az104-10-nic0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                              = "az104-10-vm0"
  location                          = azurerm_resource_group.rg.location
  resource_group_name               = azurerm_resource_group.rg.name
  size                              = "Standard_B2ms"
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.nic.id]
  vm_agent_platform_updates_enabled = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_recovery_services_vault" "vault" {
  name                = "az104-rsv-region1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"
  soft_delete_enabled = true
}

variable "backup_timezone" {
  type        = string
  description = "Time zone for VM backup schedule"
  default     = "UTC"
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "az104-backup"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  timezone            = var.backup_timezone

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }

  instant_restore_retention_days = 2
}

resource "azurerm_backup_protected_vm" "protected_vm" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = azurerm_windows_virtual_machine.vm.id
  backup_policy_id    = azurerm_backup_policy_vm.policy.id
}

output "vm_name" {
  value       = azurerm_windows_virtual_machine.vm.name
  description = "Name of the virtual machine"
}

output "vm_public_ip" {
  value       = azurerm_public_ip.pip.ip_address
  description = "Public IP address of the VM"
}

output "recovery_vault_name" {
  value       = azurerm_recovery_services_vault.vault.name
  description = "Name of the Recovery Services vault"
}

resource "azurerm_storage_account" "backup_logs" {
  name                     = "az104logs${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_monitor_diagnostic_setting" "vault_diagnostics" {
  name                           = "Logs and Metrics to storage"
  target_resource_id             = azurerm_recovery_services_vault.vault.id
  storage_account_id             = azurerm_storage_account.backup_logs.id
  log_analytics_workspace_id     = null
  eventhub_authorization_rule_id = null
  eventhub_name                  = null

  enabled_log {
    category = "AzureBackupReport"
  }

  enabled_log {
    category = "AddonAzureBackupJobs"
  }

  enabled_log {
    category = "AddonAzureBackupAlerts"
  }

  enabled_log {
    category = "AzureSiteRecoveryJobs"
  }

  enabled_log {
    category = "AzureSiteRecoveryEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

output "storage_account_name" {
  value       = azurerm_storage_account.backup_logs.name
  description = "Storage account for diagnostic logs and metrics"
}

resource "azurerm_resource_group" "rg_region2" {
  name     = "az104-rg-region2"
  location = "uksouth"
}

resource "azurerm_recovery_services_vault" "vault_region2" {
  name                = "az104-rsv-region2"
  location            = azurerm_resource_group.rg_region2.location
  resource_group_name = azurerm_resource_group.rg_region2.name
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"
  soft_delete_enabled = true
}

output "secondary_vault_name" {
  value       = azurerm_recovery_services_vault.vault_region2.name
  description = "Secondary Recovery Services vault for disaster recovery"
}

output "secondary_region" {
  value       = azurerm_resource_group.rg_region2.location
  description = "Secondary region for VM replication"
}
