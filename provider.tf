terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = data.vault_generic_secret.secret_azure.data["client_secret"]
  tenant_id       = var.tenant_id
}

provider "vault" {
  address = "http://127.0.0.1:8200" 
  token   = "hvs.PG7igedPN0RTBohf8bDFqCNO"
}

data "vault_generic_secret" "secret_azure" {
  path = "secret/azure"
}

data "vault_generic_secret" "ssh_key" {
  path = "ssh/public_key"
}