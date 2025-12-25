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
  description = "Admin username for the virtual machine"
  default     = "localadmin"
}

variable "admin_password" {
  type        = string
  description = "Admin password for the virtual machine"
  sensitive   = true
}

variable "location" {
  type        = string
  description = "Azure region for resources"
  default     = "polandcentral"
}

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications"
  default     = "admin@contoso.com"
}

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name     = "az104-rg11"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "az104-nsg01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "default-allow-rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "az104-pip0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "az104-nic0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_storage_account" "diagnostics" {
  name                     = "az10411${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "az104-vm0"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

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

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "az104-workspace-${random_string.storage_suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "dependency_agent" {
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_virtual_machine_extension.ama]
}

resource "azurerm_monitor_data_collection_rule" "vm_insights" {
  name                = "MSVMI-az104-workspace-${random_string.storage_suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
      name                  = "VMInsightsPerf-Logs-Dest"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["VMInsightsPerf-Logs-Dest"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\VmInsights\\DetailedMetrics"
      ]
      name = "VMInsightsPerfCounters"
    }
  }
}

# Associate Data Collection Rule with VM
resource "azurerm_monitor_data_collection_rule_association" "vm_insights" {
  name                    = "VMInsights-Dcr-Association"
  target_resource_id      = azurerm_windows_virtual_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_insights.id

  depends_on = [
    azurerm_virtual_machine_extension.ama,
    azurerm_virtual_machine_extension.dependency_agent
  ]
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group"
}

output "vm_name" {
  value       = azurerm_windows_virtual_machine.vm.name
  description = "The name of the virtual machine"
}

output "vm_public_ip" {
  value       = azurerm_public_ip.pip.ip_address
  description = "The public IP address of the virtual machine"
}

output "workspace_name" {
  value       = azurerm_log_analytics_workspace.workspace.name
  description = "The name of the Log Analytics workspace"
}

resource "azurerm_monitor_action_group" "vm_alerts" {
  name                = "Alert the operations team"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "AlertOps"

  email_receiver {
    name          = "VM was deleted"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_activity_log_alert" "vm_delete" {
  name                = "VM was deleted"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [data.azurerm_subscription.current.id]
  description         = "A VM in your resource group was deleted"

  criteria {
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    category       = "Administrative"
  }

  action {
    action_group_id = azurerm_monitor_action_group.vm_alerts.id
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_monitor_alert_processing_rule_suppression" "maintenance" {
  name                = "Planned-Maintenance"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_resource_group.rg.id]
  description         = "Suppress notifications during planned maintenance."

  schedule {
    effective_from  = "2025-12-25T22:00:00"
    effective_until = "2025-12-26T07:00:00"
    time_zone       = "UTC"
  }
}

output "alert_rule_name" {
  value       = azurerm_monitor_activity_log_alert.vm_delete.name
  description = "The name of the VM deletion alert rule"
}

output "maintenance_rule_name" {
  value       = azurerm_monitor_alert_processing_rule_suppression.maintenance.name
  description = "The name of the maintenance suppression rule"
}