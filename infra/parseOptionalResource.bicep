import { OptionalResource } from 'br:acrazdbicep.azurecr.io/bicep/types/common:v1'

param resourceId string
param location string  = resourceGroup().location

// Split the resource ID by '/'
var resourceParts = split(resourceId, '/')

// Extract subscriptionId, resourceGroup, and resourceName
var subscriptionId = resourceParts[2]
var resourceGroup = resourceParts[4]
var resourceName = last(resourceParts)

// Outputs
var existingResource = {
  exists: true
  subscriptionId  : subscriptionId
  resourceGroup   : resourceGroup
  name: resourceName
}

output existingResource OptionalResource = existingResource
