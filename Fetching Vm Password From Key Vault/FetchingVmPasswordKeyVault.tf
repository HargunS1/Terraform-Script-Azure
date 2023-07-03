provider "azurerm" {
  features {}
}

# locals {
#   resource_group_name = "example"
#   location = "West Us"
# }


resource "azurerm_resource_group" "example" {
  name     = "example"
  location = "West Us"
}

data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "example" {
  name                ="test-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  depends_on = [
    azurerm_resource_group.example
  ]
}


resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  =  azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on=[
    azurerm_resource_group.example
  ]
}

resource "azurerm_public_ip" "example" {
  name                    = "test-pip"
  location                =azurerm_resource_group.example.location
  resource_group_name     =  azurerm_resource_group.example.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name =  azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
  depends_on = [
    azurerm_public_ip.example,
    azurerm_subnet.example
  ]
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name =  azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.password.value
  availability_set_id = azurerm_availability_set.example.id
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.example,
    azurerm_availability_set.example,
    azurerm_key_vault_secret.password
  ]
}

resource "azurerm_availability_set" "example" {
  name                = "example-aset"
  location            = azurerm_resource_group.example.location
  resource_group_name =  azurerm_resource_group.example.name
  platform_update_domain_count = "5"
  platform_fault_domain_count = "3"
  managed = "true"
}

resource "azurerm_storage_account" "example" {
  name                     = "sda2001"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_kind = "BlobStorage"
  account_replication_type = "LRS"
  //allow_blob_public_access = "true"
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "blob"
  depends_on = [
    azurerm_storage_account.example
  ]
}

resource "azurerm_storage_blob" "example" {
  name                   = "IIS_Config.ps1"
  storage_account_name   = azurerm_storage_account.example.name
  storage_container_name = azurerm_storage_container.data.name
  type                   = "Block"
  source                 = "IIS_Config.ps1"
  depends_on = [
    azurerm_storage_container.data
  ]
}

resource "azurerm_key_vault" "example" {
  name                        = "examplekeyvault001"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore" , "Set"
    ]

    storage_permissions = [
      "Get",
    ]
  }
  depends_on = [
    azurerm_resource_group.example
  ]
} 

resource "azurerm_key_vault_secret" "password" {
  name         = "vmpassword"
  value        = "Admin@123"
  key_vault_id = azurerm_key_vault.example.id
  depends_on = [
    azurerm_key_vault.example
  ]
}