# AzureIntegration

Shared **landing zone** (one APIM, one Key Vault, one Service Bus namespace) plus **scenarios** that add products, APIs, and queues on that platform. Scenarios do not create another gateway.

Treat this as **practice for a secure company**. Copy OIDC, lint → what-if → apply, Key Vault references, and Entra groups.

**GitHub → Azure:** [Connect GitHub Actions to Azure (OIDC)](docs/github-azure-oidc.md). No `AZURE_CLIENT_SECRET`. Deploy from Actions only.

| Piece | What it deploys |
|-------|-----------------|
| [Landing zone](library/LandingZones/README.md) | Key Vault, Consumption APIM, Service Bus namespace, `entra-tenant-id` |
| [Library](library/README.md) | Shared Bicep modules (no environment URLs, no swagger filenames) |
| [GisIntegration](Scenarios/GisIntegration/README.md) | Product `gis` + Tdp GIS OpenAPI + `validate-jwt` on the shared APIM |
| [TwilioIntegration](Scenarios/TwilioIntegration/README.md) | Product `twilio` + APIs + queues + table `twiliomessages` (payload + status) + Function `sendEmail` (Resend) / `sendSms` (empty) |

## Deploy order

1. **Deploy LandingZone** ([`landingzone-deploy.yml`](.github/workflows/landingzone-deploy.yml)) — **lint → what-if → apply**.
2. Copy apply outputs to Environment **`demo`** variables (single line, no trailing Enter): `APIM_NAME`, `SERVICE_BUS_NAMESPACE`, `KEY_VAULT_NAME`.
3. Run a scenario. GIS is one workflow. Twilio is two (infra, then Function code).

Required reviewers on Environment **`demo`** so Apply waits until someone reads the what-if.

| Workflow | When |
|----------|------|
| [Deploy LandingZone](.github/workflows/landingzone-deploy.yml) | First, and when the shared vault / APIM / namespace changes |
| [Deploy GisIntegration](.github/workflows/gisintegration-deploy.yml) | GIS product, API, JWT named value |
| [Deploy TwilioIntegration Infrastructure](.github/workflows/twiliointegration-deploy.yml) | Queues, Function **App**, APIM product/APIs, **API policy XML**, vault secret writes |
| [Deploy TwilioIntegration Function](.github/workflows/twiliointegration-function-deploy.yml) | `sendEmail` / `sendSms` zip only. **build and test** then `config-zip`. Set `FUNCTION_APP_NAME` from infra `functionAppNameOut` |

## Twilio (index)

Call the **landing-zone Gateway URL**, not the Function `*.azurewebsites.net`.

```text
POST {gateway}/twilio-email/emails     → 400 if invalid; else table (queued) + queue → sendEmail (sent/failed)
POST {gateway}/twilio-sms/messages     → table (queued) + queue → sendSms (handler empty)
```

APIM email policy is [`library/policies/twilio-email-api.xml`](library/policies/twilio-email-api.xml). Infra apply compiles it with `loadTextContent` and PUTs `apis/twilio-email/policies/policy`. The Function zip-deploy does not update APIM.

Policy changes: commit the XML, run **Deploy TwilioIntegration Infrastructure** on that branch, read what-if, approve apply.

Handler / test changes: **Deploy TwilioIntegration Function**.

```powershell
dotnet test Scenarios/TwilioIntegration/function.tests/TwilioEmail.Tests.csproj
```

Tests do not call Azure or Resend. Details: [TwilioIntegration README](Scenarios/TwilioIntegration/README.md).

## Consumption APIM workarounds

The landing-zone gateway is **Consumption**. Several features other SKUs allow are missing or rejected, so Twilio policy and a few Bicep settings are shaped around that.

| Limitation | What we do |
|------------|------------|
| `send-request` cannot contain `set-body` (`expected proxy`) | Set the body on the inbound request, then `<send-request mode="copy">` (email queue; SMS table insert / MERGE). |
| No `buffer-request-content` | Read the body with `As<…>(preserveContent: true)` and reuse variables (`originalPayload`, `messageId`). |
| Default `forward-request` would return the backend status (often 200) | After Service Bus accepts the message, `<return-response>` **201** with `{"status":"queued","id":"…"}`. |
| Consumption cannot join a VNet | Vault stays public so APIM can resolve Key Vault named values. Not a company default. |
| Consumption rejects some TLS `customProperties` (SSL3 / 3DES even when `False`) | `apiManagement.bicep` only disables TLS 1.0/1.1 on this SKU. |

Related (Linux **Consumption Function** Y1, not APIM): `az functionapp deploy` (OneDeploy) is unavailable — zip uses `config-zip`. The scale controller needs Service Bus Data Receiver on the **namespace**, not only the queue.

Developer / Standard / VNet APIM would not need the `mode=copy` body trick. Keep the comments in [`twilio-email-api.xml`](library/policies/twilio-email-api.xml) if you change SKU.
