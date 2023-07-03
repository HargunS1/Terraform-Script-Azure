provider "azurerm" {
  features {}
}

locals {
  resource_group = "PrivateEndpoint"
  location = "East Us"
}

locals {
  private_dns_zones = {
    privatelink-blob-core-windows-net           = "privatelink.blob.core.windows.net"
    privatelink-table-core-windows-net          = "privatelink.table.core.windows.net"
    privatelink-queue-core-windows-net          = "privatelink.queue.core.windows.net"
    privatelink-file-core-windows-net           = "privatelink.file.core.windows.net"
    //privatelink-web-core-windows-net            = "privatelink.web.core.windows.net"
    privatelink-dfs-core-windows-net            = "privatelink.dfs.core.windows.net"

  }
}



resource "azurerm_resource_group" "example" {
  name     = local.resource_group
  location = local.location
}

resource "azurerm_storage_account" "example" {
  name                     = "sda2001"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "ForPrivateEnpoint"
  }
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  location            = local.location
  resource_group_name = local.resource_group
  address_space       = ["10.0.0.0/16"]
  depends_on = [azurerm_resource_group.example]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet0"
  address_prefixes     = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.example.name
  resource_group_name  = local.resource_group
  private_endpoint_network_policies_enabled = true
  depends_on = [azurerm_virtual_network.example, azurerm_resource_group.example]
}


resource "azurerm_subnet" "PE_Subnet1" {
  name                                           = "PE_Subnet1"
  resource_group_name                            = local.resource_group
  virtual_network_name                           = azurerm_virtual_network.example.name
  address_prefixes                               = ["10.0.1.0/24"]
  enforce_private_link_endpoint_network_policies = true
  depends_on                                     = [azurerm_virtual_network.example, azurerm_resource_group.example]
}

resource "azurerm_private_dns_zone" "private_dns_zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = local.resource_group
  depends_on = [azurerm_resource_group.example]
}

# Create Private DNS Zone Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  for_each              = local.private_dns_zones
  name = "net-link"
  resource_group_name   = local.resource_group
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.example.id
  depends_on            = [azurerm_private_dns_zone.private_dns_zones]
}

resource "azurerm_private_endpoint" "Blob" {
  name                = "BlobEndpoint"
  resource_group_name = local.resource_group
  location            = local.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-blob-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    name                           = "${azurerm_storage_account.example.name}-psc"
    subresource_names              = ["blob"]
  }
  depends_on = [azurerm_storage_account.example, azurerm_resource_group.example]
}

resource "azurerm_private_endpoint" "File" {
  name                = "FileEndpoint"
  resource_group_name = local.resource_group
  location            = local.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-file-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    name                           = "${azurerm_storage_account.example.name}-psc"
    subresource_names              = ["file"]
  }
  depends_on = [azurerm_storage_account.example, azurerm_resource_group.example]
}

resource "azurerm_private_endpoint" "Table" {
  name                = "TableEndpoint"
  resource_group_name = local.resource_group
  location            = local.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-table-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    name                           = "${azurerm_storage_account.example.name}-psc"
    subresource_names              = ["table"]
  }
  depends_on = [azurerm_storage_account.example, azurerm_resource_group.example]
}

resource "azurerm_private_endpoint" "Queue" {
  name                = "QueueEndpoint"
  resource_group_name = local.resource_group
  location            = local.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-queue-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    name                           = "${azurerm_storage_account.example.name}-psc"
    subresource_names              = ["queue"]
  }
  depends_on = [azurerm_storage_account.example, azurerm_resource_group.example]
}

resource "azurerm_private_endpoint" "Dfs" {
  name                = "DfsEndpoint"
  resource_group_name = local.resource_group
  location            = local.location
  subnet_id           = azurerm_subnet.PE_Subnet1.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-dfs-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.example.id
    name                           = "${azurerm_storage_account.example.name}-psc"
    subresource_names              = ["dfs"]
  }
  depends_on = [azurerm_storage_account.example, azurerm_resource_group.example]
}

