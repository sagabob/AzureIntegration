/**************************************************************************
  Purpose: Azure Key Vault as the store of record for secrets.
  Security:
    - Never put secret values in this module
    - RBAC only (no access policies); grant get/list via keyVaultAssignRole
    - Platform features that would broaden vault use are off
**************************************************************************/
@description('Key Vault name (3–24 chars, globally unique, alphanumeric and hyphens).')
@minLength(3)
@maxLength(24)
param name string

param location string = resourceGroup().location
param tags object = {}

@description('Soft-delete retention in days (7–90). Microsoft conventional default is 90.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Purge protection cannot be disabled later. Leave false for a disposable demo vault. Do not send false to the API — omit the property.')
param enablePurgeProtection bool = false

var vaultProperties = {
  sku: {
    family: 'A'
    name: 'standard'
  }
  tenantId: tenant().tenantId
  enableRbacAuthorization: true
  enableSoftDelete: true
  softDeleteRetentionInDays: softDeleteRetentionInDays
  enabledForDeployment: false
  enabledForTemplateDeployment: false
  enabledForDiskEncryption: false
  publicNetworkAccess: 'Enabled'
  networkAcls: {
    defaultAction: 'Allow'
    bypass: 'AzureServices'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: name
  location: location
  tags: tags
  properties: enablePurgeProtection ? union(vaultProperties, { enablePurgeProtection: true }) : vaultProperties
}

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
