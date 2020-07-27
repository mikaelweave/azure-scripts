# Get ARM Template
$file = Get-Content 'ARMTemplateForFactory.json' -raw | ConvertFrom-Json 

# Get our Integration Runtime Object
$irNode = $file.resources | Where name -eq "[concat(parameters('factoryName'), '/irConsRpt')]" 

# Update linked info values
$o = @{}
$o.resourceId = "test"
$o.authorizationType = "Rbac"
$irNode.properties.typeProperties | Add-Member -Type NoteProperty -Name "linkedInfo" -Value $o -Force

# Write the file back to disk
$file | ConvertTo-Json -depth 32 | set-content 'ARMTemplateForFactory.json'