Param(
    [string]$ServicePrincipalId,
    [string]$ServicePrincipalPassword,
    [string]$TenantId,
    [string]$SQLServerName,
    [string]$userObjectId,
    [string]$userName
)


# https://www.c-sharpcorner.com/blogs/create-azure-service-principal-and-get-aad-auth-token
Function GetAuthTokenInvokingRestApi {  
    Param(  
       [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
       [String]$TenantID,  
       [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
       [String]$ServicePrincipalId,  
       [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
       [String]$ServicePrincipalPwd,  
       [Parameter(Mandatory)][ValidateNotNull()][ValidateNotNullOrEmpty()]  
       [string]$ApiEndpointUri  
 )  
 $encodedSecret = [System.Web.HttpUtility]::UrlEncode($ServicePrincipalPwd)  
 $RequestAccessTokenUri = "https://login.microsoftonline.com/$TenantID/oauth2/token"  
 $body = "grant_type=client_credentials&client_id=$ServicePrincipalId&client_secret=$encodedSecret&resource=$ApiEndpointUri"  
 $contentType = 'application/x-www-form-urlencoded'  
 
 try {  
    $Token = Invoke-RestMethod -Method Post -Uri $RequestAccessTokenUri -Body $body -ContentType $contentType    
    }  
    catch { throw }  
  $Token
 } 

 
 # https://blog.bredvid.no/handling-azure-managed-identity-access-to-azure-sql-in-an-azure-devops-pipeline-1e74e1beb10b
Function ConvertTo-Sid {
    param (
        [string]$appId
    )
    [guid]$guid = [System.Guid]::Parse($appId)
    foreach ($byte in $guid.ToByteArray()) {
        $byteGuid += [System.String]::Format("{0:X2}", $byte)
    }
    return "0x" + $byteGuid
}
 
  GetAuthTokenInvokingRestApi -TenantID $TenantId -ServicePrincipalId $ServicePrincipalId -ServicePrincipalPwd $ServicePrincipalPassword -ApiEndpointUri "https://database.windows.net/" -OutVariable SPNToken

 Write-Verbose "Create SQL connectionstring"
 $conn = New-Object System.Data.SqlClient.SQLConnection 
 $DatabaseName = 'Master'
 $conn.ConnectionString = "Data Source=$SQLServerName.database.windows.net;Initial Catalog=$DatabaseName;Connect Timeout=30"
 $conn.AccessToken = $($SPNToken.access_token)
 $conn
 
 Write-Verbose "Connect to database and execute SQL script"
 $sid = ConvertTo-Sid "57b45b2d-27ee-41dc-b1ae-70b1bc83030c"
 $conn.Open() 
 $query = "DROP USER IF EXISTS $userName; CREATE USER [$userName] WITH DEFAULT_SCHEMA=[dbo], SID = $sid, TYPE = E; ALTER ROLE db_owner ADD MEMBER [$userName]"
 #$query = 'select @@version'
 $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($query, $conn)     
 $Result = $command.ExecuteScalar()
 $Result
 $conn.Close() 
