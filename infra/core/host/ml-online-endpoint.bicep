import { OptionalResource } from 'br:acrazdbicep.azurecr.io/bicep/types/common:v1'

metadata description = 'Creates an Azure Container Registry.'
param name string
param serviceName string
param location string = resourceGroup().location
param tags object = {}
param aiProject OptionalResource
param aiHub OptionalResource
param keyVault OptionalResource
param kind string = 'Managed'
param authMode string = 'Key'

resource endpoint 'Microsoft.MachineLearningServices/workspaces/onlineEndpoints@2023-10-01' = {
  name: name
  location: location
  parent: workspace
  kind: kind
  tags: union(tags, { 'azd-service-name': serviceName })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authMode: authMode
  }
}

var azureMLDataScientist = resourceId('Microsoft.Authorization/roleDefinitions', 'f6c7c914-8db3-469d-8ca1-694a8f32e121')

module azureMLDataScientistRoleHub '../security/role.bicep' = {
  name: guid(subscription().id, resourceGroup().id, aiHub.name, name, azureMLDataScientist)
  scope: resourceGroup(aiHub.subscriptionId, aiHub.resourceGroup)
  params: {
    principalId: endpoint.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: azureMLDataScientist
  }
}

module azureMLDataScientistRoleWorkspace '../security/role.bicep' = {
  name: guid(subscription().id, resourceGroup().id, aiProject.name, name, azureMLDataScientist)
  scope: resourceGroup(aiProject.subscriptionId, aiProject.resourceGroup)
  params: {
    principalId: endpoint.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: azureMLDataScientist
  }
}

var azureMLWorkspaceConnectionSecretsReader = resourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
)

resource azureMLWorkspaceConnectionSecretsReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, aiProject.name, name, azureMLWorkspaceConnectionSecretsReader)
  scope: endpoint
  properties: {
    principalId: endpoint.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: azureMLWorkspaceConnectionSecretsReader
  }
}

module keyVaultAccess '../security/keyvault-access.bicep' = {
  name: '${name}-keyvault-access'
  scope: resourceGroup(keyVault.subscriptionId, keyVault.resourceGroup)
  params: {
    keyVaultName: keyVault.name
    principalId: endpoint.identity.principalId
  }
}

resource workspace 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' existing = {
  name: aiProject.name
}

output name string = endpoint.name
output scoringEndpoint string = endpoint.properties.scoringUri
output swaggerEndpoint string = endpoint.properties.swaggerUri
output principalId string = endpoint.identity.principalId
