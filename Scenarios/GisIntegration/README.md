# GisIntegration

GIS APIs on the **shared landing-zone APIM**. This scenario does not create Key Vault or API Management.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

## What this creates

| Resource | Purpose |
|----------|---------|
| APIM product `gis` | All GIS APIs. One **product**; one **subscription** per caller (`gis-demo`, `allowTracing: false`) |
| Named value `gis-api-audience` | JWT `aud` for `validate-jwt` |
| APIM API `tdp-gis` | Tdp GIS query GETs. Spec: [`apis/tdp-gis.json`](apis/tdp-gis.json). Backend URL: `gisApiBackendUrl` in `main.bicepparam`. |

Shared `entra-tenant-id` comes from the landing zone. Copy the `gis-demo` subscription key from the portal (APIM → Subscriptions), not from deployment outputs.

## Product vs subscription

| | Product `gis` | Subscription |
|--|---------------|--------------|
| What it is | A **bundle** of GIS APIs | A **caller’s key** for that bundle |
| How many | **One** for the GIS topic | **One per caller** |
| When you add a new GIS API | Add `apis/<name>.json` + `<name>.bicep` + policy, call it from `main.bicep` | Existing keys keep working |

Do not create a product per POST. Do not edit `library/modules/apimOpenApi.bicep`.

## Configuration

Run **[Deploy LandingZone](../../library/LandingZones/README.md)** first. Then on Environment **`demo`**:

| Variable | Example |
|----------|---------|
| `APIM_NAME` | From landing zone output `apiManagementNameOut` |
| `GIS_API_AUDIENCE` | JWT `aud` of the GIS Entra app (`api://…`) |
| Plus the shared OIDC vars | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` |

`apimName` / `gisApiAudience` in `main.bicepparam` are placeholders; Actions overrides them.

After apply:

```text
GET {gateway}/gis/api/gis-workspace-entities/{workspaceId}
Ocp-Apim-Subscription-Key: <gis-demo key>
Authorization: Bearer <Entra token with role TdpGisApi.Access>
X-Access-Token: <workspace token>
```

### Adding another GIS API

1. Add `apis/<name>.json`, `apis/<name>.bicep` (copy [`tdp-gis.bicep`](apis/tdp-gis.bicep)), and `policies/<name>-api.xml`.
2. Add a backend URL param on `main.bicep` / `main.bicepparam`.
3. Add one `module` call in `main.bicep`. Pass the landing-zone `apimName` and product output.

## Deploy

Workflow: [`.github/workflows/gisintegration-deploy.yml`](../../.github/workflows/gisintegration-deploy.yml).

- **Actions → Deploy GisIntegration → Run workflow**
- **lint → what-if → apply**. No skip-plan.
- Required reviewers on Environment **`demo`** (company control).
