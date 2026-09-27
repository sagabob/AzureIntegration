/**************************************************************************
  Purpose: Grant a data-plane role on one table. Default is Table Data Contributor.
**************************************************************************/
@description('Existing storage account name.')
param storageAccountName string

@description('Existing table name.')
param tableName string

@description('Object ID of the managed identity or service principal.')
param principalId string

@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param principalType string = 'ServicePrincipal'

@description('Built-in role GUID. Default is Storage Table Data Contributor.')
param roleDefinitionId string = '0a9a7e1f-b9cd-4c3f-8d01-4ea46c06ed8f'

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' existing = {
  parent: storage
  name: 'default'
}

resource table 'Microsoft.Storage/storageAccounts/tableServices/tables@2025-01-01' existing = {
  parent: tableService
  name: tableName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(table.id, principalId, roleDefinitionId)
  scope: table
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}
