provider "azurerm" {
  features {}
}

locals {
  private_dns_zones = {
    privatelink-blob-core-windows-net           = "privatelink.blob.core.windows.net"
    privatelink-table-core-windows-net          = "privatelink.table.core.windows.net"
    privatelink-queue-core-windows-net          = "privatelink.queue.core.windows.net"
    privatelink-file-core-windows-net           = "privatelink.file.core.windows.net"
    privatelink-web-core-windows-net            = "privatelink.web.core.windows.net"
    privatelink-dfs-core-windows-net            = "privatelink.dfs.core.windows.net"

  }
}


locals {
  resource_group = "Hargun_RG"
  location = "East Us"
}

resource "azurerm_resource_group" "example" {
  name     = local.resource_group
  location = local.location
}

resource "azurerm_service_plan" "example" {
  name                = "example-app-service-plan"
  resource_group_name = local.resource_group
  location            = local.location
  os_type             = "Windows"
  sku_name            = "S1"
  depends_on = [azurerm_resource_group.example]
}

resource "azurerm_windows_function_app" "example" {
  name                = "translabtechnologies"
  resource_group_name = local.resource_group
  location            = local.location

  storage_account_name       = azurerm_storage_account.example.name
  storage_account_access_key = azurerm_storage_account.example.primary_access_key
  service_plan_id            = azurerm_service_plan.example.id

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"           = "dotnet"
    "FUNCTIONS_EXTENSION_VERSION"        = "~6"
    
  }
  site_config {}
  depends_on = [azurerm_storage_account.example]
}

resource "azurerm_storage_account" "example" {
  name                     = "sda200"
  resource_group_name      = local.resource_group
  location                 = local.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [azurerm_resource_group.example]
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-1"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = local.resource_group
  depends_on = [azurerm_resource_group.example]
}

resource "azurerm_subnet" "example" {
  name                 = "subnetname"
  resource_group_name  = local.resource_group
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on = [azurerm_virtual_network.example]
}

resource "azurerm_private_dns_zone" "private_dns_zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = local.resource_group
  depends_on = [azurerm_resource_group.example]
}
resource "azurerm_private_dns_zone_virtual_network_link" "network_link" {
  for_each              = local.private_dns_zones
  name = "net-link"
  resource_group_name   = local.resource_group
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.example.id
  depends_on            = [azurerm_private_dns_zone.private_dns_zones]
}
resource "azurerm_private_endpoint" "Blob" {
  name                = "Blob-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "blob-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-blob-core-windows-net"].id]
  }
}
resource "azurerm_private_endpoint" "Table" {
  name                = "Table-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "Table-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-table-core-windows-net"].id]
  }
}
resource "azurerm_private_endpoint" "Queue" {
  name                = "Queue-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "Queue-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-queue-core-windows-net"].id]
  }
}
resource "azurerm_private_endpoint" "File" {
  name                = "File-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "File-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-file-core-windows-net"].id]
  }
}
resource "azurerm_private_endpoint" "Web" {
  name                = "Web-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "Web-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-web-core-windows-net"].id]
  }
}
resource "azurerm_private_endpoint" "Dfs" {
  name                = "Dfs-endpoint"
  location            = local.location
  resource_group_name = local.resource_group
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "Dfs-privateserviceconnection"
    private_connection_resource_id = azurerm_windows_function_app.example.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "example1-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-dfs-core-windows-net"].id]
  }
}




