# TwilioIntegration

Email send path on the **shared landing zone**: APIM product + queue + Function App. This scenario does not create Key Vault, API Management, or a Service Bus namespace.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

```text
Caller  POST  {gateway}/twilio/emails
          → APIM (product key + managed identity)
          → Service Bus queue  twilio-email
          → Function sendEmail (queue trigger, handler empty for now)
```

## What this creates

| Resource | Purpose |
|----------|---------|
| APIM product `twilio` | One **product**; one **subscription** per caller (`twilio-demo`, `allowTracing: false`) |
| Named values | `twilio-service-bus-hostname`, `twilio-email-queue` (not secrets) |
| APIM API `twilio-email` | POST `/emails`. Spec: [`library/policies/twilio-email.json`](../../library/policies/twilio-email.json). Backend is Service Bus REST. |
| Queue `twilio-email` | On the landing-zone namespace. Function identity is Data Receiver on this queue. |
| Storage + Linux Consumption Function | .NET 8 isolated worker. Queue trigger `sendEmail` (empty). Application Insights is created with the Function. |

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

Twilio GitHub secrets are still written to Key Vault on apply (for when the Function sends). The handler does not use them yet.

After apply:

```text
POST {gateway}/twilio/emails
Ocp-Apim-Subscription-Key: <twilio-demo key>
Content-Type: application/json

{"to":"someone@example.com","subject":"Hello","body":"Queued email"}
```

Service Bus should return **201**. `sendEmail` completes the message and does nothing else until you add send logic.

At work, add `validate-jwt` (Entra) on this API the same way GisIntegration does. This demo uses the product key only so you can exercise the queue path without a second app registration.

## Deploy

Workflow: [`.github/workflows/twiliointegration-deploy.yml`](../../.github/workflows/twiliointegration-deploy.yml).

- **Actions → Deploy TwilioIntegration → Run workflow**
- **lint → what-if → apply**. No skip-plan. Zip-deploy of the Function runs in **apply** only, after Bicep.
- Required reviewers on Environment **`demo`** (company control).
