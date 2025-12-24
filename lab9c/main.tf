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

resource "azurerm_resource_group" "az104_rg9" {
  name     = "az104-rg9"
  location = "polandcentral"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${azurerm_resource_group.az104_rg9.name}"
  location            = azurerm_resource_group.az104_rg9.location
  resource_group_name = azurerm_resource_group.az104_rg9.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "env" {
  name                       = "my-environment"
  location                   = azurerm_resource_group.az104_rg9.location
  resource_group_name        = azurerm_resource_group.az104_rg9.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "app" {
  name                         = "my-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.az104_rg9.name
  revision_mode                = "Single"

  template {
    container {
      name   = "simple-hello-world-container"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

output "container_app_fqdn" {
  value       = azurerm_container_app.app.ingress[0].fqdn
  description = "FQDN of the Container App"
}
