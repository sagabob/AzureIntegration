/**************************************************************************
  Purpose: Grant a principal a Key Vault data-plane role (RBAC).
  Workloads: Secrets User (get/list). Human groups: Secrets Officer.
**************************************************************************/
@description('Existing Key Vault name.')
param keyVaultName string

@description('Object ID of the managed identity, service principal, or Entra group.')
param principalId string

@description('ServicePrincipal avoids AAD lookup lag on first deploy. Use Group for Entra security groups.')
@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param principalType string = 'ServicePrincipal'

@description('Built-in role definition GUID. Default is Key Vault Secrets User.')
param roleDefinitionId string = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2026-02-01' existing = {
  name: keyVaultName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}
