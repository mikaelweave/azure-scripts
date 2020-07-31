resource "azurerm_resource_group" "rg" {
  name     = "${var.base_name}-rg"
  location = "westus2"
}

locals {
  default_fa_sa_name = replace(replace(var.base_name, "-", ""), "_", "")
}

resource "azurerm_storage_account" "func_storage" {
  name                     = "${length(local.default_fa_sa_name) > 20 ? substr(local.default_fa_sa_name, 0, 19) : local.default_fa_sa_name}fasa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "func_plan" {
  name                = "${var.base_name}-fp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }

  lifecycle {
    ignore_changes = [
      # Ingore because deploying FunctionApp will change it from linux to FunctionApp. Therr is a TF bug with FunctionApp and Linux.
      kind
    ]
  }
}

resource "azurerm_application_insights" "func_monitoring" {
  name                = "${var.base_name}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_function_app" "func_app" {
  name                       = "${var.base_name}-fa"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.func_plan.id
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  os_type                    = "linux"
  version                    = "~3"

  app_settings = {
      AppInsights_InstrumentationKey = azurerm_application_insights.func_monitoring.instrumentation_key
  }
}