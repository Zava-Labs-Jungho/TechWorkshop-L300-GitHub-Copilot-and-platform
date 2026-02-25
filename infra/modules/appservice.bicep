@description('Location for resources.')
param location string

@description('Resource token for unique naming.')
param resourceToken string

@description('Resource ID of the user-assigned managed identity.')
param managedIdentityId string

@description('Client ID of the user-assigned managed identity.')
param managedIdentityClientId string

@description('ACR login server URL.')
param acrLoginServer string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Azure OpenAI endpoint URL.')
param openAiEndpoint string

@description('AI Foundry Project name.')
param aiProjectName string

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'azasp${resourceToken}'
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true // Required for Linux
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: 'azapp${resourceToken}'
  location: location
  tags: {
    'azd-service-name': 'web'
  }
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/zava-storefront:latest'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentityClientId
      alwaysOn: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: managedIdentityClientId
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: openAiEndpoint
        }
        {
          name: 'AZURE_AI_PROJECT_NAME'
          value: aiProjectName
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

// Note: Site Extensions (Microsoft.Web/sites/siteextensions) are not supported
// on Linux container-based App Services. Application Insights telemetry should
// be configured via the APPLICATIONINSIGHTS_CONNECTION_STRING app setting and
// the Application Insights SDK in the application code.

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppId string = webApp.id
