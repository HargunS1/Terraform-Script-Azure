provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "Storage" {
  name     = "Storage"
  location = "West Europe"
}

resource "azurerm_storage_account" "example" {
  name                     = "examplestoraccount"
  resource_group_name      = azurerm_resource_group.Storage.name
  location                 = azurerm_resource_group.Storage.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
}

resource "azurerm_storage_container" "test" {
  name                  = "vhds"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "example" {
  name                   = "simple.txt"
  storage_account_name   = azurerm_storage_account.example.name
  storage_container_name = azurerm_storage_container.test.name
  type                   = "Block"
  access_tier = "Hot"
  source                 = "simple.txt"
  depends_on = [
    azurerm_storage_container.test
  ]
}

