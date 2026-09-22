/**************************************************************************
  Purpose: One queue on an existing Service Bus namespace. Call from a scenario.
**************************************************************************/
@description('Existing namespace name.')
param namespaceName string

@description('Queue name.')
@minLength(1)
param queueName string

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

output name string = queue.name
output id string = queue.id
