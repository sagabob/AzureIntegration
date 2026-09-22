targetScope = 'resourceGroup'

@description('Existing APIM from the landing zone. From GitHub APIM_NAME.')
@minLength(1)
param apimName string

@description('Tdp GIS API HTTPS base (no trailing slash). From main.bicepparam. Empty skips the OpenAPI import.')
param gisApiBackendUrl string = ''

@description('Expected JWT aud for the GIS API. From GitHub GIS_API_AUDIENCE. Not a secret.')
@minLength(1)
param gisApiAudience string

@description('APIM product id (URL-safe). All GIS APIs join this product.')
param apimProductName string = 'gis'

@description('APIM product display name.')
param apimProductDisplayName string = 'GIS'

module gisProduct '../../library/modules/apimProduct.bicep' = {
  name: 'gis-product'
  params: {
    apimName: apimName
    productName: apimProductName
    productDisplayName: apimProductDisplayName
  }
}

module gisApiAudienceValue '../../library/modules/apimNamedValue.bicep' = {
  name: 'gis-nv-audience'
  params: {
    apimName: apimName
    namedValueName: 'gis-api-audience'
    namedValue: gisApiAudience
  }
}

module tdpGisApi './apis/tdp-gis.bicep' = if (!empty(gisApiBackendUrl)) {
  name: 'gis-tdp-gis'
  dependsOn: [
    gisApiAudienceValue
  ]
  params: {
    apimName: apimName
    productName: gisProduct.outputs.productNameOut
    backendUrl: gisApiBackendUrl
  }
}

output apimNameOut string = apimName
output productNameOut string = gisProduct.outputs.productNameOut
output apiNameOut string = tdpGisApi.?outputs.apiNameOut ?? ''
output apiPathOut string = tdpGisApi.?outputs.apiPathOut ?? ''
