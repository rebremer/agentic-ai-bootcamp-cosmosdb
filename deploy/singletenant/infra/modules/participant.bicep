targetScope = 'resourceGroup'

@export()
@sealed()
type modelDeployment = {
  name: string
  version: string
  sku: 'GlobalStandard' | 'Standard' | 'DataZoneStandard'
  @minValue(1)
  capacity: int
}

@export()
type participantEnvironment = {
  participant: string
  principalId: string
  subscriptionId: string
  resourceGroup: string
  cosmosAccountName: string
  cosmosEndpoint: string
  cosmosDatabase: string
  foundryAccountName: string
  foundryEndpoint: string
  openAiEndpoint: string
  chatDeployment: string
  embeddingDeployment: string
  embeddingDimensions: int
}

@description('Participant database name, such as cosmosbc-001.')
param participantName string
@description('Globally unique name of the Cosmos DB account and Foundry account, such as cosmosbc-<random>-001.')
param accountName string
@description('Existing Entra user object ID.')
param principalId string
@description('Cosmos DB region.')
param location string
@description('Foundry region.')
param aiLocation string
@description('Chat deployment configuration.')
param chatModel modelDeployment
@description('Embedding deployment configuration.')
param embeddingModel modelDeployment
@description('Products container vector dimensions.')
param embeddingDimensions int
@description('Allowed Cosmos DB browser origins.')
param corsOrigins string[]
@description('Resource tags.')
param tags { *: string }

var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    minimalTlsVersion: 'Tls12'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      { name: 'EnableServerless' }
      { name: 'EnableNoSQLVectorSearch' }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    cors: [
      {
        allowedOrigins: join(corsOrigins, ',')
        allowedHeaders: '*'
        exposedHeaders: '*'
        maxAgeInSeconds: 3600
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: cosmos
  name: participantName
  properties: {
    resource: {
      id: participantName
    }
  }
}

resource chats 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: database
  name: 'chats'
  properties: {
    resource: {
      id: 'chats'
      partitionKey: {
        kind: 'Hash'
        paths: ['/sessionId']
      }
    }
  }
}

// Serialize container operations on each account; different participant accounts run independently.
resource products 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: database
  name: 'products'
  dependsOn: [chats]
  properties: {
    resource: {
      id: 'products'
      partitionKey: {
        kind: 'Hash'
        paths: ['/category']
      }
      vectorEmbeddingPolicy: {
        vectorEmbeddings: [
          {
            path: '/embedding'
            dataType: 'float32'
            dimensions: embeddingDimensions
            distanceFunction: 'cosine'
          }
        ]
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [{ path: '/*' }]
        excludedPaths: [
          { path: '/embedding/*' }
          { path: '/"_etag"/?' }
        ]
        vectorIndexes: [
          {
            path: '/embedding'
            type: 'quantizedFlat'
          }
        ]
      }
    }
  }
}

resource scratch 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = {
  parent: database
  name: 'test'
  dependsOn: [products]
  properties: {
    resource: {
      id: 'test'
      partitionKey: {
        kind: 'Hash'
        paths: ['/id']
      }
    }
  }
}

resource cosmosAccess 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmos
  name: guid(cosmos.id, principalId, cosmosDataContributorRoleId)
  dependsOn: [scratch]
  properties: {
    principalId: principalId
    roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
    scope: '${cosmos.id}/dbs/${database.name}'
  }
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: aiLocation
  kind: 'AIServices'
  tags: tags
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
  sku: {
    name: 'S0'
  }
}

resource chat 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: chatModel.name
  sku: {
    name: chatModel.sku
    capacity: chatModel.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModel.name
      version: chatModel.version
    }
  }
}

// Model deployment writes on one Foundry account must also run sequentially.
resource embeddings 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: embeddingModel.name
  dependsOn: [chat]
  sku: {
    name: embeddingModel.sku
    capacity: embeddingModel.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModel.name
      version: embeddingModel.version
    }
  }
}

resource foundryAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: foundry
  name: guid(foundry.id, principalId, openAiUserRoleId)
  properties: {
    principalId: principalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
  }
}

resource participantReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, readerRoleId)
  properties: {
    principalId: principalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
  }
}

output environment participantEnvironment = {
  participant: participantName
  principalId: principalId
  subscriptionId: subscription().subscriptionId
  resourceGroup: resourceGroup().name
  cosmosAccountName: cosmos.name
  cosmosEndpoint: cosmos.properties.documentEndpoint
  cosmosDatabase: database.name
  foundryAccountName: foundry.name
  foundryEndpoint: foundry.properties.endpoint
  openAiEndpoint: 'https://${foundry.properties.customSubDomainName}.openai.azure.com/'
  chatDeployment: chat.name
  embeddingDeployment: embeddings.name
  embeddingDimensions: embeddingDimensions
}
