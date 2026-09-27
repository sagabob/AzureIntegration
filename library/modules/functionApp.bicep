/**************************************************************************
  Purpose: Linux Consumption Function App with system-assigned identity.
  Host storage key stays in this module (listKeys → app settings). Do not output it.
  Workload secrets belong in Key Vault references passed via extraAppSettings.
**************************************************************************/
@description('Function App name (globally unique).')
@minLength(2)
@maxLength(60)
param name string

param location string = resourceGroup().location
param tags object = {}

@description('Existing storage account name (host storage).')
param storageAccountName string

@allowed([
  'dotnet-isolated'
  'node'
])
@description('Functions worker. Twilio uses dotnet-isolated.')
param workerRuntime string = 'dotnet-isolated'

@description('Runtime version. 8.0 for isolated .NET, 24 for Node.')
param runtimeVersion string = '8.0'

@description('App settings merged with host defaults. Do not put secret values here; use Key Vault references.')
param extraAppSettings object = {}

@description('Create a Log Analytics workspace and Application Insights. Connection string stays in this module.')
param enableApplicationInsights bool = true

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'asp-${take(name, 20)}'
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

var linuxFxVersion = workerRuntime == 'node' ? 'Node|${runtimeVersion}' : 'DOTNET-ISOLATED|${runtimeVersion}'

resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = if (enableApplicationInsights) {
  name: take('log-${name}', 63)
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: take('appi-${name}', 255)
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

var nodeSettings = workerRuntime == 'node' ? {
  WEBSITE_NODE_DEFAULT_VERSION: '~${runtimeVersion}'
} : {}

var hostSettings = union({
  AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTIONS_WORKER_RUNTIME: workerRuntime
}, nodeSettings)

var insightsSettings = enableApplicationInsights ? {
  APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights!.properties.ConnectionString
} : {}

resource appSettings 'Microsoft.Web/sites/config@2024-11-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: union(hostSettings, insightsSettings, extraAppSettings)
}

output name string = functionApp.name
output id string = functionApp.id
output principalId string = functionApp.identity.principalId
output defaultHostName string = functionApp.properties.defaultHostName
output applicationInsightsName string = enableApplicationInsights ? appInsights!.name : ''
