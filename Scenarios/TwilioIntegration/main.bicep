targetScope = 'resourceGroup'

@description('Existing APIM from the landing zone. From GitHub APIM_NAME.')
@minLength(1)
param apimName string

@description('Existing Service Bus namespace from the landing zone. From GitHub SERVICE_BUS_NAMESPACE.')
@minLength(1)
param serviceBusNamespaceName string

@description('Existing Key Vault from the landing zone. From GitHub KEY_VAULT_NAME.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('OIDC pipeline service-principal object ID. Granted Key Vault Secrets Officer so apply can write Twilio secrets. Empty skips. Not a user OID.')
param pipelinePrincipalId string = ''

@description('Short name prefix for Function App and storage (letters/numbers).')
@minLength(2)
@maxLength(16)
param namePrefix string = 'twilio'

@description('Environment label, e.g. demo.')
param environmentName string = 'demo'

@description('Cost centre tag.')
param tagCostCentre string = 'DEMO'

@description('Project code tag.')
param tagProjectCode string = 'Twilio'

@description('Extra tags merged with CostCentre / ProjectCode / environment.')
param tags object = {}

@description('Queue that receives SMS send requests.')
param queueName string = 'twilio-sms'

@description('APIM product id (URL-safe). All Twilio APIs join this product.')
param apimProductName string = 'twilio'

@description('APIM product display name.')
param apimProductDisplayName string = 'Twilio'

var resolvedApimName = trim(replace(apimName, '\r', ''))
var resolvedServiceBusNamespaceName = trim(replace(serviceBusNamespaceName, '\r', ''))
var resolvedKeyVaultName = trim(replace(keyVaultName, '\r', ''))
var resolvedPipelinePrincipalId = trim(replace(pipelinePrincipalId, '\r', ''))

var resourceTags = union({
  project: 'TwilioIntegration'
  environment: environmentName
  CostCentre: tagCostCentre
  ProjectCode: tagProjectCode
}, tags)

var storageAccountName = toLower(take(
  'st${replace(take(namePrefix, 6), '-', '')}${uniqueString(resourceGroup().id)}',
  24
))

var functionAppName = take(
  'func-${namePrefix}-${environmentName}-${uniqueString(resourceGroup().id)}',
  60
)

var serviceBusHostname = '${resolvedServiceBusNamespaceName}.servicebus.windows.net'

module storage '../../library/modules/storageAccount.bicep' = {
  name: 'twilio-storage'
  params: {
    name: storageAccountName
    tags: resourceTags
  }
}

module functionApp '../../library/modules/functionApp.bicep' = {
  name: 'twilio-function'
  params: {
    name: functionAppName
    tags: resourceTags
    storageAccountName: storage.outputs.name
    extraAppSettings: {
      WEBSITE_RUN_FROM_PACKAGE: '1'
      TWILIO_QUEUE_NAME: queueName
      ServiceBusConnection__fullyQualifiedNamespace: serviceBusHostname
      ServiceBusConnection__credential: 'managedidentity'
      TWILIO_ACCOUNT_SID: '@Microsoft.KeyVault(VaultName=${resolvedKeyVaultName};SecretName=Twilio-AccountSid)'
      TWILIO_API_KEY: '@Microsoft.KeyVault(VaultName=${resolvedKeyVaultName};SecretName=Twilio-ApiKey)'
      TWILIO_API_SECRET: '@Microsoft.KeyVault(VaultName=${resolvedKeyVaultName};SecretName=Twilio-ApiSecret)'
      TWILIO_FROM_NUMBER: '@Microsoft.KeyVault(VaultName=${resolvedKeyVaultName};SecretName=Twilio-FromNumber)'
    }
  }
}

module smsQueue '../../library/modules/serviceBusQueue.bicep' = {
  name: 'twilio-queue'
  params: {
    namespaceName: resolvedServiceBusNamespaceName
    queueName: queueName
    receiverPrincipalId: functionApp.outputs.principalId
    receiverPrincipalType: 'ServicePrincipal'
  }
}

module keyVaultAssignFunction '../../library/modules/keyVaultAssignRole.bicep' = {
  name: 'twilio-assign-kv-function'
  params: {
    keyVaultName: resolvedKeyVaultName
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

var keyVaultSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

module keyVaultAssignPipeline '../../library/modules/keyVaultAssignRole.bicep' = if (!empty(resolvedPipelinePrincipalId)) {
  name: 'twilio-assign-kv-pipeline'
  params: {
    keyVaultName: resolvedKeyVaultName
    principalId: resolvedPipelinePrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsOfficerRoleId
  }
}

module twilioProduct '../../library/modules/apimProduct.bicep' = {
  name: 'twilio-product'
  params: {
    apimName: resolvedApimName
    productName: apimProductName
    productDisplayName: apimProductDisplayName
  }
}

module serviceBusHostnameValue '../../library/modules/apimNamedValue.bicep' = {
  name: 'twilio-nv-sb-hostname'
  params: {
    apimName: resolvedApimName
    namedValueName: 'twilio-service-bus-hostname'
    namedValue: serviceBusHostname
  }
}

module queueNameValue '../../library/modules/apimNamedValue.bicep' = {
  name: 'twilio-nv-queue'
  params: {
    apimName: resolvedApimName
    namedValueName: 'twilio-sms-queue'
    namedValue: smsQueue.outputs.name
  }
}

module twilioSmsApi './apis/twilio-sms.bicep' = {
  name: 'twilio-sms-api'
  dependsOn: [
    serviceBusHostnameValue
    queueNameValue
  ]
  params: {
    apimName: resolvedApimName
    productName: twilioProduct.outputs.productNameOut
    backendUrl: 'https://${serviceBusHostname}'
  }
}

output apimNameOut string = resolvedApimName
output productNameOut string = twilioProduct.outputs.productNameOut
output apiNameOut string = twilioSmsApi.outputs.apiNameOut
output apiPathOut string = twilioSmsApi.outputs.apiPathOut
output queueNameOut string = smsQueue.outputs.name
output functionAppNameOut string = functionApp.outputs.name
output storageAccountNameOut string = storage.outputs.name
