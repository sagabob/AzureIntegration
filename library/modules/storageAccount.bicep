/**************************************************************************
  Purpose: Storage account for a Function App host. No secret outputs.
**************************************************************************/
@description('Storage account name (3–24 chars, lowercase alphanumeric, globally unique).')
@minLength(3)
@maxLength(24)
param name string

param location string = resourceGroup().location
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

output name string = storage.name
output id string = storage.id
