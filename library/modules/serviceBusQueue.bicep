/**************************************************************************
  Purpose: One queue on an existing Service Bus namespace. Call from a scenario.
**************************************************************************/
@description('Existing namespace name.')
param namespaceName string

@description('Queue name.')
@minLength(1)
param queueName string

@description('Principal granted Azure Service Bus Data Receiver on this queue. Empty skips.')
param receiverPrincipalId string = ''

@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param receiverPrincipalType string = 'ServicePrincipal'

resource namespace 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: namespaceName
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2026-01-01' = {
  parent: namespace
  name: queueName
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
  }
}

var serviceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e54d494dc01'

resource receiverAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(receiverPrincipalId)) {
  name: guid(queue.id, receiverPrincipalId, serviceBusDataReceiverRoleId)
  scope: queue
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataReceiverRoleId)
    principalId: receiverPrincipalId
    principalType: receiverPrincipalType
  }
}

output name string = queue.name
output id string = queue.id
