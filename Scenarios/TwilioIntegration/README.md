# TwilioIntegration

Email enqueue on the **shared landing-zone APIM**. This scenario does not create Key Vault, API Management, or a Service Bus namespace.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

```text
Caller  POST  {gateway}/twilio/emails
          → APIM (product key + managed identity)
          → Service Bus queue  twilio-email
          → Function sendEmail  (queue trigger; handler is empty)
```

Use the **same gateway** as GIS (`apiManagementGatewayUrl` from Deploy LandingZone, or Portal → APIM → Overview → Gateway URL). Twilio does not get a second APIM. Only the path changes: `/gis/...` vs `/twilio/emails`.

## What this creates

| Resource | Purpose |
|----------|---------|
| APIM product `twilio` | One **product**; one **subscription** per caller (`twilio-demo`, `allowTracing: false`) |
| Named values | `twilio-service-bus-hostname`, `twilio-email-queue` (not secrets) |
| APIM API `twilio-email` | POST `/emails`. Spec: [`library/policies/twilio-email.json`](../../library/policies/twilio-email.json). Backend is Service Bus REST. |
| Queue `twilio-email` | On the landing-zone namespace. Function identity is Data Receiver on the queue and the namespace. |
| Storage + Linux Consumption Function | .NET 8 isolated worker (`TwilioEmail.csproj`). Trigger `sendEmail` on `twilio-email`. Handler logs and completes; no send yet. Application Insights is created with the Function. |

APIM is already Data Sender on the namespace (landing zone). Copy the `twilio-demo` subscription key from the portal (APIM → Subscriptions), not from deployment outputs.

A previous SMS API (`twilio-sms`) and queue (`twilio-sms`) may still exist after apply. Delete those in the portal if you no longer need them.

## Call

```http
POST {gateway}/twilio/emails
Ocp-Apim-Subscription-Key: <twilio-demo key>
Content-Type: application/json

{"to":"someone@example.com","subject":"Hello","body":"Queued email"}
```

| Piece | Value |
|-------|--------|
| Host | Landing-zone **Gateway URL** (not the Function `*.azurewebsites.net`) |
| Path | `/twilio/emails` |
| Key | Product subscription `twilio-demo` |
| Body | `to`, `subject`, `body` |

Success from Service Bus through APIM is **201**. The Function then completes the message. Do not call the Function URL (no HTTP trigger; that is a 404).

## Configuration

Run **[Deploy LandingZone](../../library/LandingZones/README.md)** first. Then on Environment **`demo`**, set **variables** (not secrets) from that apply. Paste a single line with no trailing Enter:

| Variable | From landing zone output |
|----------|--------------------------|
| `APIM_NAME` | `apiManagementNameOut` (resource name only, no `.azure-api.net`) |
| `SERVICE_BUS_NAMESPACE` | `serviceBusNamespaceNameOut` (the existing namespace, not a new name) |
| `KEY_VAULT_NAME` | `keyVaultNameOut` |
| Plus the shared OIDC vars | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` |

Optional variable `AZURE_PIPELINE_OBJECT_ID` is the OIDC app object ID if `az ad sp show` is not allowed.

`apimName` / `serviceBusNamespaceName` / `keyVaultName` in `main.bicepparam` are placeholders; Actions overrides them.

Apply still writes these **Secrets** into the landing-zone vault (for when you add send logic). They are not used by the empty handler:

| GitHub Secret | Key Vault name | Function setting |
|---------------|----------------|------------------|
| `TWILIO_ACCOUNT_SID` | `Twilio-AccountSid` | `TWILIO_ACCOUNT_SID` |
| `TWILIO_API_KEY` | `Twilio-ApiKey` | `TWILIO_API_KEY` |
| `TWILIO_API_SECRET` | `Twilio-ApiSecret` | `TWILIO_API_SECRET` |
| `TWILIO_FROM_NUMBER` | `Twilio-FromNumber` | `TWILIO_FROM_NUMBER` |

Do not put those values in Bicep, GitHub variables, or the workflow file. The Function settings are Key Vault references. The pipeline is Key Vault Secrets Officer so CI can write them. The Function identity is Secrets User (read only).

## Deploy

Workflow: [`.github/workflows/twiliointegration-deploy.yml`](../../.github/workflows/twiliointegration-deploy.yml).

1. **Actions → Deploy TwilioIntegration → Run workflow**
2. **lint** (Bicep + `dotnet build`) → **what-if** → **apply**. No skip-plan.
3. Apply writes vault secrets, publishes `TwilioEmail.csproj`, zip-deploys, then restarts the Function.
4. Required reviewers on Environment **`demo`** (company control).

At work, add `validate-jwt` (Entra) on this API the same way GisIntegration does. This demo uses the product key only so you can exercise the queue path without a second app registration.
