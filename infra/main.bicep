targetScope = 'subscription'

import { OptionalResource } from 'br:acrazdbicep.azurecr.io/bicep/types/common:v1'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'AI Studio Hub'
      description: 'The AI Studio Hub resource'
      type: 'Microsoft.MachineLearningServices/workspaces'
      kind: ['Hub']
    }
  }
})
param aiHub OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'AI Studio Project'
      description: 'The AI Studio Project resource'
      type: 'Microsoft.MachineLearningServices/workspaces'
      kind: ['Project']
    }
  }
})
param aiProject OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Azure AI Service'
      description: 'The Azure AI Service'
      type: 'Microsoft.CognitiveServices/accounts'
      kind: ['OpenAI', 'AIServices']
    }
  }
})
param aiService OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Key Vault'
      description: 'The Azure Key Vault resource'
      type: 'Microsoft.KeyVault/vaults'
    }
  }
})
param keyVault OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Storage Account'
      description: 'The Azure Storage Account resource'
      type: 'Microsoft.Storage/storageAccounts'
    }
  }
})
param storageAccount OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Application Insights'
      description: 'The Application Insights resource'
      type: 'Microsoft.Insights/components'
    }
  }
})
param applicationInsights OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Azure Search'
      description: 'The Azure Search resource'
      type: 'Microsoft.Search/searchServices'
    }
  }
})
param searchService OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Azure Container Registry'
      description: 'The Azure Container Registry resource'
      type: 'Microsoft.ContainerRegistry/registries'
    }
  }
})
param containerRegistry OptionalResource

@metadata({
  azd: {
    type: 'resource'
    resource: {
      displayName: 'Log Analytics Workspace'
      description: 'The Log Analytics Workspace resource'
      type: 'Microsoft.OperationalInsights/workspaces'
    }
  }
})
param logAnalytics OptionalResource

@description('The Azure resource group where new resources will be deployed')
param resourceGroupName string = ''

@description('The Open AI connection name. If ommited will use a default value')
param openAiConnectionName string = ''

@description('The Open AI content safety connection name. If ommited will use a default value')
param openAiContentSafetyConnectionName string = ''

@description('The Azure Search connection name. If ommited will use a default value')
param searchConnectionName string = ''

@description('The name of the machine learning online endpoint. If ommited will be generated')
param endpointName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('The type of the principal to assign application roles')
@allowed(['Device', 'ForeignGroup', 'Group', 'ServicePrincipal', 'User'])
param principalType string = 'User'

@description('The name of the azd service to use for the machine learning endpoint')
param endpointServiceName string = 'chat'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var aiConfig = loadYamlContent('./ai.yaml')

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module ai 'core/host/ai-environment.bicep' = {
  name: 'ai'
  scope: aiProject.exists ? resourceGroup(aiProject.subscriptionId, aiProject.resourceGroup) : rg
  params: {
    resourceGroupName: rg.name
    location: location
    tags: tags
    aiHub: aiHub
    aiProject: aiProject
    keyVault: keyVault
    storageAccount: storageAccount
    aiService: aiService
    openAiConnectionName: !empty(openAiConnectionName) ? openAiConnectionName : 'aoai-connection'
    openAiContentSafetyConnectionName: !empty(openAiContentSafetyConnectionName)
      ? openAiContentSafetyConnectionName
      : 'aoai-content-safety-connection'
    openAiModelDeployments: aiConfig.?deployments
    logAnalytics: logAnalytics
    applicationInsights: applicationInsights
    containerRegistry: containerRegistry
    searchService: searchService
    searchConnectionName: !empty(searchConnectionName) ? searchConnectionName : 'search-service-connection'
  }
}

module machineLearningEndpoint './core/host/ml-online-endpoint.bicep' = {
  name: 'endpoint'
  scope: rg
  params: {
    name: !empty(endpointName) ? endpointName : 'mloe-${resourceToken}'
    location: location
    tags: tags
    serviceName: endpointServiceName
    aiHub: ai.outputs.aiHub
    aiProject: ai.outputs.aiProject
    keyVault: ai.outputs.keyVault
  }
}

module userAcrRolePush 'core/security/role.bicep' = if (!empty(principalId)) {
  name: 'user-acr-role-push'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: '8311e382-0749-4cb8-b61a-304f252e45ec'
    principalType: principalType
  }
}

module userAcrRolePull 'core/security/role.bicep' = if (!empty(principalId)) {
  name: 'user-acr-role-pull'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    principalType: principalType
  }
}

module userRoleDataScientist 'core/security/role.bicep' = if (!empty(principalId)) {
  name: 'user-role-data-scientist'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
    principalType: principalType
  }
}

module userRoleSecretsReader 'core/security/role.bicep' = if (!empty(principalId)) {
  name: 'user-role-secrets-reader'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
    principalType: principalType
  }
}

// output the names of the resources
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name

output AZUREAI_HUB_NAME string = ai.outputs.hubName
output AZUREAI_PROJECT_NAME string = ai.outputs.projectName
output AZUREAI_ENDPOINT_NAME string = machineLearningEndpoint.outputs.name

output AZURE_OPENAI_NAME string = ai.outputs.openAiName
output AZURE_OPENAI_ENDPOINT string = ai.outputs.openAiEndpoint

output AZURE_SEARCH_NAME string = ai.outputs.searchServiceName
output AZURE_SEARCH_ENDPOINT string = ai.outputs.searchServiceEndpoint

output AZURE_CONTAINER_REGISTRY_NAME string = ai.outputs.containerRegistryName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = ai.outputs.containerRegistryEndpoint

output AZURE_KEYVAULT_NAME string = ai.outputs.keyVaultName
output AZURE_KEYVAULT_ENDPOINT string = ai.outputs.keyVaultEndpoint

output AZURE_STORAGE_ACCOUNT_NAME string = ai.outputs.storageAccountName
output AZURE_STORAGE_ACCOUNT_ENDPOINT string = ai.outputs.storageAccountName

output AZURE_APPLICATION_INSIGHTS_NAME string = ai.outputs.applicationInsightsName
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = ai.outputs.logAnalyticsWorkspaceName
