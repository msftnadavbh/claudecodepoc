using '../main.bicep'

param deploymentMode = 'greenfield'
param location = 'eastus2'
param resourceGroupName = 'rg-claude-code-poc'
param foundryName = 'your-foundry-resource'
param foundryProjectName = 'your-foundry-project'
param claudeDeploymentName = 'your-claude-deployment'
param expectedClaudeModelName = 'claude-opus-5'
param expectedClaudeModelVersion = '2'
param claudeModelCapacity = 25
param claudeOrganizationName = 'Your legal organization name'
param claudeCountryCode = 'US'
param claudeIndustry = 'technology'
param apimName = 'your-globally-unique-apim-name'
param workspaceName = 'log-claude-code-poc'
param appInsightsName = 'appi-claude-code-poc'
param apimSubscriptionName = 'claude-code-poc'
param deployGateway = false
param publisherName = 'Your organization'
param publisherEmail = 'azure-admin@example.com'
param enableClaudeTokenMetrics = false
param enableClaudeTokenLimit = false
param claudeTokenLimitPerMinute = 20000
