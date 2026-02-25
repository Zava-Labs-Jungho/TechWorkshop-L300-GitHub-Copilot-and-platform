@description('Location for resources.')
param location string

@description('Resource token for unique naming.')
param resourceToken string

@description('Principal ID of the user-assigned managed identity.')
param managedIdentityPrincipalId string

@description('Name of the AI Foundry Project workspace.')
param aiProjectName string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var phi4SecretName = 'phi4-api-key'

// ---------------------------------------------------------------------------
// Existing Resources
// ---------------------------------------------------------------------------

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: aiProjectName
}

resource phi4Endpoint 'Microsoft.MachineLearningServices/workspaces/serverlessEndpoints@2024-10-01-preview' existing = {
  parent: aiProject
  name: 'phi-4-${resourceToken}'
}

// ---------------------------------------------------------------------------
// Key Vault for Application Secrets
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'azkvapp${resourceToken}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
  }
}

// Store the Phi-4 serverless endpoint API key as a secret
resource phi4ApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: phi4SecretName
  properties: {
    value: phi4Endpoint.listKeys().primaryKey
  }
}

// Key Vault Secrets User — allows managed identity to read secrets
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name
output phi4SecretName string = phi4SecretName
