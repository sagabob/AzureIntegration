/**************************************************************************
  Purpose: One non-secret APIM named value. Scenario or landing zone supplies the value.
  Do not put secret values here — use Key Vault + secret: true instead.
**************************************************************************/
@description('Existing APIM service name.')
param apimName string

@description('Named value id and display name ({{this}} in policy).')
@minLength(1)
param namedValueName string

@description('Plain value. Not a secret.')
@minLength(1)
param namedValue string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource namedValueResource 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: namedValueName
  properties: {
    displayName: namedValueName
    secret: false
    value: namedValue
  }
}

output namedValueNameOut string = namedValueResource.name
