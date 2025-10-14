variable "subscription_id" {
  type    = string
  default = "c15c583e-73cf-4fd8-8cd3-610b44031006"
}

variable "tenant_id" {
  type    = string
  default = "c371d4f5-b34f-4b06-9e66-517fed904220"
}

variable "client_id" {
  type    = string
  default = "75262a9b-a604-4869-a615-262b73605695"
}

variable "location" {
  type    = string
  default = "France Central"
}

variable "resource_group_name" {
  type    = string
  default = "rg-k3s-cluster"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_vault_path" {
  type    = string
  default = "ssh/public_key"
}