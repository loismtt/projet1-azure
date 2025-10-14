resource "azurerm_lb" "lb" {
  name                = "lb-k3s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicFrontend"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  depends_on = [
    azurerm_subnet.subnet_a,
    azurerm_subnet.subnet_b,
    azurerm_public_ip.lb_public_ip
  ]
}


resource "azurerm_lb_backend_address_pool" "bepool" {
  name            = "backendpool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "http_probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  request_path        = "/"
  port                = 80
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "http_rule" {
  name                           = "HTTPRule"
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = "PublicFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bepool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
}

resource "azurerm_lb_nat_rule" "ssh_vm1" {
  name                           = "ssh-vm1"
  resource_group_name            = azurerm_resource_group.rg.name # ✅ ajouté
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = "PublicFrontend"
  protocol                       = "Tcp"
  frontend_port                  = 50001
  backend_port                   = 22
}

resource "azurerm_lb_nat_rule" "ssh_vm2" {
  name                           = "ssh-vm2"
  resource_group_name            = azurerm_resource_group.rg.name # ✅ ajouté
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = "PublicFrontend"
  protocol                       = "Tcp"
  frontend_port                  = 50002
  backend_port                   = 22
}