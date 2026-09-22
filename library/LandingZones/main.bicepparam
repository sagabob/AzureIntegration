using './main.bicep'

param namePrefix = 'gisint'
param environmentName = 'demo'
param tagCostCentre = 'DEMO'
param tagProjectCode = 'LandingZone'
param publisherName = 'AzureIntegration'

param keyVaultName = ''
param apiManagementName = ''
param serviceBusNamespaceName = ''
param enableServiceBus = true
param apiManagementSku = 'Consumption'

// Overridden by the GitHub Action from APIM_PUBLISHER_EMAIL / AZURE_TENANT_ID.
param publisherEmail = 'replace-me@example.com'
param entraTenantId = '00000000-0000-0000-0000-000000000000'
param notificationSenderEmail = ''

param enablePurgeProtection = false
param enableDeleteLock = false
param keyVaultOfficerGroupObjectId = ''
