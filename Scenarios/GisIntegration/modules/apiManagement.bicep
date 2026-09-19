/**************************************************************************
  Purpose: API Management instance (Consumption demo SKU by default).
  Security:
    - System-assigned identity for Key Vault named values
    - TLS 1.0/1.1/SSL3 and 3DES disabled
    - minApiVersion blocks old control-plane APIs
    - Global policy from policies/ (loadTextContent, same as samples)
  Child resources:
    1. APIM service
    2. Optional CanNotDelete lock
    3. Global policy
**************************************************************************/
@description('API Management instance name (1–50 chars, globally unique, alphanumeric and hyphens).')
@minLength(1)
@maxLength(50)
param name string

param location string = resourceGroup().location
param tags object = {}

@description('Publisher email for APIM notifications.')
@minLength(1)
param publisherEmail string

@description('Publisher / organization name shown on the instance.')
@minLength(1)
param publisherName string

@description('Notification sender. Defaults to publisherEmail when empty (sample: notificationSenderEmail).')
param notificationSenderEmail string = ''

@description('Consumption is pay-per-call with no dedicated unit (cheapest demo). Developer is a cheap always-on eval SKU with a developer portal.')
@allowed([
  'Consumption'
  'Developer'
])
param sku string = 'Consumption'

@description('Reject control-plane calls older than this API version.')
param minApiVersion string = '2021-08-01'

@description('CanNotDelete lock. Default false so a demo instance can be torn down.')
param enableDeleteLock bool = false

var skuCapacity = sku == 'Consumption' ? 0 : 1
var resolvedNotificationEmail = empty(notificationSenderEmail) ? publisherEmail : notificationSenderEmail

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: resolvedNotificationEmail
    publicNetworkAccess: 'Enabled'
    apiVersionConstraint: {
      minApiVersion: minApiVersion
    }
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${name}.azure-api.net'
        defaultSslBinding: true
        negotiateClientCertificate: false
      }
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
    }
  }
}

resource apimDeleteLock 'Microsoft.Authorization/locks@2020-05-01' = if (enableDeleteLock) {
  name: 'apim-delete-lock'
  scope: apiManagement
  properties: {
    level: 'CanNotDelete'
    notes: 'APIM should not be deleted'
  }
}

var globalPolicy = loadTextContent('policies/global-policy.xml')
resource globalPolicyResource 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  name: 'policy'
  parent: apiManagement
  properties: {
    value: globalPolicy
    format: 'rawxml'
  }
}

output id string = apiManagement.id
output name string = apiManagement.name
output gatewayUrl string = apiManagement.properties.gatewayUrl
output principalId string = apiManagement.identity.principalId
output sku string = apiManagement.sku.name
