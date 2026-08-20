param location string
param tags object
param workspaceName string
param appInsightsName string

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  #disable-next-line BCP187
  sku: {
    name: 'PerGB2018'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    DisableLocalAuth: true
    RetentionInDays: 30
    SamplingPercentage: 100
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceName string = workspace.name
output workspaceId string = workspace.id
output appInsightsName string = appInsights.name
output appInsightsId string = appInsights.id
output connectionString string = appInsights.properties.ConnectionString
