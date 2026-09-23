/**************************************************************************
  Purpose: Grant a data-plane role on an existing Service Bus namespace.
  Consumption Functions need Data Receiver on the namespace so the scale
  controller can see queue depth (queue-only RBAC is not enough).
**************************************************************************/
@description('Existing namespace name.')
param namespaceName string

@description('Object ID of the managed identity or service principal.')
param principalId string

@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param principalType string = 'ServicePrincipal'

@description('Built-in role GUID. Default is Azure Service Bus Data Receiver.')
param roleDefinitionId string = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'

resource namespace 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: namespaceName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(namespace.id, principalId, roleDefinitionId)
  scope: namespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}
