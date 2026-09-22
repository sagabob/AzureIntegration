/**************************************************************************
  Purpose: Twilio SMS enqueue API. Owns the spec, policy, and API identity.
  Spec/policy live in library/policies so loadTextContent resolves in the editor
  (new scenario data folders are not visible to the Bicep language service).
  Backend is the landing-zone Service Bus namespace. Product is passed in.
**************************************************************************/
param apimName string
param productName string
param backendUrl string

module api '../../../library/modules/apimOpenApi.bicep' = {
  name: 'import'
  params: {
    apimName: apimName
    productName: productName
    apiName: 'twilio-sms'
    apiPath: 'twilio'
    apiDisplayName: 'Twilio SMS'
    backendUrl: backendUrl
    openApiJson: loadTextContent('../../../library/policies/twilio-sms.json')
    policyXml: loadTextContent('../../../library/policies/twilio-sms-api.xml')
  }
}

output apiNameOut string = api.outputs.apiNameOut
output apiPathOut string = api.outputs.apiPathOut
