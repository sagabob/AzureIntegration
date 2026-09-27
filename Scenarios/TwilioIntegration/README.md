# TwilioIntegration

Email and SMS enqueue on the **shared landing-zone APIM**. This scenario does not create Key Vault, API Management, or a Service Bus namespace.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

```text
Caller  POST  {gateway}/twilio-email/emails
          → APIM (product key + managed identity)
          → table twiliomessages (status=queued, RowKey=request id)
          → Service Bus queue  twilio-email
          → Function sendEmail  (updates status to sent or failed; Resend)

Caller  POST  {gateway}/twilio-sms/messages
          → APIM (product key + managed identity)
          → Service Bus queue  twilio-sms
          → Function sendSms  (queue trigger; handler is empty — add send later)
```

Use the **same gateway** as GIS (`apiManagementGatewayUrl` from Deploy LandingZone, or Portal → APIM → Overview → Gateway URL). Twilio does not get a second APIM. The two APIs use different path prefixes (`twilio-email` and `twilio-sms`) because APIM will not let two HTTP APIs share path `twilio`.

## What this creates

| Resource | Purpose |
|----------|---------|
| APIM product `twilio` | One **product**; one **subscription** per caller (`twilio-demo`, `allowTracing: false`) |
| Named values | `twilio-service-bus-hostname`, `twilio-email-queue`, `twilio-sms-queue`, `twilio-table-hostname`, `twilio-message-table` (not secrets) |
| Table `twiliomessages` | Payload + `Status`. APIM inserts `queued` (RowKey = APIM request id). Queue failure MERGEs `queueFailed`. Function merges `sent` / `failed`. APIM and Function identities are Table Data Contributor. |
| APIM API `twilio-email` | POST `/emails`. Spec: [`library/policies/twilio-email.json`](../../library/policies/twilio-email.json). Backend is Service Bus REST. |
| APIM API `twilio-sms` | POST `/messages`. Spec: [`library/policies/twilio-sms.json`](../../library/policies/twilio-sms.json). Backend is Service Bus REST. Send logic later. |
| Queue `twilio-email` | Function identity is Data Receiver on the queue and the namespace. |
| Queue `twilio-sms` | Same receiver. Kept so SMS can be developed later. |
| Storage + Linux Consumption Function | .NET 8 isolated worker (`TwilioEmail.csproj`). `sendEmail` sends through Resend (`https://api.resend.com/emails`). `sendSms` is still empty. Application Insights is created with the Function. |

APIM is already Data Sender on the namespace (landing zone). Copy the `twilio-demo` subscription key from the portal (APIM → Subscriptions), not from deployment outputs.

## Call email

```http
POST {gateway}/twilio-email/emails
Ocp-Apim-Subscription-Key: <twilio-demo key>
Content-Type: application/json

{"to":"someone@example.com","subject":"Hello","body":"Queued email"}
```

| Piece | Value |
|-------|--------|
| Host | Landing-zone **Gateway URL** (not the Function `*.azurewebsites.net`) |
| Path | `/twilio-email/emails` |
| Key | Product subscription `twilio-demo` |
| Body | `to` (well-formed email), `subject`, `body` — all required, non-blank |
| 400 | Missing fields, blank strings, or `to` is not `local@domain.tld` (shape only; not mailbox or MX) |
| 201 | Both succeeded: table row **and** queue. `{"status":"queued","id":"<APIM request id>"}` |

## Call SMS (enqueue only)

```http
POST {gateway}/twilio-sms/messages
Ocp-Apim-Subscription-Key: <twilio-demo key>
Content-Type: application/json

{"to":"+61400000000","body":"Queued SMS"}
```

| Piece | Value |
|-------|--------|
| Path | `/twilio-sms/messages` |
| Body | `to` (E.164), `body` |

APIM returns **400** (and does not enqueue) if `to`, `subject`, or `body` is missing/blank, or if `to` is not a well-formed email. That check is format only — not mailbox existence or MX. APIM writes the payload to table `twiliomessages` (`Status=queued`, `RowKey` = request id), then the queue (body includes `id`). **201** only if both succeed. Table failure does not enqueue. Queue failure MERGEs the row to `queueFailed` and returns the Service Bus status (not 201). `sendEmail` calls Resend and merges `sent` or `failed` on the same row. A Resend error retries and can dead-letter. Do not call the Function URL (no HTTP trigger; that is a 404).

Portal: storage account from `storageAccountNameOut` → **Storage browser** → **Tables** → `twiliomessages`. PartitionKey `email` or `sms`.

A previous SMS API on path `twilio` is updated in place to path `twilio-sms`. Call `/twilio-sms/messages`, not `/twilio/messages`.

## Configuration

Run **[Deploy LandingZone](../../library/LandingZones/README.md)** first. Then on Environment **`demo`**, set **variables** (not secrets) from that apply. Paste a single line with no trailing Enter:

| Variable | From landing zone output |
|----------|--------------------------|
| `APIM_NAME` | `apiManagementNameOut` (resource name only, no `.azure-api.net`) |
| `SERVICE_BUS_NAMESPACE` | `serviceBusNamespaceNameOut` (the existing namespace, not a new name) |
| `KEY_VAULT_NAME` | `keyVaultNameOut` |
| `FUNCTION_APP_NAME` | `functionAppNameOut` from **Deploy TwilioIntegration Infrastructure** (not the landing zone) |
| `EMAIL_FROM_ADDRESS` | Sender address (not a secret), e.g. `noreply@example.com` |
| Plus the shared OIDC vars | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` |

Optional variable `AZURE_PIPELINE_OBJECT_ID` is the OIDC app object ID if `az ad sp show` is not allowed.

`apimName` / `serviceBusNamespaceName` / `keyVaultName` in `main.bicepparam` are placeholders; Actions overrides them.

`sendEmail` reads `EMAIL_SERVICE_API_KEY` (Resend) and `EMAIL_FROM_ADDRESS` after Azure resolves the Key Vault references. The from address must be a domain you verified in Resend. Apply writes these into the landing-zone vault:

| GitHub Secret | Key Vault name | Function setting |
|---------------|----------------|------------------|
| `TWILIO_ACCOUNT_SID` | `Twilio-AccountSid` | `TWILIO_ACCOUNT_SID` |
| `TWILIO_API_KEY` | `Twilio-ApiKey` | `TWILIO_API_KEY` |
| `TWILIO_API_SECRET` | `Twilio-ApiSecret` | `TWILIO_API_SECRET` |
| `TWILIO_FROM_NUMBER` | `Twilio-FromNumber` | `TWILIO_FROM_NUMBER` |
| `EMAIL_SERVICE_API_KEY` | `Email-Service-ApiKey` | `EMAIL_SERVICE_API_KEY` |
| Variable `EMAIL_FROM_ADDRESS` | `Email-FromAddress` | `EMAIL_FROM_ADDRESS` |

Do not put those values in Bicep, GitHub variables, or the workflow file. The Function settings are Key Vault references. The pipeline is Key Vault Secrets Officer so CI can write them. The Function identity is Secrets User (read only).

## Deploy

Two workflows. Infra does not zip-deploy code.

1. **Actions → Deploy TwilioIntegration Infrastructure → Run workflow** ([`twiliointegration-deploy.yml`](../../.github/workflows/twiliointegration-deploy.yml))
2. **lint** → **what-if** → **apply**. No skip-plan. Apply writes vault secrets and prints `functionAppNameOut`.
3. Copy `functionAppNameOut` to Environment variable `FUNCTION_APP_NAME` (single line, no trailing Enter).
4. **Actions → Deploy TwilioIntegration Function → Run workflow** ([`twiliointegration-function-deploy.yml`](../../.github/workflows/twiliointegration-function-deploy.yml))
5. **build and test** → **zip-deploy** (`config-zip`) → restart. No ARM what-if. Tests do not call Azure or Resend.
6. Required reviewers on Environment **`demo`** (company control) for both.

Handler changes only need step 4. First time, or after the Function App name changes, run infra then the Function workflow.

## Unit tests

Parser, settings, `sendEmail` (mocked Resend), and the Resend HTTP payload. No Service Bus, Key Vault, or `api.resend.com`.

```powershell
dotnet test Scenarios/TwilioIntegration/function.tests/TwilioEmail.Tests.csproj
```

The Function deploy workflow runs the same `dotnet test` before zip-deploy.

At work, add `validate-jwt` (Entra) on these APIs the same way GisIntegration does. This demo uses the product key only so you can exercise the queue path without a second app registration.
