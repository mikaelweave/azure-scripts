param name string = substring('patch-proxy${uniqueString(resourceGroup().id)}', 0, 20)
param tenantId string = subscription().tenantId
param location string = resourceGroup().location

var workspaceName = format('{0}hcapi', replace(name, '-', ''))
var fhirName = 'teststor'
var storageAccountName = format('{0}sa', replace(name, '-', ''))
var appServiceName = '${name}-plan'
var appInsightsName = '${name}-insight'
var functionAppName = '${name}-func'

var appTags = {
  AppID: 'fhir-proxy-sdk-sample'
  AppName: 'FHIR Proxy SDK Sample'
}

module fhir './fhir.bicep' = {
  name: 'fhirDeploy'
  params: {
    workspaceName: workspaceName
    fhirName: fhirName
    location: location
    tenantId: tenantId
    fhirContributorObjectIds: [
      function.outputs.functionAppPrincipalId
    ]
    appTags: appTags
  }

  dependsOn: [
    function
  ]
}

module function './function.bicep' = {
  name: 'functionDeploy'
  params: {
    storageAccountName: storageAccountName
    appInsightsName: appInsightsName
    appServiceName: appServiceName
    functionAppName: functionAppName
    location: location
    appTags: appTags
    tenantId: tenantId
    fhirServerUrl: 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'
  }
}

output functionAppName string = functionAppName
