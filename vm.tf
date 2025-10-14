resource "random_string" "k3s_token" {
  length  = 20
  special = false
}

# --- NIC 1 ---
resource "azurerm_network_interface" "nic1_final" {
  name                = "nic-k3s-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_a.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_subnet.subnet_a,
    azurerm_subnet.subnet_b,
    azurerm_lb.lb
  ]
}

# --- NIC 2 ---
resource "azurerm_network_interface" "nic2_final" {
  name                = "nic-k3s-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet_b.id
    private_ip_address_allocation = "Dynamic"
  }

    depends_on = [
    azurerm_subnet.subnet_a,
    azurerm_subnet.subnet_b,
    azurerm_lb.lb
  ]
}

# --- Association au Backend Pool ---
resource "azurerm_network_interface_backend_address_pool_association" "nic1_bepool" {
  network_interface_id    = azurerm_network_interface.nic1_final.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic2_bepool" {
  network_interface_id    = azurerm_network_interface.nic2_final.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

# --- Association aux règles NAT ---
resource "azurerm_network_interface_nat_rule_association" "nic1_nat" {
  network_interface_id  = azurerm_network_interface.nic1_final.id
  ip_configuration_name = "ipconfig1"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_vm1.id
}

resource "azurerm_network_interface_nat_rule_association" "nic2_nat" {
  network_interface_id  = azurerm_network_interface.nic2_final.id
  ip_configuration_name = "ipconfig1"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_vm2.id
}

# --- NSG association ---
resource "azurerm_network_interface_security_group_association" "nic1_nsg" {
  network_interface_id      = azurerm_network_interface.nic1_final.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [
    azurerm_network_interface.nic1_final,
    azurerm_network_security_group.nsg
  ]
}

resource "azurerm_network_interface_security_group_association" "nic2_nsg" {
  network_interface_id      = azurerm_network_interface.nic2_final.id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [
    azurerm_network_interface.nic2_final,
    azurerm_network_security_group.nsg
  ]
}

# --- VM1 (Server) ---
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "k3s-server"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic1_final.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.vault_generic_secret.ssh_key.data["public_key"]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("./cloudinit/server.tpl", {
    k3s_token = random_string.k3s_token.result,
    NODE_NAME = "k3s-server"
  }))
}

# --- VM2 (Agent) ---
resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "k3s-agent"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic2_final.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.vault_generic_secret.ssh_key.data["public_key"]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("./cloudinit/agent.tpl", {
    k3s_token         = random_string.k3s_token.result,
    server_private_ip = azurerm_network_interface.nic1_final.private_ip_address
  }))
}