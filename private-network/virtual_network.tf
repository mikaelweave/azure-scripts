resource "azurerm_resource_group" "virtual_network_rg" {
  name     = "${var.base_name}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main_virtual_network" {
  name                = "${var.base_name}-vnet"
  location            = azurerm_resource_group.virtual_network_rg.location
  resource_group_name = azurerm_resource_group.virtual_network_rg.name
  address_space       = var.virtual_network_address_space
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.virtual_network_rg.name
  virtual_network_name = azurerm_virtual_network.main_virtual_network.name
  address_prefixes     = var.gateway_subnet_address_prefix
}

resource "azurerm_subnet" "main_subnet" {
  name                 = "MainSubnet"
  resource_group_name  = azurerm_resource_group.virtual_network_rg.name
  virtual_network_name = azurerm_virtual_network.main_virtual_network.name
  address_prefixes     = var.main_subnet_address_prefix
}

resource "azurerm_private_dns_zone" "main_dns" {
  name                = "${var.base_name}.local"
  resource_group_name = azurerm_resource_group.virtual_network_rg.name
}