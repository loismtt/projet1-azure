# Terraform Azure K3s Cluster

Ce dépôt contient un fichier Terraform (`main.tf`) qui permet de déployer une infrastructure Azure pour un cluster K3s léger. Le fichier inclut la configuration de base pour le Resource Group, le réseau, les machines virtuelles et les règles de sécurité. Les secrets sont récupérés depuis HashiCorp Vault.

---

## Table des matières

1. [Prérequis](#prérequis)  
2. [Fichiers principaux](#fichiers-principaux)  
3. [Configuration du provider](#configuration-du-provider)  
4. [Ressources Terraform](#ressources-terraform)  
   - [Resource Group](#resource-group)  
   - [Virtual Network](#virtual-network)  
   - [Subnet](#subnet)  
   - [Network Security Group](#network-security-group)  
   - [Association Subnet ↔ NSG](#association-subnet-nsg)  
   - [Public IPs](#public-ips)  
   - [Network Interfaces](#network-interfaces)  
   - [Machines Virtuelles Linux](#machines-virtuelles-linux)  
5. [Provisioning et K3s](#provisioning-et-k3s)  
6. [Outputs](#outputs)  
7. [Commandes utiles Terraform](#commandes-utiles-terraform)  

---

## Prérequis

- **Terraform >= 1.5.0**  
- **Azure CLI** configuré pour le compte Azure utilisé  
- **HashiCorp Vault** accessible avec un token et des secrets configurés  
- Une clé SSH publique pour l'accès aux VM  

---

## Fichiers principaux

- `main.tf` : contient toute la configuration Terraform pour créer le cluster.  
- `README.md` : explication complète de la configuration et du fonctionnement.  

---

## Configuration du provider

Le fichier Terraform configure deux providers :

### Virtual Network

resource "azurerm_virtual_network" "vnet" {
  name                = "k3s-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

### Subnet

resource "azurerm_subnet" "subnet" {
  name                 = "k3s-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

### Network Security Group

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
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  security_rule {
    name                       = "ICMP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }
}

###  Public IPs

resource "azurerm_public_ip" "k3s" {
  count               = 2
  name                = "k3s-pip-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

### Machines Virtuelles Linux

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


