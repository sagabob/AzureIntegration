targetScope = 'resourceGroup'

@description('Azure region. Default is the resource group location from the pipeline.')
param location string = resourceGroup().location

@description('Short name prefix used in resource names (letters/numbers only). Do not change after first apply.')
@minLength(2)
@maxLength(16)
param namePrefix string = 'gisint'

@description('Environment label, e.g. demo.')
param environmentName string = 'demo'

@description('Cost centre tag.')
param tagCostCentre string = 'DEMO'

@description('Project code tag for the shared platform.')
param tagProjectCode string = 'LandingZone'

@description('Extra tags merged with CostCentre / ProjectCode / environment.')
param tags object = {}

@description('Key Vault name (3–24 chars). Empty generates kv-<prefix>-<env>-<hash>.')
param keyVaultName string = ''

@description('API Management name (1–50 chars). Empty generates apim-<prefix>-<env>-<hash>.')
param apiManagementName string = ''

@description('Service Bus namespace. Empty generates sb-<prefix>-<env>-<hash>.')
param serviceBusNamespaceName string = ''

@description('Create a shared Service Bus namespace. Scenarios add queues.')
param enableServiceBus bool = true

@description('Consumption = cheapest demo. Developer = always-on eval SKU.')
@allowed([
  'Consumption'
  'Developer'
])
param apiManagementSku string = 'Consumption'

@description('Publisher email for APIM notifications. From APIM_PUBLISHER_EMAIL.')
@minLength(1)
param publisherEmail string

@description('Publisher / organization name shown on the APIM instance.')
@minLength(1)
param publisherName string = 'AzureIntegration'

@description('APIM notification sender. Empty uses publisherEmail.')
param notificationSenderEmail string = ''

@description('Purge protection cannot be turned off later. Leave false for a disposable demo vault.')
param enablePurgeProtection bool = false

@description('CanNotDelete lock on APIM. Default false for a disposable demo.')
param enableDeleteLock bool = false

@description('Entra security group object ID granted Key Vault Secrets Officer. Empty skips. Do not pass a user OID.')
param keyVaultOfficerGroupObjectId string = ''

@description('Entra tenant ID for shared named value entra-tenant-id. From AZURE_TENANT_ID.')
@minLength(1)
param entraTenantId string

var resourceTags = union({
  project: 'LandingZone'
  environment: environmentName
  CostCentre: tagCostCentre
  ProjectCode: tagProjectCode
}, tags)

var generatedKeyVaultName = take(
  'kv-${take(namePrefix, 6)}-${take(environmentName, 3)}-${uniqueString(resourceGroup().id)}',
  24
)
var resolvedKeyVaultName = empty(keyVaultName) ? generatedKeyVaultName : keyVaultName

var generatedApiManagementName = take(
  'apim-${namePrefix}-${environmentName}-${uniqueString(resourceGroup().id)}',
  50
)
var resolvedApiManagementName = empty(apiManagementName) ? generatedApiManagementName : apiManagementName

var generatedServiceBusName = take(
  'sb-${namePrefix}-${environmentName}-${uniqueString(resourceGroup().id)}',
  50
)
var resolvedServiceBusName = empty(serviceBusNamespaceName) ? generatedServiceBusName : serviceBusNamespaceName

module keyVault '../modules/keyVault.bicep' = {
  name: 'lz-deploy-keyvault'
  params: {
    name: resolvedKeyVaultName
    location: location
    tags: resourceTags
    enablePurgeProtection: enablePurgeProtection
  }
}

module apiManagement '../modules/apiManagement.bicep' = {
  name: 'lz-deploy-apim'
  params: {
    name: resolvedApiManagementName
    location: location
    tags: resourceTags
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: notificationSenderEmail
    sku: apiManagementSku
    enableDeleteLock: enableDeleteLock
  }
}

module keyVaultAssignApim '../modules/keyVaultAssignRole.bicep' = {
  name: 'lz-assign-kv-apim'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: apiManagement.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

module keyVaultAssignOfficerGroup '../modules/keyVaultAssignRole.bicep' = if (!empty(keyVaultOfficerGroupObjectId)) {
  name: 'lz-assign-kv-officer-group'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: keyVaultOfficerGroupObjectId
    principalType: 'Group'
    roleDefinitionId: keyVaultSecretsOfficerRoleId
  }
}

module entraTenantNamedValue '../modules/apimNamedValue.bicep' = {
  name: 'lz-nv-entra-tenant-id'
  params: {
    apimName: apiManagement.outputs.name
    namedValueName: 'entra-tenant-id'
    namedValue: entraTenantId
  }
}

module serviceBus '../modules/serviceBus.bicep' = if (enableServiceBus) {
  name: 'lz-deploy-servicebus'
  params: {
    name: resolvedServiceBusName
    location: location
    tags: resourceTags
    senderPrincipalId: apiManagement.outputs.principalId
    senderPrincipalType: 'ServicePrincipal'
  }
}

output keyVaultId string = keyVault.outputs.id
output keyVaultNameOut string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output apiManagementId string = apiManagement.outputs.id
output apiManagementNameOut string = apiManagement.outputs.name
output apiManagementGatewayUrl string = apiManagement.outputs.gatewayUrl
output apiManagementPrincipalId string = apiManagement.outputs.principalId
output apiManagementSkuOut string = apiManagement.outputs.sku
output serviceBusNamespaceNameOut string = serviceBus.?outputs.name ?? ''
output serviceBusHostnameOut string = serviceBus.?outputs.hostname ?? ''
