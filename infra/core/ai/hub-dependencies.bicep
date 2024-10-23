import { OptionalResource } from 'br:acrazdbicep.azurecr.io/bicep/types/common:v1'

param location string = resourceGroup().location
param tags object = {}

param aiService OptionalResource
param keyVault OptionalResource
param storageAccount OptionalResource
param applicationInsights OptionalResource
param searchService OptionalResource
param containerRegistry OptionalResource
param logAnalytics OptionalResource

@description('Array of OpenAI model deployments')
param openAiModelDeployments array = []

resource existingKeyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = if (keyVault.exists) {
  name: keyVault.name
  scope: resourceGroup(keyVault.subscriptionId, keyVault.resourceGroup)
}

module newKeyVault '../security/keyvault.bicep' = if (!keyVault.exists) {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    name: keyVault.name
  }
}

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (storageAccount.exists) {
  name: storageAccount.name
  scope: resourceGroup(storageAccount.subscriptionId, storageAccount.resourceGroup)
}

module newStorageAccount '../storage/storage-account.bicep' = if (!storageAccount.exists) {
  name: 'storageAccount'
  params: {
    location: location
    tags: tags
    name: storageAccount.name
    containers: [
      {
        name: 'default'
      }
    ]
    files: [
      {
        name: 'default'
      }
    ]
    queues: [
      {
        name: 'default'
      }
    ]
    tables: [
      {
        name: 'default'
      }
    ]
    corsRules: [
      {
        allowedOrigins: [
          'https://mlworkspace.azure.ai'
          'https://ml.azure.com'
          'https://*.ml.azure.com'
          'https://ai.azure.com'
          'https://*.ai.azure.com'
          'https://mlworkspacecanary.azure.ai'
          'https://mlworkspace.azureml-test.net'
        ]
        allowedMethods: [
          'GET'
          'HEAD'
          'POST'
          'PUT'
          'DELETE'
          'OPTIONS'
          'PATCH'
        ]
        maxAgeInSeconds: 1800
        exposedHeaders: [
          '*'
        ]
        allowedHeaders: [
          '*'
        ]
      }
    ]
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: false
    }
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (logAnalytics.exists) {
  name: logAnalytics.name
  scope: resourceGroup(logAnalytics.subscriptionId, logAnalytics.resourceGroup)
}

module newLogAnalytics '../monitor/loganalytics.bicep' = if (!logAnalytics.exists) {
  name: 'logAnalytics'
  params: {
    location: location
    tags: tags
    name: logAnalytics.name
  }
}

resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (applicationInsights.exists) {
  name: existingLogAnalytics.name
  scope: resourceGroup(applicationInsights.subscriptionId, applicationInsights.resourceGroup)
}

module newApplicationInsights '../monitor/applicationinsights.bicep' = if (!applicationInsights.exists){
  name: 'applicationInsights'
  params: {
    location: location
    tags: tags
    name: applicationInsights.name
    logAnalyticsWorkspaceId: logAnalytics.exists ? existingLogAnalytics.id : newLogAnalytics.outputs.id
  }
}

resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (containerRegistry.exists) {
  name: containerRegistry.name
  scope: resourceGroup(containerRegistry.subscriptionId, containerRegistry.resourceGroup)
}

module newContainerRegistry '../host/container-registry.bicep' = if (!containerRegistry.exists) {
  name: 'containerRegistry'
  params: {
    location: location
    tags: tags
    name: containerRegistry.name
  }
}

resource existingCognitiveServices 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' existing = if (aiService.exists) {
  name: aiService.name
  scope: resourceGroup(aiService.subscriptionId, aiService.resourceGroup)
}

module newCognitiveServices '../ai/cognitiveservices.bicep' = if (!aiService.exists) {
  name: 'cognitiveServices'
  params: {
    location: location
    tags: tags
    name: aiService.name
    kind: 'AIServices'
    deployments: openAiModelDeployments
  }
}

resource existingSearchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = if (searchService.exists) {
  name: searchService.name
  scope: resourceGroup(searchService.subscriptionId, searchService.resourceGroup)
}

module newSearchService '../search/search-services.bicep' = if (!searchService.exists) {
  name: 'searchService'
  params: {
    location: location
    tags: tags
    name: searchService.name
    sku: {
      name: 'free'
    }
  }
}

module outputKeyVault '../../parseOptionalResource.bicep' = {
  name: 'outputKeyVault'
  params: {
    resourceId: keyVault.exists ? existingKeyVault.id : newKeyVault.outputs.id
  }
}

output keyVaultId string = keyVault.exists ? existingKeyVault.id : newKeyVault.outputs.id
output keyVaultName string = keyVault.exists ? existingKeyVault.name : newKeyVault.outputs.name
output keyVaultEndpoint string = keyVault.exists ? existingKeyVault.properties.vaultUri : newKeyVault.outputs.endpoint

output storageAccountId string = storageAccount.exists ? existingStorageAccount.id : newStorageAccount.outputs.id
output storageAccountName string = storageAccount.exists ? existingStorageAccount.name : newStorageAccount.outputs.name

output containerRegistryId string = containerRegistry.exists ? existingContainerRegistry.id : newContainerRegistry.outputs.id
output containerRegistryName string = containerRegistry.exists ? existingContainerRegistry.name : newContainerRegistry.outputs.name
output containerRegistryEndpoint string = containerRegistry.exists ? existingContainerRegistry.properties.loginServer : newContainerRegistry.outputs.loginServer

output applicationInsightsId string = applicationInsights.exists ? existingApplicationInsights.id : newApplicationInsights.outputs.id
output applicationInsightsName string = applicationInsights.exists ? existingApplicationInsights.name : newApplicationInsights.outputs.name
output logAnalyticsWorkspaceId string = logAnalytics.exists ? existingLogAnalytics.id : newLogAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.exists ? existingLogAnalytics.name : newLogAnalytics.outputs.name

output openAiId string = aiService.exists ? existingCognitiveServices.id : newCognitiveServices.outputs.id
output openAiName string = aiService.exists ? existingCognitiveServices.name : newCognitiveServices.outputs.name
output openAiEndpoint string = aiService.exists ? existingCognitiveServices.properties.endpoints['OpenAI Language Model Instance API'] : newCognitiveServices.outputs.endpoint

output searchServiceId string = searchService.exists ? existingSearchService.id : newSearchService.outputs.id
output searchServiceName string = searchService.exists ? existingSearchService.name : newSearchService.outputs.name
output searchServiceEndpoint string = searchService.exists ? 'https://${existingSearchService.name}.search.windows.net/' : newSearchService.outputs.endpoint

output keyVault OptionalResource = outputKeyVault.outputs.existingResource
