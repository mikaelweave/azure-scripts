provider "azurerm" {
  version = "~>1.19"
}

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
  resource_group_name      = var.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "BlobStorage"
}

resource "azurerm_storage_container" "source_container" {
  name                  = var.sourceContainerName
  resource_group_name   = var.resourceGroupName
  storage_account_name  = var.sourceStorageAccountName
  container_access_type = "private"
}

resource "azurerm_storage_account" "dest" {
  name                     = var.destStorageAccountName
  resource_group_name      = var.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "BlobStorage"
}

resource "azurerm_storage_container" "dest_container" {
  name                  = var.destStorageAccountName
  resource_group_name   = var.resourceGroupName
  storage_account_name  = var.destStorageAccountName
  container_access_type = "private"
}

resource "azurerm_data_factory" "adf" {
  name                = var.factoryName
  location            = var.location
  resource_group_name = var.resourceGroupName
}

resource "azurerm_template_deployment" "data-factory-dependencies" {
  name                = "MyApp-ARM"
  resource_group_name = azurerm_resource_group.main.name

  template_body = file("azuredeploy.json")

  parameters = {
    "factoryName" = var.factoryName,
    "blobSourceAccountUrl" = "https://${var.sourceStorageAccountName}.blob.core.windows.net/",
    "blobDestAccountUrl" = "https://${var.destStorageAccountName}.blob.core.windows.net/"
  }

  deployment_mode = "Incremental"
}