terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.13"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "eastus"

  tags = {
    CostCenter = "000"
  }
}

data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag and its value on resources"
}

data "azurerm_policy_definition" "inherit_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

resource "azapi_resource" "require_tag_assignment" {
  name     = "Require-CostCenter-Tag"
  type     = "Microsoft.Authorization/policyAssignments@2021-06-01"
  location = "eastus"

  body = jsonencode({
    properties = {
      displayName     = "Require Cost Center tag and its value on resources"
      description     = "Require Cost Center tag and its value on all resources in the resource group"
      enforcementMode = "Default"
      parameters = {
        tagName = {
          value = "CostCenter"
        }
        tagValue = {
          value = "000"
        }
      }
      policyDefinitionId = data.azurerm_policy_definition.require_tag.id
    }
  })

  parent_id = azurerm_resource_group.rg2.id
}

resource "azapi_resource" "inherit_tag_assignment" {
  name     = "Inherit-CostCenter-Tag"
  type     = "Microsoft.Authorization/policyAssignments@2021-06-01"
  location = "eastus"

  body = jsonencode({
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName     = "Inherit Cost Center tag and its value 000 from the resource group if missing"
      description     = "Inherit the Cost Center tag and its value 000 from the resource group if missing"
      enforcementMode = "Default"
      parameters = {
        tagName = {
          value = "CostCenter"
        }
      }
      policyDefinitionId = data.azurerm_policy_definition.inherit_tag.id
    }
  })

  parent_id = azurerm_resource_group.rg2.id
}

resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
  notes      = "Prevents accidental deletion of the resource group"

  depends_on = [
    azapi_resource.require_tag_assignment,
    azapi_resource.inherit_tag_assignment
  ]
}

output "resource_group_name" {
  value = azurerm_resource_group.rg2.name
}

output "policies_applied" {
  value = [
    azapi_resource.require_tag_assignment.name,
    azapi_resource.inherit_tag_assignment.name,
  ]
}

output "lock_name" {
  value = azurerm_management_lock.rg_lock.name
}