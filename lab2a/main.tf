terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
}

data "azuread_domains" "default" {
  only_initial = true
}

locals {
  domain_name = data.azuread_domains.default.domains.0.domain_name
}   

resource "azurerm_management_group" "az104-mg1" {
  name                = "az104-mg1"
  display_name        = "az104-mg1"
}

resource "azuread_group" "helpdesk" {
  display_name = "Helpdesk"
  mail_enabled = false
  mail_nickname = "helpdesk"
  security_enabled = true
}

resource "azurerm_role_assignment" "vm_contributor_helpdesk" {
  scope                = azurerm_management_group.az104-mg1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_group.helpdesk.object_id
}

resource "azurerm_role_definition" "custom_support_request" {
  name        = "Custom Support Request"
  scope       = azurerm_management_group.az104-mg1.id
  description = "A custom contributor role for support requests."

  permissions {
    actions     = ["Microsoft.Support/*"]
    not_actions = ["Microsoft.Support/register/action"]
  }

  assignable_scopes = [
    azurerm_management_group.az104-mg1.id
  ]
}

resource "azurerm_role_assignment" "custom_support_request_helpdesk" {
  scope                = azurerm_management_group.az104-mg1.id
  role_definition_id   = azurerm_role_definition.custom_support_request.role_definition_resource_id
  principal_id         = azuread_group.helpdesk.object_id
}