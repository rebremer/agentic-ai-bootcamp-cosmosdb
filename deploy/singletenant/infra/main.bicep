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
param participantCount int = 100

@description('Existing Entra user object IDs in participant order. Supply exactly participantCount distinct IDs; deploy.ps1 resolves hackuserNNN automatically.')
param participantObjectIds string[]

@description('In subscription mode, exactly participantCount distinct existing subscription IDs in participant order, all in this tenant. Empty in resourceGroup mode.')
param participantSubscriptionIds string[] = []

@description('Lowercase alphanumeric base name, starting with a letter. The Cosmos DB account and Foundry account are named <namePrefix>-<random>-NNN, the database and resource group <namePrefix>-NNN (NNN = participant 001-999).')
@minLength(3)
@maxLength(12)
param namePrefix string = 'cosmosbc'

@description('Optional seed for the random name segment. The segment is deterministic per subscription, participant and seed; change the seed if a name is still reserved, e.g. by a soft-deleted Foundry account.')
param nameSeed string = ''

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

var participantNumbers = [for i in range(0, participantCount): padLeft(string(i + 1), 3, '0')]

module participants 'modules/participantSubscription.bicep' = [for (participantNumber, i) in participantNumbers: {
  name: '${namePrefix}-${participantNumber}'
  scope: subscription(isolationMode == 'subscription' ? participantSubscriptionIds[i] : subscription().subscriptionId)
  params: {
    namePrefix: namePrefix
    participantNumber: participantNumber
    nameSeed: nameSeed
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
