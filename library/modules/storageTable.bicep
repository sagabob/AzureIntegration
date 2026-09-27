/**************************************************************************
  Purpose: One table on an existing StorageV2 account. No account keys.
  Names: letters and numbers only (3–63). Scenario supplies the name.
**************************************************************************/
@description('Existing storage account name.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Table name (alphanumeric).')
@minLength(3)
@maxLength(63)
param tableName string

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' existing = {
  parent: storage
  name: 'default'
}

resource table 'Microsoft.Storage/storageAccounts/tableServices/tables@2025-01-01' = {
  parent: tableService
  name: tableName
}

output name string = table.name
output id string = table.id
output tableServiceUri string = 'https://${storage.name}.table.${environment().suffixes.storage}'
