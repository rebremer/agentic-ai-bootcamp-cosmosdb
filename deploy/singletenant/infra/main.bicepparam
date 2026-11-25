using 'main.bicep'

param isolationMode = 'resourceGroup'
param participantCount = 3
param namePrefix = 'cosmosbc'
param nameSeed = ''
param location = 'swedencentral'
param aiLocation = 'swedencentral'

// deploy.ps1 replaces this with the resolved object IDs of hackuser001..hackuserNNN.
// For direct Bicep deployment, fill exactly participantCount distinct user object IDs.
param participantObjectIds = []

// Used only for isolationMode = 'subscription'; existing subscriptions in the same tenant.
param participantSubscriptionIds = []

param chatModel = {
  name: 'gpt-4.1-mini'
  version: '2025-04-14'
  sku: 'GlobalStandard'
  capacity: 10
}
param embeddingModel = {
  name: 'text-embedding-3-small'
  version: '1'
  sku: 'GlobalStandard'
  capacity: 10
}
param embeddingDimensions = 1536
param corsOrigins = [
  'http://localhost:5500'
  'http://127.0.0.1:5500'
]
