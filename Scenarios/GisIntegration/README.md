# GisIntegration

Demo Azure resources for GIS API integration: **Key Vault** for secrets and **API Management** as the front door.

Treat this as **practice for a secure company**. Copy the identity and secret patterns; do not copy the cheap public-network shortcuts into production.

## What this creates

| Resource | SKU | Purpose |
|----------|-----|---------|
| Key Vault | Standard | Store of record for secrets (RBAC, not access policies) |
| API Management | **Consumption** | Cheap demo gateway — no dedicated unit, billed per call |
| APIM product `gis` | — | All GIS APIs. One **product**; one **subscription** per caller (`gis-demo`, `allowTracing: false`) |
| APIM API `tdp-gis` | OpenAPI import | Tdp GIS query GETs. Spec: [`modules/apis/tdp-gis.json`](modules/apis/tdp-gis.json). Backend URL: `gisApiBackendUrl` in `main.bicepparam`. |

Bicep never writes secret *values*. After deploy, put secrets in Key Vault out of band. Copy the `gis-demo` subscription key from the portal (APIM → Subscriptions), not from deployment outputs.

## Product vs subscription

These are not alternatives.

| | Product `gis` | Subscription |
|--|---------------|--------------|
| What it is | A **bundle** of GIS APIs | A **caller’s key** for that bundle |
| How many | **One** for the GIS topic | **One per caller** (app, partner, team) |
| When you add a new GIS API | Add `modules/apis/<name>.json` + `<name>.bicep`, call it from `main.bicep`, attach to product `gis` | Existing keys keep working; no new product |

Do not create a product per POST. Do not use the built-in all-access subscription for real callers. At work, put each key in Key Vault after create; never commit it. APIM `validate-jwt` checks the Entra Bearer token at the gateway; the product key is still the caller identity.

## Access (Key Vault RBAC)

[`modules/keyVaultAssignRole.bicep`](modules/keyVaultAssignRole.bicep) grants a role on the vault. Call it once per principal.

| Who | `principalType` | Role | How |
|-----|-----------------|------|-----|
| APIM (and later App Service, Functions, …) | `ServicePrincipal` | **Key Vault Secrets User** (get/list) | Each workload’s **managed identity** |
| Humans | `Group` only | **Key Vault Secrets Officer** | Entra security group via `keyVaultOfficerGroupObjectId` |

Do not assign a **user** object ID. Add people to the group in Entra. Leave `keyVaultOfficerGroupObjectId` empty to skip the human grant.

A later App Service would enable its own identity and get another Secrets User assignment — it does not share APIM’s identity.

## Configuration

Region and resource group are **not** in `main.bicepparam`. The workflow creates the group from GitHub Environment **variables**; resources use `resourceGroup().location`.

On Environment **`demo`**, set variables (not secrets):

| Variable | Example |
|----------|---------|
| `AZURE_CLIENT_ID` | Entra app (client) ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `APIM_PUBLISHER_EMAIL` | APIM contact email |
| `AZURE_RESOURCE_GROUP` | `rg-integration-demo` |
| `AZURE_LOCATION` | `australiaeast` |
| `GIS_API_AUDIENCE` | JWT `aud` of the GIS Entra app (Application ID URI or client ID) |

`publisherEmail` in `main.bicepparam` is a placeholder; Actions overrides it from `APIM_PUBLISHER_EMAIL`. `gisApiBackendUrl` is set in `main.bicepparam` next to the OpenAPI spec (no GitHub variable). Tenant and audience for `validate-jwt` come from `AZURE_TENANT_ID` and `GIS_API_AUDIENCE` (named values `entra-tenant-id`, `gis-api-audience`).

After apply, call through APIM (subscription `gis-demo` plus the two backend tokens):

```text
GET {gateway}/gis/api/gis-workspace-entities/{workspaceId}
Ocp-Apim-Subscription-Key: <gis-demo key>
Authorization: Bearer <Entra token>
X-Access-Token: <workspace token>
```

When the Tdp GIS spec changes, replace [`modules/apis/tdp-gis.json`](modules/apis/tdp-gis.json) and redeploy. Do not point Bicep at the live `/swagger/v1/swagger.json` URL.

### Adding another GIS API

1. Add `modules/apis/<name>.json` (OpenAPI) and `modules/apis/<name>.bicep` (copy [`tdp-gis.bicep`](modules/apis/tdp-gis.bicep); point `loadTextContent` at that JSON; set `apiName` / `apiPath` / display name).
2. Add the backend URL in `main.bicepparam` and a `param` on `main.bicep`; pass it into the new module call.
3. In `main.bicep`, add one `module` call like `tdpGisApi` and pass APIM name, product output, and that URL.
4. Do not edit `apimOpenApi.bicep`.

## Security

- `@secure()` for any secret parameter; no secret values in `.bicepparam`
- APIM named values that hold credentials: `secret: true` + Key Vault `secretIdentifier`
- `tdp-gis` inbound: `validate-jwt` (Entra) using named values; `allowTracing: false` on subscriptions
- Gateway/backend TLS 1.0 and 1.1 disabled. SSL 3.0 / 3DES custom properties are set only on Developer SKU (Consumption rejects them; those protocols are already off). `minApiVersion` blocks old control-plane APIs
- Gateway does not request client TLS certificates (ordinary HTTPS, not mTLS)
- Global policy (`modules/policies/global-policy.xml`) strips `Server` / `X-Powered-By` and does not echo `LastError` to clients
- Key Vault: RBAC only, soft-delete 90 days, deployment/template/disk encryption flags off
- `bicepconfig.json` treats secret-in-output / insecure secret params as errors

## Deploy

Full account setup: **[Connect GitHub Actions to Azure (OIDC)](../../docs/github-azure-oidc.md)** (Entra app, subscription RBAC, [`New-GitHubFederatedCredential.ps1`](../../scripts/New-GitHubFederatedCredential.ps1), Environment `demo`, variables).

Workflow: [`.github/workflows/gisintegration-deploy.yml`](../../.github/workflows/gisintegration-deploy.yml).

- Manual only: **Actions → Deploy GisIntegration → Run workflow**
- Order: **lint → what-if (plan) → apply**. Plan always runs; there is no skip. Apply starts only after plan succeeds.
- Company control: on Environment **`demo`**, add **Required reviewers**. GitHub then waits before **What-if** and again before **Apply**, so you can read the plan log and approve (or reject) the apply. Without reviewers, Apply starts as soon as plan succeeds.

## Demo-only (do not copy to work as-is)

- Consumption APIM: cheapest (pay-per-call; first ~1M operations/month typically included), no developer portal, can cold-start. Switch with `apiManagementSku = 'Developer'` in `main.bicepparam` (fixed monthly cost).
- Vault **public** network access: Consumption APIM cannot join a VNet. At work use a VNet-capable SKU and a private vault.
- Soft-delete 90 days, **no** purge protection, **no** delete lock: so the demo can be torn down. Names stay reserved until soft-delete ends unless you purge. At work: purge protection and locks on shared resources.
- Officer group is optional here; at work it is required.

Optional: `enableDeleteLock = true` or set `keyVaultOfficerGroupObjectId` (`az ad group show --group '<name>' --query id -o tsv`).

When `keyVaultName` / `apiManagementName` are empty, names are generated from the resource group id (both must be globally unique).
