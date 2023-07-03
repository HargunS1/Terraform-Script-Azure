provider "azurerm" {
  features {

  }

}
## Resource Group
resource "azurerm_resource_group" "Testing" {
  name     = "Testing"
  location = "West Europe"
}


resource "tls_private_key" "linux_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "linuxkey" {
  filename="linuxkey.pem"  
  content=tls_private_key.linux_key.private_key_pem 
}

## Virtual Network

resource "azurerm_virtual_network" "vmnetinfa" {
  name                = "vnet1"
  location            = azurerm_resource_group.Testing.location
  resource_group_name = azurerm_resource_group.Testing.name
  address_space       = ["10.0.0.0/16"]

}

## Subnet Resource Group

resource "azurerm_subnet" "Subnet1" {
  name                 = "my-subnet"
  resource_group_name  = azurerm_resource_group.Testing.name
  virtual_network_name = azurerm_virtual_network.vmnetinfa.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.vmnetinfa
  ]

}

## Public Ip for vm connection NIC1
resource "azurerm_public_ip" "app_public_ip" {
  name                = "app-public-ip"
  resource_group_name = azurerm_resource_group.Testing.name
  location            = azurerm_resource_group.Testing.location
  allocation_method   = "Dynamic"

}

# ## Public Ip for vm connection NIC2
# resource "azurerm_public_ip" "app_public1_ip" {
#   name                = "app-public1-ip"
#   resource_group_name = azurerm_resource_group.Testing.name
#   location            = azurerm_resource_group.Testing.location
#   allocation_method   = "Dynamic"

# }

## Network Security Group

resource "azurerm_network_security_group" "Nsg" {
  name                = "TestSecurityGroup1"
  location            = azurerm_resource_group.Testing.location
  resource_group_name = azurerm_resource_group.Testing.name



  security_rule {
   name                       = "Allow_HTTP"
   priority                   = 200
   direction                  = "Inbound"
   access                     = "Allow"
   protocol                   = "Tcp"
   source_port_range          = "*"
   destination_port_range     = "*"
   source_address_prefix      = "*"
   destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "NSgroup" {
  subnet_id                 = azurerm_subnet.Subnet1.id
  network_security_group_id = azurerm_network_security_group.Nsg.id
  depends_on = [
    azurerm_network_security_group.Nsg
  ]
}


## 1st NIC Card

resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = azurerm_resource_group.Testing.location
  resource_group_name = azurerm_resource_group.Testing.name
  enable_accelerated_networking = true
  
  ip_configuration {
    name                          = "nic1-config1"
    subnet_id                     = azurerm_subnet.Subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.app_public_ip.id
  }
  depends_on = [
    azurerm_virtual_network.vmnetinfa,
    azurerm_public_ip.app_public_ip
  ]
}

## 2nd NIC Card
# resource "azurerm_network_interface" "nic2" {
#   name                = "nic2"
#   location            = azurerm_resource_group.Testing.location
#   resource_group_name = azurerm_resource_group.Testing.name
#   enable_accelerated_networking = true
  
#   ip_configuration {
#     name                          = "nic2-config2"
#     subnet_id                     = azurerm_subnet.Subnet1.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id = azurerm_public_ip.app_public1_ip.id
#   }
#   depends_on = [
#     azurerm_virtual_network.vmnetinfa,
#     azurerm_public_ip.app_public1_ip
#   ]
# }

## Vm Creation

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "appvm"
  resource_group_name = azurerm_resource_group.Testing.name
  location            = azurerm_resource_group.Testing.location
  size                = "Standard_F2"
  admin_username      = "linuxusr"
  //admin_password      = "Admin@123"
  //disable_password_authentication = false
  network_interface_ids = [azurerm_network_interface.nic1.id]//azurerm_network_interface.nic2.id


  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "linuxusr"
    public_key = tls_private_key.linux_key.public_key_openssh
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.nic1,
    tls_private_key.linux_key
  ]
}

resource "azurerm_managed_disk" "disk" {
  name                 = "localdiska"
  location             = azurerm_resource_group.Testing.location
  resource_group_name  = azurerm_resource_group.Testing.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "50"

 
}

resource "azurerm_virtual_machine_data_disk_attachment" "example" {
  managed_disk_id    = azurerm_managed_disk.disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.app_vm.id
  lun                = "0"
  caching            = "ReadWrite"
  depends_on = [
    azurerm_linux_virtual_machine.app_vm,
    azurerm_managed_disk.disk
  ]
}

resource "azurerm_availability_set" "app_set" {
  name                = "app-set"
  location            = azurerm_resource_group.Testing.location
  resource_group_name = azurerm_resource_group.Testing.name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3  
  depends_on = [
    azurerm_resource_group.Testing
  ]
}

## To Create Image

##resource "azurerm_image" "example" {
  #name                      = "acctest"
  #location                  = azurerm_resource_group.Testing.location
  #resource_group_name       = azurerm_resource_group.Testing.name
  #source_virtual_machine_id = azurerm_windows_virtual_machine.app_vm.id


#}
## Storage Account
 resource "azurerm_storage_account" "personel" {
  name                     = "hargunstorageaccountname"
  resource_group_name      = azurerm_resource_group.Testing.name
  location                 = azurerm_resource_group.Testing.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

## For Blob Storage 
resource "azurerm_storage_container" "personel2" {
  name                  = "personel2"
  storage_account_name  = azurerm_storage_account.personel.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "filestorage" {
  name                   = "simple.txt"
  storage_account_name   = azurerm_storage_account.personel.name
  storage_container_name = azurerm_storage_container.personel2.name
  type                   = "Block"
  source                 = "simple.txt"
}


# resource "azurerm_virtual_machine_extension" "vm_extension" {
#   name                 = "appvm-extension"
#   virtual_machine_id   = azurerm_linux_virtual_machine.app_vm.id
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"
#   depends_on = [
#     azurerm_storage_blob.filestorage
#   ]
#   settings = <<SETTINGS
#     {
#         "fileUris": [ "https://my.bootstrapscript.com/extend_filesystem.sh}" ],
#         "commandToExecute": "bash extend_filesystem.sh"    
#     }
# SETTINGS

# }