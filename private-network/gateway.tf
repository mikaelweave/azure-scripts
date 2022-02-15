#module "azure_vpn" {
#    source = "avinor/vpn/azurerm"
#    version = "1.1.0"
#
#    name = var.base_name
#    resource_group_name = azurerm_resource_group.virtual_network_rg.name
#    location = azurerm_resource_group.virtual_network_rg.location
#    subnet_id = azurerm_subnet.gateway_subnet.id
#    sku = var.virtual_network_gateway_sku
#}