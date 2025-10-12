terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }

  required_version = ">= 1.5.0"
}

provider "azurerm" {
  features {}
  subscription_id = "c15c583e-73cf-4fd8-8cd3-610b44031006"
  tenant_id       = "c371d4f5-b34f-4b06-9e66-517fed904220"
  client_id       = "75262a9b-a604-4869-a615-262b73605695"
  client_secret   = data.vault_generic_secret.secret_azure.data["client_secret"]
}

provider "vault" {
  address = "http://127.0.0.1:8200"  # Remplace par ton Vault
  token   = "hvs.PG7igedPN0RTBohf8bDFqCNO"
}

# Récupération des secrets depuis Vault
data "vault_generic_secret" "secret_azure" {
  path = "secret/azure"
}

data "vault_generic_secret" "ssh_key" {
  path = "ssh/public_key"
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "k3s-rg"
  location = "France Central"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "k3s-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "k3s-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "k3s-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ICMP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IPs
resource "azurerm_public_ip" "k3s" {
  count               = 2
  name                = "k3s-pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "k3s-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.k3s[count.index].id
  }
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "k3s-vm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.vault_generic_secret.ssh_key.data["public_key"]
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx curl",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "curl -sfL https://get.k3s.io | sh -"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.k3s[count.index].ip_address
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

output "public_ips" {
  value = [for pip in azurerm_public_ip.k3s : pip.ip_address]
}