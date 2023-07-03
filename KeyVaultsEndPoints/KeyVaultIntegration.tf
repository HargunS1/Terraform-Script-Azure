# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

locals {
  private_dns_zones = {
    # privatelink-blob-core-windows-net           = "privatelink.blob.core.windows.net"
    # privatelink-table-core-windows-net          = "privatelink.table.core.windows.net"
    # privatelink-queue-core-windows-net          = "privatelink.queue.core.windows.net"
    # privatelink-file-core-windows-net           = "privatelink.file.core.windows.net"
    # privatelink-web-core-windows-net            = "privatelink.web.core.windows.net"
    # privatelink-dfs-core-windows-net            = "privatelink.dfs.core.windows.net"
     privatelink-vaultcore-azure-net             = "privatelink.vaultcore.azure.net"
    
  }
}

resource "azurerm_resource_group" "Testing" {
  name     = "Testing"
  location = "eastUS2"
}

resource "azurerm_private_dns_zone" "private_dns_zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.Testing.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "eastus2-vnet"
  location            = azurerm_resource_group.Testing.location
  resource_group_name = azurerm_resource_group.Testing.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "Subnet1" {
  name                 = "Subnet-1"
  resource_group_name  = azurerm_resource_group.Testing.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "PE_Subnet1" {
  name                                           = "PE_Subnet1"
  resource_group_name                            = azurerm_resource_group.Testing.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.1.2.0/24"]
  enforce_private_link_endpoint_network_policies = true
  depends_on                                     = [azurerm_virtual_network.vnet]
}

###Here's our private dns links #####
resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_network_links" {
  for_each              = local.private_dns_zones
  name                  = "${azurerm_virtual_network.vnet.name}-link"
  resource_group_name   = azurerm_resource_group.Testing.name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.vnet.id
  depends_on            = [azurerm_private_dns_zone.private_dns_zones]
}
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "example" {
  name                       = "examplekeyvault01"
  location                   = azurerm_resource_group.Testing.location
  resource_group_name        = azurerm_resource_group.Testing.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Set",
    ]
  }
}

resource "azurerm_key_vault_key" "generated" {
  name         = "generated-certificate"
  key_vault_id = azurerm_key_vault.example.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}


resource "azurerm_private_endpoint" "main" {
  name                = "${azurerm_key_vault.example.name}-pe"
  resource_group_name = azurerm_resource_group.Testing.name
  location            = azurerm_resource_group.Testing.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-vaultcore-azure-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.example.id
    name                           = "${azurerm_key_vault.example.name}-psc"
    subresource_names              = ["vault"]
  }
  depends_on = [azurerm_key_vault.example]
}

resource "azurerm_role_assignment" "terraform_spn" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}