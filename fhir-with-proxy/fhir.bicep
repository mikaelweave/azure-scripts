param workspaceName string
param fhirName string
param appTags object = {}

param tenantId string
param location string
param fhirContributorObjectIds array = []

var fhirservicename = '${workspaceName}/${fhirName}'
var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'

resource healthWorkspace 'Microsoft.HealthcareApis/workspaces@2021-06-01-preview' = {
  name: workspaceName
  location: location
  tags: appTags
}

resource fhir 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-06-01-preview' = {
  name: fhirservicename
  location: location
  kind: 'fhir-R4'

  identity: {
    type: 'SystemAssigned'
  }


  properties: {
    authenticationConfiguration: {
      authority: authority
      audience: audience
      smartProxyEnabled: false
    }
  }

  tags: appTags

  dependsOn: [
    healthWorkspace
  ]
}


@description('This is the built-in FHIR Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#fhir-data-contributor')
resource fhirContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '5a1fc7df-4bf1-4951-a576-89034ee01acd'
}

resource fhirDataContributorAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  [for principalId in  fhirContributorObjectIds: {
  scope: fhir
  name: guid(fhir.id, principalId, fhirContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirContributorRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
