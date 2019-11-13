# Sign in first with "Connect-AzAccount"

#################
# PARAMETERS
#################
$SubscriptionId = "0f26e0a8-997f-480c-a11f-245c8459271b"
$StorageAccountName = "adls2accesstest"

#################
# SCRIPT BEGIN
#################
# Ensure we're on the correct subscription
Set-AzContext -Subscription $SubscriptionId

# Get all RBAC roles with data access
$RolesWithAccess = $(Get-AzRoleDefinition | Where-Object -FilterScript {$_.dataActions -like "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/*"})

# Get resource ID
$StorageAccount = $(Get-AzStorageAccount | Where-Object StorageAccountName -eq $StorageAccountName)

# Get role assignments for storage account (and child containers)
Get-AzRoleAssignment -Scope $StorageAccount.Id | Where-Object RoleDefinitionId -in $RolesWithAccess.Id