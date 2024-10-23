import { OptionalResource } from 'br:acrazdbicep.azurecr.io/bicep/types/common:v1'

param resourceGroupName string

@minLength(1)
@description('Primary location for all resources')
param location string

param aiHub OptionalResource
param aiProject OptionalResource
param aiService OptionalResource
param keyVault OptionalResource
param storageAccount OptionalResource
param applicationInsights OptionalResource
param searchService OptionalResource
param containerRegistry OptionalResource
param logAnalytics OptionalResource

@description('The Open AI connection name.')
param openAiConnectionName string

@description('The Open AI model deployments.')
param openAiModelDeployments array = []

@description('The Open AI content safety connection name.')
param openAiContentSafetyConnectionName string

@description('The Azure Search connection name.')
param searchConnectionName string = ''
param tags object = {}

module hubDependencies '../ai/hub-dependencies.bicep' = {
  name: 'hubDependencies'
  scope: resourceGroup(resourceGroupName)
  params: {
    location: location
    tags: tags
    keyVault: keyVault
    storageAccount: storageAccount
    containerRegistry: containerRegistry
    applicationInsights: applicationInsights
    logAnalytics: logAnalytics
    aiService: aiService
    openAiModelDeployments: openAiModelDeployments
    searchService: searchService
  }
}

resource existingHub 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' existing = if (aiHub.exists) {
  name: aiHub.name
  scope: resourceGroup(aiHub.subscriptionId, aiHub.resourceGroup)
}

module hub '../ai/hub.bicep' = if (!aiHub.exists) {
  name: 'hub'
  params: {
    location: location
    tags: tags
    name: aiHub.name
    displayName: aiHub.name
    keyVaultId: hubDependencies.outputs.keyVaultId
    storageAccountId: hubDependencies.outputs.storageAccountId
    containerRegistryId: hubDependencies.outputs.containerRegistryId
    applicationInsightsId: hubDependencies.outputs.applicationInsightsId
    openAiName: hubDependencies.outputs.openAiName
    openAiConnectionName: openAiConnectionName
    openAiContentSafetyConnectionName: openAiContentSafetyConnectionName
    aiSearchName: hubDependencies.outputs.searchServiceName
    aiSearchConnectionName: searchConnectionName
  }
}

resource existingProject 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' existing = if (aiProject.exists) {
  name: aiProject.name
  scope: resourceGroup(aiProject.subscriptionId, aiProject.resourceGroup)
}

module project '../ai/project.bicep' = if (!aiProject.exists) {
  name: 'project'
  params: {
    location: location
    tags: tags
    name: aiProject.name
    displayName: aiProject.name
    hubName: hub.outputs.name
    keyVaultName: hubDependencies.outputs.keyVaultName
  }
}

// Outputs
// Resource Group
output resourceGroupName string = resourceGroup().name

// Hub
output hubName string = aiHub.exists ? aiHub.name : hub.outputs.name
output hubPrincipalId string = aiHub.exists ? existingHub.identity.principalId : hub.outputs.principalId

// Project
output projectName string = aiProject.exists ? aiProject.name : project.outputs.name
output projectPrincipalId string = aiProject.exists ? existingProject.identity.principalId : project.outputs.principalId

// Key Vault
output keyVaultName string = hubDependencies.outputs.keyVaultName
output keyVaultEndpoint string = hubDependencies.outputs.keyVaultEndpoint

// Application Insights
output applicationInsightsName string = hubDependencies.outputs.applicationInsightsName
output logAnalyticsWorkspaceName string = hubDependencies.outputs.logAnalyticsWorkspaceName

// Container Registry
output containerRegistryName string = hubDependencies.outputs.containerRegistryName
output containerRegistryEndpoint string = hubDependencies.outputs.containerRegistryEndpoint

// Storage Account
output storageAccountName string = hubDependencies.outputs.storageAccountName

// Open AI
output openAiName string = hubDependencies.outputs.openAiName
output openAiEndpoint string = hubDependencies.outputs.openAiEndpoint

// Search
output searchServiceName string = hubDependencies.outputs.searchServiceName
output searchServiceEndpoint string = hubDependencies.outputs.searchServiceEndpoint

module outputHub '../../parseOptionalResource.bicep' = {
  name: 'outputHub'
  scope: aiHub.exists ? resourceGroup(aiHub.subscriptionId, aiHub.resourceGroup) : resourceGroup(resourceGroupName)
  params: {
    location: resourceGroup().location
    resourceId: aiHub.exists ? existingHub.id : hub.outputs.id
  }
}

module outputProject '../../parseOptionalResource.bicep' = {
  name: 'outputProject'
  scope: aiProject.exists ? resourceGroup(aiProject.subscriptionId, aiProject.resourceGroup) : resourceGroup(resourceGroupName)
  params: {
    location: resourceGroup().location
    resourceId: aiProject.exists ? existingProject.id : project.outputs.id
  }
}

output aiHub OptionalResource = outputHub.outputs.existingResource
output aiProject OptionalResource = outputProject.outputs.existingResource
output keyVault OptionalResource = hubDependencies.outputs.keyVault

