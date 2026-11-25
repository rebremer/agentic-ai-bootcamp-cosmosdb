targetScope = 'subscription'

import { modelDeployment, participantEnvironment } from 'participant.bicep'

@description('Lowercase alphanumeric base name.')
param namePrefix string
@description('Three-digit participant number, such as 001.')
param participantNumber string
@description('Seed for the random name segment.')
param nameSeed string
@description('Existing participant user object ID in this tenant.')
param principalId string
@description('Resource group and Cosmos DB region.')
param location string
@description('Foundry region.')
param aiLocation string
@description('Chat model configuration.')
param chatModel modelDeployment
@description('Embedding model configuration.')
param embeddingModel modelDeployment
@description('Products container vector dimensions.')
param embeddingDimensions int
@description('Cosmos DB browser origins.')
param corsOrigins string[]
@description('Additional resource tags.')
param tags { *: string }

// Resource group, database and tags use <prefix>-NNN; the globally unique account name adds a random segment before NNN
var participantName = '${namePrefix}-${participantNumber}'
var accountName = '${namePrefix}-${uniqueString(subscription().subscriptionId, participantName, nameSeed)}-${participantNumber}'

var resourceTags = union(tags, {
  purpose: 'cosmosdb-bootcamp'
  participant: participantName
})

resource participantGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${participantName}-rg'
  location: location
  tags: resourceTags
}

module resources 'participant.bicep' = {
  name: '${participantName}-resources'
  scope: participantGroup
  params: {
    participantName: participantName
    accountName: accountName
    principalId: principalId
    location: location
    aiLocation: aiLocation
    chatModel: chatModel
    embeddingModel: embeddingModel
    embeddingDimensions: embeddingDimensions
    corsOrigins: corsOrigins
    tags: resourceTags
  }
}

output environment participantEnvironment = resources.outputs.environment
