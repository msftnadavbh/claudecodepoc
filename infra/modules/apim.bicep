param location string
param tags object
param apimName string
param publisherName string
param publisherEmail string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    publicNetworkAccess: 'Enabled'
  }
}

output apimName string = apim.name
output apimId string = apim.id
output principalId string = apim.identity.principalId
output gatewayUrl string = apim.properties.gatewayUrl
