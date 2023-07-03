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
  admin_password      = "Admin@123"
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
    azurerm_availability_set.example
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

resource "azurerm_virtual_machine_extension" "test" {
  name                 = "appvm-extension"
  virtual_machine_id = azurerm_windows_virtual_machine.example.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.example
  ]

  settings = <<SETTINGS
    {
        
        "fileUris": ["https://${azurerm_storage_account.example.name}.blob.core.windows.net/data/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    
    }
SETTINGS
}