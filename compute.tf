resource "azurerm_network_interface" "vm" {
  for_each = var.spokes

  name                = "nic-${var.prefix}-${each.key}-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.vm_private_ip
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = var.spokes

  name                            = "vm-${var.prefix}-${each.key}"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id,
  ]
  tags = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.prefix}-${each.key}-vm"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Managed boot diagnostics (no storage account needed). Enables the
  # serial console and boot screenshot for troubleshooting.
  boot_diagnostics {}

  # Make sure the NSG and (when enabled) the route to the firewall are in
  # place before the VM boots.
  depends_on = [
    azurerm_subnet_network_security_group_association.workload,
    azurerm_subnet_route_table_association.workload,
  ]
}
