@description('Location for resources.')
param location string

@description('Resource token for unique naming.')
param resourceToken string

@description('Resource ID of Application Insights.')
param appInsightsId string

// ---------------------------------------------------------------------------
// Storage Account (required dependency for AI Foundry Hub)
// ---------------------------------------------------------------------------
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'azst${resourceToken}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// ---------------------------------------------------------------------------
// Key Vault (required dependency for AI Foundry Hub — not used for app secrets)
// ---------------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'azkv${resourceToken}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
  }
}

// ---------------------------------------------------------------------------
// Azure OpenAI Service
// ---------------------------------------------------------------------------
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'azoai${resourceToken}'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'azoai${resourceToken}'
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

// GPT-4.1 model deployment (Standard, pay-per-token)
resource gpt41Deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAiAccount
  name: 'gpt-41'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1'
    }
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Hub
// ---------------------------------------------------------------------------
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'azhub${resourceToken}'
  location: location
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Foundry Hub'
    description: 'AI Foundry Hub for ZavaStorefront'
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: appInsightsId
  }
}

// Connection from AI Hub to Azure OpenAI
resource aiHubOpenAiConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiHub
  name: 'aoai-connection'
  properties: {
    category: 'AzureOpenAI'
    target: openAiAccount.properties.endpoint
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ApiVersion: '2024-10-01'
      ResourceId: openAiAccount.id
    }
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Project
// ---------------------------------------------------------------------------
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'azprj${resourceToken}'
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'ZavaStorefront AI Project'
    description: 'AI Project for ZavaStorefront development'
    hubResourceId: aiHub.id
  }
}

// Phi-4 Serverless Endpoint (pay-per-token, managed identity auth)
resource phi4Endpoint 'Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-10-01-preview' = {
  parent: aiProject
  name: 'phi-4-${resourceToken}'
  location: location
  sku: {
    name: 'Consumption'
  }
  properties: {
    modelSettings: {
      modelId: 'azureml://registries/azureml/models/Phi-4'
    }
    authMode: 'Key'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output openAiAccountName string = openAiAccount.name
output openAiEndpoint string = openAiAccount.properties.endpoint
output aiFoundryHubName string = aiHub.name
output aiFoundryProjectName string = aiProject.name
output phi4EndpointUri string = phi4Endpoint.properties.inferenceEndpoint.uri
