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

resource "azurerm_resource_group" "az104-rg6" {
  name     = "az104-rg6"
  location = "polandcentral"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# resource "azurerm_resource_group_template_deployment" "networking" {
#   name                = "networking-deployment"
#   resource_group_name = azurerm_resource_group.az104-rg6.name
#   template_content    = file("${path.module}/az104-06-vms-template.json")
#   deployment_mode     = "Incremental"
#   parameters_content = jsonencode({
#     adminPassword = {
#       value = random_password.password.result
#     }
#   })
#   depends_on = [azurerm_resource_group.az104-rg6]
# }

resource "azurerm_public_ip" "az104-lbpip" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.az104-rg6.location
  resource_group_name = azurerm_resource_group.az104-rg6.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "az104-lb" {
  name                = "az104-lb"
  location            = azurerm_resource_group.az104-rg6.location
  resource_group_name = azurerm_resource_group.az104-rg6.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.az104-lbpip.id
  }
}

resource "azurerm_lb_backend_address_pool" "az104-be" {
  name            = "az104-be"
  loadbalancer_id = azurerm_lb.az104-lb.id
}

data "azurerm_virtual_network" "az104-06-vnet1" {
  name                = "az104-06-vnet1"
  resource_group_name = azurerm_resource_group.az104-rg6.name
}

data "azurerm_network_interface" "vm0" {
  name                = "az104-06-nic0"
  resource_group_name = azurerm_resource_group.az104-rg6.name
}

data "azurerm_network_interface" "vm1" {
  name                = "az104-06-nic1"
  resource_group_name = azurerm_resource_group.az104-rg6.name
}

data "azurerm_network_interface" "nic2" {
  name                = "az104-06-nic2"
  resource_group_name = azurerm_resource_group.az104-rg6.name
}

resource "azurerm_network_interface_backend_address_pool_association" "vm0" {
  network_interface_id    = data.azurerm_network_interface.vm0.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az104-be.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm1" {
  network_interface_id    = data.azurerm_network_interface.vm1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az104-be.id
}

resource "azurerm_lb_probe" "az104-hp" {
  name                = "az104-hp"
  loadbalancer_id     = azurerm_lb.az104-lb.id
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "az104-lbrule" {
  name                           = "az104-lbrule"
  loadbalancer_id                = azurerm_lb.az104-lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.az104-be.id]
  probe_id                       = azurerm_lb_probe.az104-hp.id
}

resource "azurerm_subnet" "subnet-appgw" {
  name                 = "subnet-appgw"
  virtual_network_name = data.azurerm_virtual_network.az104-06-vnet1.name
  resource_group_name  = azurerm_resource_group.az104-rg6.name
  address_prefixes     = ["10.60.3.224/27"]
}

resource "azurerm_public_ip" "az104-gwpip" {
  name                = "az104-gwpip"
  location            = azurerm_resource_group.az104-rg6.location
  resource_group_name = azurerm_resource_group.az104-rg6.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "az104-appgw" {
  name                = "az104-appgw"
  location            = azurerm_resource_group.az104-rg6.location
  resource_group_name = azurerm_resource_group.az104-rg6.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet-appgw.id
  }

  frontend_port {
    name = "appgw-frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.az104-gwpip.id
  }

  backend_address_pool {
    name = "az104-appgwbe"
  }

  backend_address_pool {
    name = "az104-imagebe"
  }

  backend_address_pool {
    name = "az104-videobe"
  }

  backend_http_settings {
    name                  = "appgw-besettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  backend_http_settings {
    name                  = "az104-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "az104-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "appgw-frontend-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                = "az104-gwrule"
    priority            = 10
    rule_type           = "PathBasedRouting"
    http_listener_name  = "az104-listener"
    url_path_map_name   = "az104-pathmap"
  }

  url_path_map {
    name                               = "az104-pathmap"
    default_backend_address_pool_name  = "az104-appgwbe"
    default_backend_http_settings_name = "az104-http"

    path_rule {
      name                       = "images"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "az104-http"
    }

    path_rule {
      name                       = "videos"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "az104-http"
    }
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }
}

data "azurerm_application_gateway" "az104-appgw" {
  name                = azurerm_application_gateway.az104-appgw.name
  resource_group_name = azurerm_resource_group.az104-rg6.name
}

locals {
  appgw_backend_pool     = [for pool in data.azurerm_application_gateway.az104-appgw.backend_address_pool : pool.id if pool.name == "az104-appgwbe"][0]
  image_backend_pool     = [for pool in data.azurerm_application_gateway.az104-appgw.backend_address_pool : pool.id if pool.name == "az104-imagebe"][0]
  video_backend_pool     = [for pool in data.azurerm_application_gateway.az104-appgw.backend_address_pool : pool.id if pool.name == "az104-videobe"][0]
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic1" {
  network_interface_id    = data.azurerm_network_interface.vm1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = local.image_backend_pool
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic2" {
  network_interface_id    = data.azurerm_network_interface.nic2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = local.video_backend_pool
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic1_default" {
  network_interface_id    = data.azurerm_network_interface.vm1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = local.appgw_backend_pool
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nic2_default" {
  network_interface_id    = data.azurerm_network_interface.nic2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = local.appgw_backend_pool
}

output "admin_password" {
  value       = random_password.password.result
  description = "The admin password for the virtual machines."
  sensitive   = true
}