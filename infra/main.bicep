targetScope = 'subscription'

param location string
param resourceGroupName string
param foundryName string
param foundryProjectName string
param claudeDeploymentName string
param expectedClaudeModelName string
param expectedClaudeModelVersion string
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

resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: resourceGroupName
}

resource foundry 'Microsoft.CognitiveServices/accounts@2026-05-01' existing = {
  scope: targetResourceGroup
  name: foundryName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2026-05-01' existing = {
  parent: foundry
  name: foundryProjectName
}

resource claudeDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' existing = {
  parent: foundry
  name: claudeDeploymentName
}

module observability 'modules/observability.bicep' = if (deployGateway) {
  name: 'gateway-observability'
  scope: targetResourceGroup
  params: {
    location: location
    tags: tags
    workspaceName: workspaceName
    appInsightsName: appInsightsName
  }
}

module apim 'modules/apim.bicep' = if (deployGateway) {
  name: 'apim-service'
  scope: targetResourceGroup
  params: {
    location: location
    tags: tags
    apimName: apimName
    publisherName: publisherName
    publisherEmail: publisherEmail
  }
}

module gatewayRbac 'modules/rbac.bicep' = if (deployGateway) {
  name: 'gateway-rbac'
  scope: targetResourceGroup
  params: {
    foundryName: foundryName
    appInsightsName: appInsightsName
    apimPrincipalId: apim!.outputs.principalId
  }
  dependsOn: [
    observability
  ]
}

module claudeApi 'modules/claude-api.bicep' = if (deployGateway) {
  name: 'claude-api'
  scope: targetResourceGroup
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

output resourceGroupName string = targetResourceGroup.name
output foundryResourceName string = foundry.name
output foundryResourceId string = foundry.id
output foundryBaseUrl string = 'https://${foundry.name}.services.ai.azure.com/anthropic'
output foundryProjectName string = foundryProject.name
output foundryProjectEndpoint string = 'https://${foundry.name}.services.ai.azure.com/api/projects/${foundryProject.name}'
output claudeDeploymentName string = claudeDeployment.name
output claudeModelName string = expectedClaudeModelName
output claudeModelVersion string = expectedClaudeModelVersion
output apimResourceName string = deployGateway ? apim!.outputs.apimName : ''
output apimGatewayUrl string = deployGateway ? apim!.outputs.gatewayUrl : ''
output apimClaudeBaseUrl string = deployGateway ? claudeApi!.outputs.claudeBaseUrl : ''
output appInsightsName string = deployGateway ? observability!.outputs.appInsightsName : ''
output logAnalyticsWorkspaceName string = deployGateway ? observability!.outputs.workspaceName : ''
