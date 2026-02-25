@description('Principal ID of the user-assigned managed identity.')
param managedIdentityPrincipalId string

@description('Name of the ACR resource.')
param acrName string

@description('Name of the AI Foundry Project.')
param aiFoundryProjectName string

@description('Name of the Azure OpenAI account.')
param openAiAccountName string

// Built-in role definition IDs
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var cognitiveServicesOpenAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var azureAiDeveloperRoleId = '64702f94-c441-49e6-a78b-ef80e0188fee'

// Existing resources to scope role assignments
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: openAiAccountName
}

resource aiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiFoundryProjectName
}

// AcrPull — allows App Service (via managed identity) to pull images from ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentityPrincipalId, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services OpenAI User — allows managed identity to call Azure OpenAI
resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAiAccount.id, managedIdentityPrincipalId, cognitiveServicesOpenAiUserRoleId)
  scope: openAiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiUserRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Azure AI Developer — allows managed identity to use the AI Foundry Project
resource aiDeveloperRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundryProject.id, managedIdentityPrincipalId, azureAiDeveloperRoleId)
  scope: aiFoundryProject
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureAiDeveloperRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
