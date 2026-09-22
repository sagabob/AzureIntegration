/**************************************************************************
  Purpose: Reusable APIM product plus an optional demo subscription.
  Product id comes from the scenario. Do not output keys.
**************************************************************************/
@description('Existing APIM service name.')
param apimName string

@description('Product id (URL-safe).')
@minLength(1)
param productName string

@description('Portal display name. Empty uses productName.')
param productDisplayName string = ''

@description('API names (APIM api resource names) to attach. Empty if APIs attach themselves.')
param apiNames array = []

@description('Create one active subscription for local/demo callers. Extra callers = extra subscriptions, same product.')
param createDemoSubscription bool = true

var resolvedDisplayName = empty(productDisplayName) ? productName : productDisplayName

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource product 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  parent: apim
  name: productName
  properties: {
    displayName: resolvedDisplayName
    description: 'APIs for ${resolvedDisplayName}. One product; one subscription per caller.'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource productApis 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = [
  for apiName in apiNames: {
    parent: product
    name: apiName
  }
]

resource demoSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = if (createDemoSubscription) {
  parent: apim
  name: '${productName}-demo'
  properties: {
    displayName: '${resolvedDisplayName} demo'
    scope: '/products/${product.name}'
    state: 'active'
    allowTracing: false
  }
}

output productNameOut string = product.name
output productId string = product.id
