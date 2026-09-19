targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short name prefix used in resource names (letters/numbers only, lowercase preferred).')
@minLength(2)
@maxLength(16)
param namePrefix string = 'gisint'

@description('Environment label, e.g. demo.')
param environmentName string = 'demo'

@description('Cost centre tag (sample convention: CostCentre).')
param tagCostCentre string = 'DEMO'

@description('Project code tag (sample convention: ProjectCode).')
param tagProjectCode string = 'GisIntegration'

@description('Extra tags merged with CostCentre / ProjectCode / environment.')
param tags object = {}

@description('Key Vault name (3–24 chars, globally unique). Empty generates kv-<prefix>-<env>-<hash>.')
param keyVaultName string = ''

@description('API Management name (1–50 chars, globally unique). Empty generates apim-<prefix>-<env>-<hash>.')
param apiManagementName string = ''

@description('Consumption = cheapest demo (pay-per-call, capacity 0). Developer = cheap always-on eval SKU.')
@allowed([
  'Consumption'
  'Developer'
])
param apiManagementSku string = 'Consumption'

@description('Publisher email for APIM notifications.')
@minLength(1)
param publisherEmail string

@description('Publisher / organization name shown on the APIM instance.')
@minLength(1)
param publisherName string = 'GisIntegration Demo'

@description('APIM notification sender. Empty uses publisherEmail.')
param notificationSenderEmail string = ''

@description('Purge protection cannot be turned off later. Leave false for a disposable demo vault.')
param enablePurgeProtection bool = false

@description('CanNotDelete lock on APIM. Default false for a disposable demo.')
param enableDeleteLock bool = false

@description('Entra security group object ID granted Key Vault Secrets Officer. Empty skips. Do not pass a user OID.')
param keyVaultOfficerGroupObjectId string = ''

var resourceTags = union({
  project: 'GisIntegration'
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

module keyVault 'modules/keyVault.bicep' = {
  name: 'rg-deploy-keyvault'
  params: {
    name: resolvedKeyVaultName
    location: location
    tags: resourceTags
    enablePurgeProtection: enablePurgeProtection
  }
}

module apiManagement 'modules/apiManagement.bicep' = {
  name: 'rg-deploy-apim'
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

module keyVaultAssignApim 'modules/keyVaultAssignRole.bicep' = {
  name: 'rg-assign-kv-apim'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: apiManagement.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

module keyVaultAssignOfficerGroup 'modules/keyVaultAssignRole.bicep' = if (!empty(keyVaultOfficerGroupObjectId)) {
  name: 'rg-assign-kv-officer-group'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: keyVaultOfficerGroupObjectId
    principalType: 'Group'
    roleDefinitionId: keyVaultSecretsOfficerRoleId
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
