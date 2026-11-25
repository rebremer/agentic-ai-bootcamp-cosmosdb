targetScope = 'subscription'

import { modelDeployment, participantEnvironment } from 'modules/participant.bicep'

@description('resourceGroup: all participants in this subscription. subscription: one supplied existing subscription per participant.')
@allowed([
  'resourceGroup'
  'subscription'
])
param isolationMode string = 'resourceGroup'

@description('Number of participant environments, numbered 001 to 999.')
@minValue(1)
@maxValue(999)
param participantCount int = 3

@description('Existing Entra user object IDs in participant order. Supply exactly participantCount distinct IDs; deploy.ps1 resolves hackuserNNN automatically.')
param participantObjectIds string[]

@description('In subscription mode, exactly participantCount distinct existing subscription IDs in participant order, all in this tenant. Empty in resourceGroup mode.')
param participantSubscriptionIds string[] = []

@description('Globally unique lowercase alphanumeric base name, starting with a letter. The Cosmos DB account, Foundry account and database are all named <namePrefix>-NNN (001-999).')
@minLength(3)
@maxLength(12)
param namePrefix string = 'cosmosbc'

@description('Resource group and Cosmos DB region.')
param location string = 'swedencentral'

@description('Foundry region; independent of the Cosmos DB region to accommodate model availability and quota.')
param aiLocation string = location

@description('Chat deployment. Capacity is in model/SKU-specific quota units.')
param chatModel modelDeployment = {
  name: 'gpt-4.1-mini'
  version: '2025-04-14'
  sku: 'GlobalStandard'
  capacity: 10
}

@description('Embedding deployment. If changed, keep embeddingDimensions consistent with the embedding vectors your application requests.')
param embeddingModel modelDeployment = {
  name: 'text-embedding-3-small'
  version: '1'
  sku: 'GlobalStandard'
  capacity: 10
}

@description('Vector dimensions for the products container. Changing an existing container vector policy requires migration/recreation.')
@minValue(1)
@maxValue(4096)
param embeddingDimensions int = 1536

@description('Browser origins allowed by Cosmos DB. CORS is not an authorization boundary.')
@minLength(1)
param corsOrigins string[] = [
  'http://localhost:5500'
  'http://127.0.0.1:5500'
]

@description('Additional resource tags. No tenant-policy exemptions are applied automatically.')
param tags { *: string } = {}

var participantNames = [for i in range(0, participantCount): '${namePrefix}-${padLeft(string(i + 1), 3, '0')}']

module participants 'modules/participantSubscription.bicep' = [for (participantName, i) in participantNames: {
  name: participantName
  scope: subscription(isolationMode == 'subscription' ? participantSubscriptionIds[i] : subscription().subscriptionId)
  params: {
    participantName: participantName
    principalId: participantObjectIds[i]
    location: location
    aiLocation: aiLocation
    chatModel: chatModel
    embeddingModel: embeddingModel
    embeddingDimensions: embeddingDimensions
    corsOrigins: corsOrigins
    tags: tags
  }
}]

output tenantId string = tenant().tenantId
output environments participantEnvironment[] = [for i in range(0, participantCount): participants[i].outputs.environment]
