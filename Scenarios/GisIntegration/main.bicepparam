using './main.bicep'

param apimProductName = 'gis'
param apimProductDisplayName = 'GIS'

// Tdp GIS Container App base (no trailing slash, no /swagger). Empty skips the OpenAPI import.
param gisApiBackendUrl = 'https://ca-tdpgis-api-demo.icysmoke-149afb76.australiaeast.azurecontainerapps.io'

// Overridden by the GitHub Action from APIM_NAME / GIS_API_AUDIENCE.
param apimName = 'replace-me'
param gisApiAudience = 'replace-me'
