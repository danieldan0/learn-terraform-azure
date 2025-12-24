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

variable "web_app_name" {
  type        = string
  description = "Globally unique name for the web app"
}

resource "azurerm_resource_group" "az104_rg9" {
  name     = "az104-rg9"
  location = "polandcentral"
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = "asp-${var.web_app_name}"
  location            = azurerm_resource_group.az104_rg9.location
  resource_group_name = azurerm_resource_group.az104_rg9.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "web_app" {
  name                = var.web_app_name
  location            = azurerm_resource_group.az104_rg9.location
  resource_group_name = azurerm_resource_group.az104_rg9.name
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  site_config {
    application_stack {
      php_version = "8.2"
    }
  }
}

resource "azurerm_linux_web_app_slot" "staging_slot" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.web_app.id

  site_config {
    application_stack {
      php_version = "8.2"
    }
  }
}

resource "azurerm_app_service_source_control" "staging_deployment" {
  app_id             = azurerm_linux_web_app_slot.staging_slot.app_service_id
  repo_url           = "https://github.com/Azure-Samples/php-docs-hello-world"
  branch             = "master"
  use_manual_integration = false
  use_mercurial      = false
}

resource "azurerm_monitor_autoscale_setting" "app_service_autoscale" {
  name                = "asp-autoscale-${var.web_app_name}"
  resource_group_name = azurerm_resource_group.az104_rg9.name
  location            = azurerm_resource_group.az104_rg9.location
  target_resource_id  = azurerm_service_plan.app_service_plan.id

  profile {
    name = "Auto scale based on CPU"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.app_service_plan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.app_service_plan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
}

output "web_app_url" {
  value = azurerm_linux_web_app.web_app.default_hostname
  description = "Default URL of the production web app"
}

output "staging_slot_url" {
  value = azurerm_linux_web_app_slot.staging_slot.default_hostname
  description = "Default URL of the staging deployment slot"
}
