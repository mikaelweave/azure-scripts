provider "azurerm" {
  version = "=1.41.0"
}

data "azurerm_client_config" "current" {}

variable "spnObjectId" {
    type = string
}

variable "spnAppId" {
    type = string
}

# Resource Group
resource "azurerm_resource_group" "data-pipeline-rg" {
  name     = "data-pipeline-rg"
  location = "westus2"
}

# Give SPN Contributor to rg
resource "azurerm_role_assignment" "master-spn" {
  scope                = azurerm_resource_group.data-pipeline-rg.id
  role_definition_name = "Contributor"
  principal_id         = var.spnObjectId
}

# Storage to be used in pipeline
resource "azurerm_storage_account" "data-pipeline-storage" {
  name                      = "data0pipeline0stor"
  resource_group_name       = azurerm_resource_group.data-pipeline-rg.name
  location                  = azurerm_resource_group.data-pipeline-rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = "true"
  account_kind              = "StorageV2"
  is_hns_enabled            = "true"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "lake" {
  name               = "lake"
  storage_account_id = azurerm_storage_account.data-pipeline-storage.id
}

# Data factory
resource "azurerm_data_factory" "adf" {
  name                = "data-pipeline-adf"
  location            = azurerm_resource_group.data-pipeline-rg.location
  resource_group_name = azurerm_resource_group.data-pipeline-rg.name
  identity {
    type = "SystemAssigned"
  }
}

# Data bricks
resource "azurerm_databricks_workspace" "databricks" {
  name                = "data-pipel-logging-databricks"
  resource_group_name = azurerm_resource_group.data-pipeline-rg.name
  location            = azurerm_resource_group.data-pipeline-rg.location
  sku                 = "premium"
}

# Key Vault for access
resource "azurerm_key_vault" "secrets" {
  name                        = "data-pipel-logging-vault"
  location                    = azurerm_resource_group.data-pipeline-rg.location
  resource_group_name         = azurerm_resource_group.data-pipeline-rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = "57b45b2d-27ee-41dc-b1ae-70b1bc83030c"

    secret_permissions = [
      "get",
      "set",
      "list"
    ]
  }
}

# Master token
resource "azurerm_key_vault_secret" "databricks-master-token" {
  name         = "databricks-master-token"
  value        = ""
  key_vault_id = azurerm_key_vault.secrets.id
}

# SQL DW for target
resource "azurerm_sql_firewall_rule" "dw-azure-services" {
    name = "AllowAllWindowsAzureIps"
    resource_group_name = azurerm_resource_group.data-pipeline-rg.name
    server_name = azurerm_sql_server.sql-dw-server.name
    start_ip_address = "0.0.0.0"
    end_ip_address = "0.0.0.0"
}

# Learn our public IP address
data "http" "icanhazip" {
   url = "http://icanhazip.com"
}
resource "azurerm_sql_firewall_rule" "dw-azure-deployer" {
    name = "DeployingServer"
    resource_group_name = azurerm_resource_group.data-pipeline-rg.name
    server_name = azurerm_sql_server.sql-dw-server.name
    start_ip_address = chomp(data.http.icanhazip.body)
    end_ip_address = chomp(data.http.icanhazip.body)
}


resource "azurerm_sql_active_directory_administrator" "sql-dw-server-admin" {
  server_name         = azurerm_sql_server.sql-dw-server.name
  resource_group_name = azurerm_resource_group.data-pipeline-rg.name
  login               = "sqladmin"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = var.spnAppId
}

resource "random_string" "mssqluser" {
  length = 16
  special = false
  number = false
}
 
resource "random_string" "mssqlpassword" {
  length = 32
  special = true
  override_special = "/@\" "
}

resource "azurerm_sql_server" "sql-dw-server" {
  name                         = "sqlspnauthtest"
  resource_group_name          = azurerm_resource_group.data-pipeline-rg.name
  location                     = "westus2"
  version                      = "12.0"
  administrator_login          = random_string.mssqluser.result
  administrator_login_password = random_string.mssqlpassword.result
}

resource "azurerm_sql_database" "sql-db" {
  name                = "sqlspnauthtestdb"
  resource_group_name = azurerm_resource_group.data-pipeline-rg.name
  location            = "westus2"
  server_name         = azurerm_sql_server.sql-dw-server.name
  edition             = "DataWarehouse"
  requested_service_objective_name = "DW100c"
}