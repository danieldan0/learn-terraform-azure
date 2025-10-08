# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Configure the Azure Active Directory Provider
provider "azuread" {}

# Configure the Azure Resource Manager Provider
provider "azurerm" {
  features {}
}

# Retrieve domain information
data "azuread_domains" "default" {
  only_initial = true
}

locals {
  domain_name = data.azuread_domains.default.domains.0.domain_name
}

# Create user 1
resource "azuread_user" "az104-user1-tf" {
  user_principal_name = format(
    "%s@%s",
    "az104-user1-tf",
    local.domain_name
  )

  password              = "Password123!"
  force_password_change = true

  display_name   = "az104-user1-tf"
  department     = "IT"
  job_title      = "IT Lab Administrator"
  usage_location = "US"
}

# Invite user 2
resource "azuread_invitation" "user2-tf" {
  user_email_address = "sajas36791@aiwanlab.com"
  redirect_url       = "https://myapps.microsoft.com"
  user_display_name  = "user2-tf"
  message {
    body = "Welcome to Azure and our group project"
  }
}

# Create a group
resource "azuread_group" "IT_Lab_Administrators_TF" {
  display_name     = "IT Lab Administrators TF"
  mail_nickname    = "IT_Lab_Administrators_TF"
  security_enabled = true
  description      = "Administrators that manage the IT lab"
  owners           = ["fc529afe-8713-4a30-9701-5ecd27c0d59b"] # Main User Object ID
  members          = [azuread_user.az104-user1-tf.object_id, azuread_invitation.user2-tf.user_id]
}