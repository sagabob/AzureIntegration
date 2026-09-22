/**************************************************************************
  Purpose: Shared Service Bus namespace. Queues belong to scenarios (serviceBusQueue.bicep).
**************************************************************************/
@description('Namespace name (6–50 chars, globally unique).')
@minLength(6)
@maxLength(50)
param name string

param location string = resourceGroup().location
param tags object = {}

@description('Basic = queues only (cheapest). Standard = queues + topics.')
@allowed([
  'Basic'
  'Standard'
])
param sku string = 'Basic'

@description('Principal granted Azure Service Bus Data Sender on the namespace. Empty skips.')
param senderPrincipalId string = ''

@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param senderPrincipalType string = 'ServicePrincipal'

var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'

resource namespace 'Microsoft.ServiceBus/namespaces@2026-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
}

resource senderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(senderPrincipalId)) {
  name: guid(namespace.id, senderPrincipalId, serviceBusDataSenderRoleId)
  scope: namespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataSenderRoleId)
    principalId: senderPrincipalId
    principalType: senderPrincipalType
  }
}

output id string = namespace.id
output name string = namespace.name
output endpoint string = namespace.properties.serviceBusEndpoint
output hostname string = '${namespace.name}.servicebus.windows.net'
