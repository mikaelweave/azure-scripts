param storageAccountName string
param appInsightsName string
param logAnalyticsName string
param appServiceName string
param functionAppName string
param location string
param keyVaultName string
param tenantId string
param appTags object = {}
param functionServicePrincipal object
param fhirProxyPreProcess string = 'FHIRProxy.preprocessors.TransformBundlePreProcess'
param fhirProxyPostProcess string = ''


// Function Storage Account
resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: appTags
}

// App Insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: appTags
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: appTags
}

resource logAnalyticsWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  scope: logAnalyticsWorkspace
  name: 'diagnosticSettings'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
  }
}

// App Service
resource appService 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServiceName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'S1'
  }
  tags: appTags
}

// Function App
resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'

  identity: {
    type: 'SystemAssigned'
  }


  properties: {
    httpsOnly: true
    enabled: true
    serverFarmId: appService.id
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn:true
    }
  }

  tags: appTags
}

resource fhirProxyAppSettings 'Microsoft.Web/sites/config@2020-12-01' = {
  name: 'appsettings'
  parent: functionApp
  properties: {
    'FUNCTIONS_EXTENSION_VERSION': '~3'
    'FUNCTIONS_WORKER_RUNTIME': 'dotnet'
    'AzureWebJobsStorage': 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
    //'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING': 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
    'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
    'APPLICATIONINSIGHTS_CONNECTION_STRING': 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
    'FP-ADMIN-ROLE': 'Administrator'
    'FP-READER-ROLE': 'Reader'
    'FP-WRITER-ROLE': 'Writer'
    'FP-GLOBAL-ACCESS-ROLES': 'DataScientist'
    'FP-PATIENT-ACCESS-ROLES': 'Patient'
    'FP-PARTICIPANT-ACCESS-ROLES': 'Practitioner,RelatedPerson'
    'FP-HOST': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-HOST/)'
    'FP-PRE-PROCESSOR-TYPES': empty(fhirProxyPreProcess) ? 'FHIRProxy.preprocessors.TransformBundlePreProcess' : fhirProxyPreProcess
    'FP-POST-PROCESSOR-TYPES': empty(fhirProxyPostProcess) ? '' : fhirProxyPostProcess
    'FP-RBAC-NAME':'@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-RBAC-NAME/)'
    'FP-RBAC-TENANT-NAME':'@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-RBAC-TENANT-NAME/)'
    'FP-RBAC-CLIENT-ID':'@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-RBAC-CLIENT-ID/)'
    'FP-RBAC-CLIENT-SECRET':'@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-RBAC-CLIENT-SECRET/)'
    'FP-STORAGEACCT': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FP-STORAGEACCT/)'
    'FS-URL': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FS-URL/)'
    'FS-TENANT-NAME': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FS-TENANT-NAME/)'
    'FS-CLIENT-ID': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FS-CLIENT-ID/)'
    'FS-SECRET': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FS-SECRET/)'
    'FS-RESOURCE': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}/secrets/FS-RESOURCE/)'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
}

resource functionVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
        tenantId: tenantId
      }
    ]
  }
}

resource keyVaultSecretsFpHost 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: 'FP-HOST'
  parent: keyVault
  properties: {
    value: functionApp.properties.defaultHostName
  }
}

resource symbolicname 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'authsettingsV2'
  parent: functionApp
  properties: {
    globalValidation: {
      unauthenticatedClientAction: 'AllowAnonymous'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: functionServicePrincipal.appId
          clientSecretSettingName: 'FP-RBAC-CLIENT-SECRET'
          openIdIssuer: 'https://sts.windows.net/${tenantId}/'
        }
        validation: {
          allowedAudiences: [
            functionServicePrincipal.appId
          ]
        }
      }
    }
  }
}

resource keyVaultSecretsFpStorage 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: 'FP-STORAGEACCT'
  parent: keyVault
  properties: {
    value: funcStorageAccount.listKeys().keys[0].value
  }
}

resource keyVaultSecretsFpRbacName 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: 'FP-RBAC-NAME'
  parent: keyVault
  properties: {
    value: 'https://${functionApp.properties.defaultHostName}'
  }
}

resource keyVaultSecretsFpScUrl 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = {
  name: 'FP-SC-URL'
  parent: keyVault
  properties: {
    value: 'https://${functionApp.properties.defaultHostName}'
  }
}

output functionAppName string = functionAppName
output functionAppPrincipalId string = functionApp.identity.principalId
output hostName string = functionApp.properties.defaultHostName
output funcStorageAccount object = funcStorageAccount
