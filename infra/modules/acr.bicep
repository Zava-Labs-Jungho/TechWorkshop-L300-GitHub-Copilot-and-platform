@description('Location for resources.')
param location string

@description('Resource token for unique naming.')
param resourceToken string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'azacr${resourceToken}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output acrId string = acr.id
