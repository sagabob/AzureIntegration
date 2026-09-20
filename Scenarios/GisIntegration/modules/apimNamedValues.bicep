/**************************************************************************
  Purpose: Non-secret APIM named values for validate-jwt (tenant, audience).
  Values come from GitHub Environment variables, not from this file.
**************************************************************************/
@description('Existing APIM service name.')
param apimName string

@description('Entra tenant ID. From AZURE_TENANT_ID. Used in openid-config and issuer.')
@minLength(1)
param entraTenantId string

@description('Expected JWT aud claim for the GIS API. From GIS_API_AUDIENCE.')
@minLength(1)
param gisApiAudience string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource entraTenantIdValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'entra-tenant-id'
  properties: {
    displayName: 'entra-tenant-id'
    secret: false
    value: entraTenantId
  }
}

resource gisApiAudienceValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'gis-api-audience'
  properties: {
    displayName: 'gis-api-audience'
    secret: false
    value: gisApiAudience
  }
}
