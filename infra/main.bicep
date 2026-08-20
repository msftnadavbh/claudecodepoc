targetScope = 'subscription'

@allowed([
  'greenfield'
  'brownfield'
])
param deploymentMode string = 'greenfield'
param location string
param resourceGroupName string
param foundryName string
param foundryProjectName string
param claudeDeploymentName string
param expectedClaudeModelName string
param expectedClaudeModelVersion string
param claudeModelCapacity int
param claudeOrganizationName string = ''
param claudeCountryCode string = ''
param claudeIndustry string = ''
param apimName string
param workspaceName string
param appInsightsName string
param apimSubscriptionName string
param deployGateway bool = false
param publisherName string
param publisherEmail string
param enableClaudeTokenMetrics bool = false
param enableClaudeTokenLimit bool = false

@minValue(1)
param claudeTokenLimitPerMinute int = 20000

var tags = {
  workload: 'claude-code-foundry-poc'
  environment: 'poc'
  managedBy: 'bicep'
  repository: 'claudecodepoc'
}
var greenfield = deploymentMode == 'greenfield'

resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (greenfield) {
  name: resourceGroupName
  location: location
  tags: tags
}

module foundry 'modules/foundry.bicep' = if (greenfield) {
  name: 'foundry-and-claude'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: tags
    foundryName: foundryName
    projectName: foundryProjectName
    deploymentName: claudeDeploymentName
    modelName: expectedClaudeModelName
    modelVersion: expectedClaudeModelVersion
    modelCapacity: claudeModelCapacity
    claudeOrganizationName: claudeOrganizationName
    claudeCountryCode: claudeCountryCode
    claudeIndustry: claudeIndustry
  }
  dependsOn: [
    targetResourceGroup
  ]
}

module observability 'modules/observability.bicep' = if (deployGateway) {
  name: 'gateway-observability'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: tags
    workspaceName: workspaceName
    appInsightsName: appInsightsName
  }
  dependsOn: [
    targetResourceGroup
  ]
}

module apim 'modules/apim.bicep' = if (deployGateway) {
  name: 'apim-service'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: tags
    apimName: apimName
    publisherName: publisherName
    publisherEmail: publisherEmail
  }
  dependsOn: [
    targetResourceGroup
  ]
}

module gatewayRbac 'modules/rbac.bicep' = if (deployGateway) {
  name: 'gateway-rbac'
  scope: resourceGroup(resourceGroupName)
  params: {
    foundryName: foundryName
    appInsightsName: appInsightsName
    apimPrincipalId: apim!.outputs.principalId
  }
  dependsOn: [
    observability
    foundry
  ]
}

module claudeApi 'modules/claude-api.bicep' = if (deployGateway) {
  name: 'claude-api'
  scope: resourceGroup(resourceGroupName)
  params: {
    apimName: apimName
    foundryName: foundryName
    claudeDeploymentName: claudeDeploymentName
    apimSubscriptionName: apimSubscriptionName
    appInsightsName: appInsightsName
    appInsightsConnectionString: observability!.outputs.connectionString
    enableClaudeTokenMetrics: enableClaudeTokenMetrics
    enableClaudeTokenLimit: enableClaudeTokenLimit
    claudeTokenLimitPerMinute: claudeTokenLimitPerMinute
  }
  dependsOn: [
    gatewayRbac
  ]
}

output resourceGroupName string = resourceGroupName
output foundryResourceName string = foundryName
output foundryResourceId string = resourceId(resourceGroupName, 'Microsoft.CognitiveServices/accounts', foundryName)
output foundryBaseUrl string = 'https://${foundryName}.services.ai.azure.com/anthropic'
output foundryProjectName string = foundryProjectName
output foundryProjectEndpoint string = 'https://${foundryName}.services.ai.azure.com/api/projects/${foundryProjectName}'
output claudeDeploymentName string = claudeDeploymentName
output claudeModelName string = expectedClaudeModelName
output claudeModelVersion string = expectedClaudeModelVersion
output apimResourceName string = deployGateway ? apim!.outputs.apimName : ''
output apimGatewayUrl string = deployGateway ? apim!.outputs.gatewayUrl : ''
output apimClaudeBaseUrl string = deployGateway ? claudeApi!.outputs.claudeBaseUrl : ''
output appInsightsName string = deployGateway ? observability!.outputs.appInsightsName : ''
output logAnalyticsWorkspaceName string = deployGateway ? observability!.outputs.workspaceName : ''
