provider "azurerm" {
  version = "~>1.39.0"
}
data "azurerm_subscription" "current" {}

variable "resourceGroupName" {
  type        = string
  description = "Name of the resource group to deploy to"
}
variable "location" {
  type        = string
  description = "Location to deploy resources"
}
variable "factoryName" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
}
variable "sourceStorageAccountName" {
  type        = string
  description = "Name of the source storage account"
}
variable "sourceContainerName" {
  type        = string
  description = "Name of the source container"
}
variable "destStorageAccountName" {
  type        = string
  description = "Name of the destination storage account"
}
variable "destContainerName" {
  type        = string
  description = "Name of the destination container"
}

resource "azurerm_resource_group" "main" {
  name     = var.resourceGroupName
  location = var.location
}

resource "azurerm_storage_account" "source" {
  name                     = var.sourceStorageAccountName
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "source_container" {
  name                  = var.sourceContainerName
  storage_account_name  = azurerm_storage_account.source.name
  container_access_type = "private"
}

resource "azurerm_storage_account" "dest" {
  name                     = var.destStorageAccountName
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dest_container" {
  name                  = var.destContainerName
  storage_account_name  = azurerm_storage_account.dest.name
  container_access_type = "private"
}

resource "azurerm_data_factory" "adf" {
  name                = var.factoryName
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "source-mi" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Storage/storageAccounts/${azurerm_storage_account.source.name}/blobServices/default/containers/${azurerm_storage_container.source_container.name}"
  role_definition_name = "Reader"
  principal_id         = lookup(azurerm_data_factory.adf.identity[0], "principal_id")
}

resource "azurerm_role_assignment" "dest-mi" {
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Storage/storageAccounts/${azurerm_storage_account.dest.name}/blobServices/default/containers/${azurerm_storage_container.dest_container.name}"
  role_definition_name = "Reader"
  principal_id         = lookup(azurerm_data_factory.adf.identity[0], "principal_id")
}

resource "azurerm_template_deployment" "data-factory-dependencies" {
  name                = "adfComponentsDeployment"
  resource_group_name = azurerm_resource_group.main.name

  template_body = file("azuredeploy.json")

  parameters = {
    "factoryName" = var.factoryName,
    "blobSourceAccountUrl" = "https://${azurerm_storage_account.source.name}.blob.core.windows.net/",
    "blobDestAccountUrl" = "https://${azurerm_storage_account.dest.name}.blob.core.windows.net/".
    "srcContainerName" = var.sourceContainerName,
    "destContainerName" = var.destContainerName
  }

  deployment_mode = "Incremental"
  depends_on = [azurerm_data_factory.adf, azurerm_storage_container.source_container, azurerm_storage_container.dest_container]
}