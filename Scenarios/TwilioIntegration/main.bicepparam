using './main.bicep'

param namePrefix = 'twilio'
param environmentName = 'demo'
param tagCostCentre = 'DEMO'
param tagProjectCode = 'Twilio'
param queueName = 'twilio-sms'
param apimProductName = 'twilio'
param apimProductDisplayName = 'Twilio'

// Overridden by the GitHub Action from APIM_NAME / SERVICE_BUS_NAMESPACE / KEY_VAULT_NAME.
param apimName = 'replace-me'
param serviceBusNamespaceName = 'replace-me'
param keyVaultName = 'replace-me'
param pipelinePrincipalId = ''
