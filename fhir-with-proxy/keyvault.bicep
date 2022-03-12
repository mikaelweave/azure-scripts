//https://github.com/Azure/bicep/blob/main/docs/examples/101/key-vault-create/main.bicep

param name string
param tenantId string
param keyAdminPrincipals array = []
param location string = resourceGroup().location
param sku string = 'Standard'
param defaultSecrets object = {}
param appTags object = {}

var accessPolicies = [for principalId in keyAdminPrincipals: {
  objectId: principalId
  permissions: {
    secrets: [
      'get'
      'list'
      'set'
      'delete'
    ]
  }
  tenantId: tenantId
}]

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: name
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: sku
    }
    accessPolicies: accessPolicies
  }
  tags: appTags
}

 resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = [for pair in items(defaultSecrets) :{
  name: '${keyvault.name}/${pair.key}'
  properties: {
    value: pair.value
  }
}]

output keyVaultName string = keyvault.name
