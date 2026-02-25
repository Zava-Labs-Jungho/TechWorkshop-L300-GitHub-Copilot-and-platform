targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@minLength(1)
@maxLength(64)
@description('Name of the environment used to generate resource names.')
param environmentName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Name of the resource group.')
param resourceGroupName string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var resourceToken = uniqueString(subscription().id, location, environmentName)

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

// User-Assigned Managed Identity
module identity 'modules/identity.bicep' = {
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// Monitoring — Log Analytics Workspace + Application Insights
module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// Azure Container Registry
module acr 'modules/acr.bicep' = {
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
  }
}

// AI Foundry — Storage, Key Vault, Azure OpenAI, Hub, Project, Model Deployments
module aiFoundry 'modules/ai-foundry.bicep' = {
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    appInsightsId: monitoring.outputs.appInsightsId
  }
}

// App Service — Plan + Web App (Linux Docker container)
module appservice 'modules/appservice.bicep' = {
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    managedIdentityId: identity.outputs.managedIdentityId
    managedIdentityClientId: identity.outputs.managedIdentityClientId
    acrLoginServer: acr.outputs.acrLoginServer
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    openAiEndpoint: aiFoundry.outputs.openAiEndpoint
    aiProjectName: aiFoundry.outputs.aiFoundryProjectName
  }
}

// RBAC Role Assignments — AcrPull, OpenAI User, AI Developer
module roleAssignments 'modules/role-assignments.bicep' = {
  scope: rg
  params: {
    managedIdentityPrincipalId: identity.outputs.managedIdentityPrincipalId
    acrName: acr.outputs.acrName
    aiFoundryProjectName: aiFoundry.outputs.aiFoundryProjectName
    openAiAccountName: aiFoundry.outputs.openAiAccountName
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output RESOURCE_GROUP_ID string = rg.id
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.acrLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.acrName
output WEB_APP_URL string = appservice.outputs.webAppUrl
output AZURE_OPENAI_ENDPOINT string = aiFoundry.outputs.openAiEndpoint
output AI_FOUNDRY_PROJECT_NAME string = aiFoundry.outputs.aiFoundryProjectName
