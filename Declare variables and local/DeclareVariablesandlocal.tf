provider "azurerm" {
  features {}
}

variable storage_account_name {
  type        = string
  default     = "sda2001"
  description = "description"
}

locals {
  resource_group = "Storage"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account_name
  resource_group_name      = local.resource_group
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
}

resource "azurerm_storage_container" "test" {
  name                  = "vhds"
  storage_account_name  = var.storage_account_name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "example" {
  name                   = "simple.txt"
  storage_account_name   = var.storage_account_name
  storage_container_name = azurerm_storage_container.test.name
  type                   = "Block"
  access_tier = "Hot"
  source                 = "simple.txt"
  depends_on = [
    azurerm_storage_container.test
  ]
}

