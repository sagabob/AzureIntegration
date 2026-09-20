/**************************************************************************
  Purpose: Import OpenAPI into APIM and attach the API to an existing product.
  Generic: no spec filename here. Catalog wrappers (modules/apis/*.bicep) load the JSON.
**************************************************************************/
@description('Existing APIM service name.')
param apimName string

@description('Existing product name. Pass from the product module output.')
param productName string

@description('APIM API resource name (URL-safe). Set by the catalog wrapper, not main.bicepparam.')
@minLength(1)
param apiName string

@description('Public path prefix. Callers use https://{gateway}/{path}/...')
@minLength(1)
param apiPath string

@description('Portal display name. Empty uses apiName.')
param apiDisplayName string = ''

@description('Existing API HTTPS base URL (no trailing slash).')
param backendUrl string

@description('OpenAPI document text. Caller loads a literal path with loadTextContent.')
param openApiJson string

@description('APIM import format. openapi+json = OpenAPI 3 JSON; swagger-json = Swagger 2.')
@allowed([
  'openapi+json'
  'swagger-json'
])
param openApiFormat string = 'openapi+json'

@description('API policy XML. Empty uses the shared inherit-global policy.')
param policyXml string = ''

var resolvedDisplayName = empty(apiDisplayName) ? apiName : apiDisplayName

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: resolvedDisplayName
    description: '${resolvedDisplayName}. Callers send APIM subscription key plus any backend tokens (Authorization, X-Access-Token).'
    path: apiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    serviceUrl: backendUrl
    format: openApiFormat
    value: openApiJson
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    value: empty(policyXml) ? loadTextContent('policies/api-inherit-global.xml') : policyXml
    format: 'rawxml'
  }
}

resource product 'Microsoft.ApiManagement/service/products@2024-05-01' existing = {
  parent: apim
  name: productName
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = {
  parent: product
  name: api.name
}

output apiNameOut string = api.name
output apiPathOut string = api.properties.path
