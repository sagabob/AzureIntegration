using './main.bicep'

param namePrefix = 'gisint'
param environmentName = 'demo'
param tagCostCentre = 'DEMO'
param tagProjectCode = 'GisIntegration'
param apimProductName = 'gis'
param apimProductDisplayName = 'GIS'

// Tdp GIS Container App base (no trailing slash, no /swagger). Empty skips the OpenAPI import.
param gisApiBackendUrl = 'https://ca-tdpgis-api-demo.icysmoke-149afb76.australiaeast.azurecontainerapps.io'

// Leave empty to generate globally unique names from the resource group id.
param keyVaultName = ''
param apiManagementName = ''

// Consumption: no dedicated unit, billed per call (cheapest demo).
// Developer: ~fixed monthly eval SKU with a developer portal; set capacity 1.
param apiManagementSku = 'Consumption'

// Overridden by the GitHub Action from APIM_PUBLISHER_EMAIL / AZURE_TENANT_ID / GIS_API_AUDIENCE.
// Do not put secrets or the real audience in this file.
param publisherEmail = 'replace-me@example.com'
param entraTenantId = '00000000-0000-0000-0000-000000000000'
param gisApiAudience = 'replace-me'
param publisherName = 'GisIntegration Demo'
param notificationSenderEmail = ''

param enablePurgeProtection = false
param enableDeleteLock = false

// Entra security group object ID (az ad group show --group '<name>' --query id -o tsv). Empty = no human Officer grant.
param keyVaultOfficerGroupObjectId = ''
