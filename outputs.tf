output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_public_ip.ip_address
}

output "vm_private_ips" {
  value = {
    vm1 = azurerm_network_interface.nic1_final.private_ip_address
    vm2 = azurerm_network_interface.nic2_final.private_ip_address
  }
}

output "ssh_jump_ports" {
  value = {
    vm1 = 50001
    vm2 = 50002
  }
}
