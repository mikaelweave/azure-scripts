resource "azurerm_network_interface" "main_vm_nic" {
  name                 = "${var.base_name}-main-nic"
  location             = azurerm_resource_group.virtual_network_rg.location
  resource_group_name  = azurerm_resource_group.virtual_network_rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "${var.base_name}-main-vm-ip"
    subnet_id                     = azurerm_subnet.main_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.100.16.13"
  }
}

resource "azurerm_windows_virtual_machine" "main_vm" {
  name                  = "${var.base_name}-main-vm"
  computer_name         = "${length(var.base_name) > 9 ? substr(var.base_name, 0, 8) : var.base_name}mainvm"
  location              = azurerm_resource_group.virtual_network_rg.location
  resource_group_name   = azurerm_resource_group.virtual_network_rg.name
  network_interface_ids = [azurerm_network_interface.main_vm_nic.id]
  size                  = var.vm_size
  admin_username        = var.vm_username
  admin_password        = var.vm_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "20h1-pro"
    version   = "latest"
  }
}
