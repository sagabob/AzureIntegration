/**************************************************************************
  Purpose: Twilio email enqueue API. Owns the spec, policy, and API identity.
  Spec/policy live in library/policies so loadTextContent resolves in the editor
  (new scenario data folders are not visible to the Bicep language service).
  Path is twilio-email (not twilio) so it can sit next to twilio-sms.
**************************************************************************/
param apimName string
param productName string
param backendUrl string

module api '../../../library/modules/apimOpenApi.bicep' = {
  name: 'twilio-email-import'
  params: {
    apimName: apimName
    productName: productName
    apiName: 'twilio-email'
    apiPath: 'twilio-email'
    apiDisplayName: 'Twilio Email'
    backendUrl: backendUrl
    openApiJson: loadTextContent('../../../library/policies/twilio-email.json')
    policyXml: loadTextContent('../../../library/policies/twilio-email-api.xml')
  }
}

output apiNameOut string = api.outputs.apiNameOut
output apiPathOut string = api.outputs.apiPathOut
