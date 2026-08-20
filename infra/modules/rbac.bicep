param foundryName string
param appInsightsName string
param apimPrincipalId string

var cognitiveServicesUserRoleId = 'a97b65f3-24c7-4388-baec-2e87135dc908'
var monitoringMetricsPublisherRoleId = '3913510d-42f4-4e42-8a64-420c390055eb'

resource foundry 'Microsoft.CognitiveServices/accounts@2026-05-01' existing = {
  name: foundryName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource foundryInferenceRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, apimPrincipalId, cognitiveServicesUserRoleId)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource appInsightsMetricsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, apimPrincipalId, monitoringMetricsPublisherRoleId)
  scope: appInsights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringMetricsPublisherRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}
