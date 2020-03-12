Param(
    [string]$ServicePrincipalId,
    [SecureString]$ServicePrincipalPassword,
    [string]$TenantId,
    [string]$SQLServerName,
    [string]$SQLDatabaseName,
    [string]$GrantServicePrincipalName,
    [string]$GrantServicePrincipalObjectId
)


# https://www.c-sharpcorner.com/blogs/create-azure-service-principal-and-get-aad-auth-token
Function GetAuthTokenInvokingRestApi {
    Param(
        [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
        [String]$TenantID,
        [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
        [String]$ServicePrincipalId,
        [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
        [SecureString]$ServicePrincipalPwd,
        [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
        [string]$ApiEndpointUri
    )
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalId, $ServicePrincipalPwd
    $encodedSecret = [System.Web.HttpUtility]::UrlEncode($credential.GetNetworkCredential().password)
    $RequestAccessTokenUri = "https://login.microsoftonline.com/$TenantID/oauth2/token"
    $body = "grant_type=client_credentials&client_id=$ServicePrincipalId&client_secret=$encodedSecret&resource=$ApiEndpointUri"  
    $contentType = 'application/x-www-form-urlencoded'

    try {
        $Token = Invoke-RestMethod -Method Post -Uri $RequestAccessTokenUri -Body $body -ContentType $contentType    
    }
    catch { throw }
    $Token
}

Function ConvertTo-Sid {
    param (
        [string]$objectId
    )
    [guid]$guid = [System.Guid]::Parse($objectId)
    foreach ($byte in $guid.ToByteArray()) {
        $byteGuid += [System.String]::Format("{0:X2}", $byte)
    }
    return "0x" + $byteGuid
}

$sid = ConvertTo-Sid $GrantServicePrincipalObjectId
Write-Host $sid

GetAuthTokenInvokingRestApi -TenantID $TenantId -ServicePrincipalId $ServicePrincipalId -ServicePrincipalPwd $ServicePrincipalPassword -ApiEndpointUri "https://database.windows.net/" -OutVariable SPNToken

$conn = New-Object System.Data.SqlClient.SQLConnection 
$conn.ConnectionString = "Data Source=$SQLServerName.database.windows.net;Initial Catalog=$SQLDatabaseName;Connect Timeout=30"
$conn.AccessToken = $($SPNToken.access_token)

$conn.Open() 
#$query = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$GrantServicePrincipalName') CREATE USER [$GrantServicePrincipalName] FROM EXTERNAL PROVIDER; EXEC sp_addrolemember 'db_owner', '$userName';"
#$query = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$GrantServicePrincipalName') CREATE USER [$GrantServicePrincipalName] SID = [0x2D5BB457EE27DC41B1AE70B1BC83030C], TYPE = E;; EXEC sp_addrolemember 'db_owner', '$userName';"
$query = @"
	DECLARE @username VARCHAR(60)
	SET @username = '$GrantServicePrincipalName'
	DECLARE @stmt VARCHAR(MAX)
	SET @stmt = '
	IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name =''' + @username +''')
	BEGIN
		CREATE USER [' + @username + '] WITH DEFAULT_SCHEMA=[dbo], SID = $sid, TYPE = E;
	END'
	PRINT(@stmt)
"@
$command = New-Object -TypeName System.Data.SqlClient.SqlCommand($query, $conn)
$command.ExecuteScalar()
$conn.Close()
