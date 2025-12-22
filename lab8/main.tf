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

variable "admin_password" {
  type      = string
  sensitive = true
  description = "Password for localadmin on Windows VMs"
}

resource "azurerm_resource_group" "az104_rg8" {
  name     = "az104-rg8"
  location = "polandcentral"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-vnet8"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.az104_rg8.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "vm1_nic" {
  name                = "az104-vm1-nic"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  depends_on          = [azurerm_subnet.subnet]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "az104-vm2-nic"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  depends_on          = [azurerm_subnet.subnet]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

locals {
  windows_image = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-gensecond"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "vm1" {
  name                = "az104-vm1"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm1_nic.id]
  zone                 = "1"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = local.windows_image.publisher
    offer     = local.windows_image.offer
    sku       = local.windows_image.sku
    version   = local.windows_image.version
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_managed_disk" "vm1_disk1" {
  name                 = "vm1-disk1"
  location             = azurerm_resource_group.az104_rg8.location
  resource_group_name  = azurerm_resource_group.az104_rg8.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  zone                 = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm1_disk1_attach" {
  managed_disk_id    = azurerm_managed_disk.vm1_disk1.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm1.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_windows_virtual_machine" "vm2" {
  name                = "az104-vm2"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm2_nic.id]
  zone                 = "2"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = local.windows_image.publisher
    offer     = local.windows_image.offer
    sku       = local.windows_image.sku
    version   = local.windows_image.version
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_virtual_network" "vmss_vnet" {
  name                = "vmss-vnet"
  address_space       = ["10.82.0.0/20"]
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
}

resource "azurerm_subnet" "vmss_subnet" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.az104_rg8.name
  virtual_network_name = azurerm_virtual_network.vmss_vnet.name
  address_prefixes     = ["10.82.0.0/24"]
  depends_on           = [azurerm_virtual_network.vmss_vnet]
}

resource "azurerm_network_security_group" "vmss_nsg" {
  name                = "vmss1-nsg"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name

  security_rule {
    name                       = "allow-http"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vmss_lb_pip" {
  name                = "vmss-lb-pip"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "vmss_lb" {
  name                = "vmss-lb"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "vmss_backend_pool" {
  name            = "vmss-backend-pool"
  loadbalancer_id = azurerm_lb.vmss_lb.id
}

resource "azurerm_lb_probe" "vmss_probe" {
  name            = "http-probe"
  loadbalancer_id = azurerm_lb.vmss_lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "vmss_lb_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.vmss_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss_backend_pool.id]
  probe_id                       = azurerm_lb_probe.vmss_probe.id
  depends_on                     = [
    azurerm_lb_probe.vmss_probe,
    azurerm_lb_backend_address_pool.vmss_backend_pool,
    azurerm_lb.vmss_lb
  ]
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss1" {
  name                = "vmss1"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  sku                 = "Standard_B2ms"
  instances           = 1
  admin_username      = "localadmin"
  admin_password      = var.admin_password
  zones               = ["1", "2", "3"]
  depends_on          = [
    azurerm_lb_backend_address_pool.vmss_backend_pool,
    azurerm_network_security_group.vmss_nsg,
    azurerm_subnet.vmss_subnet
  ]

  source_image_reference {
    publisher = local.windows_image.publisher
    offer     = local.windows_image.offer
    sku       = local.windows_image.sku
    version   = local.windows_image.version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name                      = "vmss1-nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.vmss_nsg.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss_backend_pool.id]
    }
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "vmss1-autoscale"
  location            = azurerm_resource_group.az104_rg8.location
  resource_group_name = azurerm_resource_group.az104_rg8.name
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss1.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 6
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }
  }
}