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

@description('Entra user object IDs of the participant (AllowedEntraUserIds). Each receives data-plane access to its own Cosmos DB database and Foundry account.')
@minLength(1)
param participantObjectIds string[]

@description('Lowercase alphanumeric base name for the Cosmos DB and Foundry accounts, starting with a letter.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'cosmosbc'

@description('Optional seed for the random account name segment. Change it if a name is still reserved, e.g. by a soft-deleted Foundry account.')
param nameSeed string = ''

@description('Cosmos DB database name that the participant selects.')
param databaseName string = 'cosmosbc'

@description('Region of all resources. Must follow the resource group so that region fallback of Invoke-MhhDeploymentWithRegionFallback works; do not hardcode it in a parameter file.')
param location string = resourceGroup().location

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

@description('Additional resource tags.')
param tags { *: string } = {}

var cosmosDataContributorRoleId = '00000000-0000-0000-0000-000000000002'
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// Globally unique, but stable per subscription and resource group so reruns update the same accounts.
var accountName = '${namePrefix}-${uniqueString(subscription().subscriptionId, resourceGroup().name, nameSeed)}'
var resourceTags = union(tags, { purpose: 'cosmosdb-bootcamp' })

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: resourceTags
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
  name: databaseName
  properties: {
    resource: {
      id: databaseName
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

// Container operations on one account are serialized.
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

resource cosmosAccess 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = [
  for principalId in participantObjectIds: {
    parent: cosmos
    name: guid(cosmos.id, principalId, cosmosDataContributorRoleId)
    dependsOn: [scratch]
    properties: {
      principalId: principalId
      roleDefinitionId: '${cosmos.id}/sqlRoleDefinitions/${cosmosDataContributorRoleId}'
      scope: '${cosmos.id}/dbs/${database.name}'
    }
  }
]

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  tags: resourceTags
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

// Model deployment writes on one Foundry account must run sequentially.
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

resource foundryAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in participantObjectIds: {
    scope: foundry
    name: guid(foundry.id, principalId, openAiUserRoleId)
    properties: {
      principalId: principalId
      principalType: 'User'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
    }
  }
]

output location string = location
output cosmosAccountName string = cosmos.name
output cosmosEndpoint string = cosmos.properties.documentEndpoint
output cosmosDatabase string = database.name
output foundryAccountName string = foundry.name
output foundryEndpoint string = 'https://${foundry.properties.customSubDomainName}.services.ai.azure.com'
output openAiEndpoint string = 'https://${foundry.properties.customSubDomainName}.openai.azure.com/'
output chatDeployment string = chat.name
output embeddingDeployment string = embeddings.name
output embeddingDimensions int = embeddingDimensions
