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
$RolesWithDataAccess = $(Get-AzRoleDefinition | Where-Object -FilterScript {$_.dataActions -like "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/*"})
$KeyAccessActionArray = "*", "Microsoft.Storage/storageAccounts/*", "Microsoft.Storage/storageAccounts/listkeys/action", "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
$RolesWithKeyAccess = $()
foreach ($action in $KeyAccessActionArray) {
    $RolesWithKeyAccess = $RolesWithKeyAccess + $(Get-AzRoleDefinition | Where-Object -FilterScript {$_.Actions.Contains($action)})
}

# Get resource ID
$StorageAccount = $(Get-AzStorageAccount | Where-Object StorageAccountName -eq $StorageAccountName)

# Get role assignments for storage account (and child containers)
$AssignmentsWithDataAccess = $(Get-AzRoleAssignment -Scope $StorageAccount.Id | Where-Object RoleDefinitionId -in $RolesWithDataAccess.Id)
$AssignmentsWithKeyAccess = $(Get-AzRoleAssignment -Scope $StorageAccount.Id | Where-Object RoleDefinitionId -in $RolesWithKeyAccess.Id)

# Export to files
$AssignmentsWithDataAccess | export-csv AssignmentsWithDataAccess.csv -notypeinformation
$AssignmentsWithKeyAccess | export-csv AssignmentsWithKeyAccess.csv -notypeinformation

$Token = Get-AzCachedAccessToken
$Filesystems = Get-ADLSContainers -StorageAccountName $StorageAccountName -BearerToken $Token

function Get-ADLSContainers()
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)] [string] $StorageAccountName,
        [Parameter(Mandatory = $true, Position = 1)] [string] $BearerToken
    )
    # Rest documentation:
    # https://docs.microsoft.com/en-us/rest/api/storageservices/datalakestoragegen2/path/create
    $method = "GET"
 
    $headers = @{ } 
    $headers.Add("x-ms-version", "2018-11-09")
    $headers.Add("Authorization", "Bearer $BearerToken")
    $headers.Add("If-None-Match", "*") # To fail if the destination already exists, use a conditional request with If-None-Match: "*"
 
    $URI = "https://$StorageAccountName.dfs.core.windows.net/?resource=account"
 
    try {
        $result = Invoke-RestMethod -method $method -Uri $URI -Headers $headers # returns empty response
        $result
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $StatusDescription = $_.Exception.Response.StatusDescription
 
        Throw $ErrorMessage + " " + $StatusDescription + " PathToCreate: $PathToCreate"
    }
}

function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'
  
    if(-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}

function Get-AzBearerToken()
{
    $ErrorActionPreference = 'Stop'
    ('Bearer {0}' -f (Get-AzCachedAccessToken))
}