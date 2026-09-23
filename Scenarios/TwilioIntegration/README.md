# TwilioIntegration

SMS send path on the **shared landing zone**: APIM product + queue + Function App. This scenario does not create Key Vault, API Management, or a Service Bus namespace.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

```text
Caller  POST  {gateway}/twilio/messages
          → APIM (product key + managed identity)
          → Service Bus queue  twilio-sms
          → Function (queue trigger)
          → Twilio Messages API
```

## What this creates

| Resource | Purpose |
|----------|---------|
| APIM product `twilio` | One **product**; one **subscription** per caller (`twilio-demo`, `allowTracing: false`) |
| Named values | `twilio-service-bus-hostname`, `twilio-sms-queue` (not secrets) |
| APIM API `twilio-sms` | POST `/messages`. Spec: [`library/policies/twilio-sms.json`](../../library/policies/twilio-sms.json). Backend is Service Bus REST. |
| Queue `twilio-sms` | On the landing-zone namespace. Function identity is Data Receiver on this queue. |
| Storage + Linux Consumption Function | Sends SMS. Twilio credentials are Key Vault references, not app setting values. Application Insights is created with the Function (workspace-based). |

APIM is already Data Sender on the namespace (landing zone). Copy the `twilio-demo` subscription key from the portal (APIM → Subscriptions), not from deployment outputs.

## Configuration

Run **[Deploy LandingZone](../../library/LandingZones/README.md)** first. Then on Environment **`demo`**:

| Variable | Example |
|----------|---------|
| `APIM_NAME` | From landing zone output `apiManagementNameOut` |
| `SERVICE_BUS_NAMESPACE` | From `serviceBusNamespaceNameOut` |
| `KEY_VAULT_NAME` | From `keyVaultNameOut` |
| Plus the shared OIDC vars | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` |

`apimName` / `serviceBusNamespaceName` / `keyVaultName` in `main.bicepparam` are placeholders; Actions overrides them.

Put the Twilio credentials on Environment **`demo` as Secrets** (not variables, not in the workflow file):

| GitHub Secret | From Twilio | Key Vault name | Function setting |
|---------------|-------------|----------------|------------------|
| `TWILIO_ACCOUNT_SID` | Account SID (`AC…`) | `Twilio-AccountSid` | `TWILIO_ACCOUNT_SID` |
| `TWILIO_API_KEY` | API Key SID (`SK…`) | `Twilio-ApiKey` | `TWILIO_API_KEY` |
| `TWILIO_API_SECRET` | API Key Secret | `Twilio-ApiSecret` | `TWILIO_API_SECRET` |
| `TWILIO_FROM_NUMBER` | Your Twilio number (E.164) | `Twilio-FromNumber` | `TWILIO_FROM_NUMBER` |

The Function authenticates with **API Key + Secret** (not the account Auth Token). The Account SID is only the Messages URL path. You still need `TWILIO_FROM_NUMBER` so Twilio has a From address.

Apply writes those values into the landing-zone vault. The Function App settings are **Key Vault references**, so at runtime `process.env.TWILIO_API_KEY` (and the others) resolve to the secret. Do not put the values in Bicep, GitHub variables, or raw app settings.

This scenario grants the pipeline **Key Vault Secrets Officer** so CI can write those three names. Optional variable `AZURE_PIPELINE_OBJECT_ID` is the OIDC app object ID if `az ad sp show` is not allowed. The Function identity stays **Secrets User** (read only).

After apply:

```text
POST {gateway}/twilio/messages
Ocp-Apim-Subscription-Key: <twilio-demo key>
Content-Type: application/json

{"to":"+61400000000","body":"Hello from APIM"}
```

Service Bus should return **201**. The Function then POSTs to Twilio. Check Function invocation logs if the SMS does not arrive.

At work, add `validate-jwt` (Entra) on this API the same way GisIntegration does. This demo uses the product key only so you can exercise the queue path without a second app registration.

## Deploy

Workflow: [`.github/workflows/twiliointegration-deploy.yml`](../../.github/workflows/twiliointegration-deploy.yml).

- **Actions → Deploy TwilioIntegration → Run workflow**
- **lint → what-if → apply**. No skip-plan. Zip-deploy of the Function runs in **apply** only, after Bicep.
- Required reviewers on Environment **`demo`** (company control).
