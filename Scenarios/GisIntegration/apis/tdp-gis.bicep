/**************************************************************************
  Purpose: Tdp GIS API catalog entry. Owns the OpenAPI file, policy, and API identity.
  Backend URL is environment-specific. Product is passed in.
**************************************************************************/
param apimName string
param productName string
param backendUrl string

module api '../../../library/modules/apimOpenApi.bicep' = {
  name: 'import'
  params: {
    apimName: apimName
    productName: productName
    apiName: 'tdp-gis'
    apiPath: 'gis'
    apiDisplayName: 'Tdp Gis API'
    backendUrl: backendUrl
    openApiJson: loadTextContent('tdp-gis.json')
    policyXml: loadTextContent('../policies/tdp-gis-api.xml')
  }
}

output apiNameOut string = api.outputs.apiNameOut
output apiPathOut string = api.outputs.apiPathOut
