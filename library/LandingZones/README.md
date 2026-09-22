# Landing zone

Shared platform for every scenario: **Key Vault**, **API Management**, optional **Service Bus** namespace, and the Entra tenant named value.

Lives under `library/LandingZones`. Generic modules are siblings in `library/modules`.

Scenarios do **not** create another APIM. They take `APIM_NAME` (and later the Service Bus namespace) and add a product, APIs, or queues.

## What this creates

| Resource | Purpose |
|----------|---------|
| Key Vault | Store of record for secrets (RBAC). APIM identity is Secrets User. |
| API Management (Consumption) | One gateway. Global policy only. |
| Named value `entra-tenant-id` | Shared by `validate-jwt` in scenarios |
| Service Bus namespace | Queues are added by scenarios. APIM is Data Sender on the namespace. |

Default names use `namePrefix = gisint` so an existing demo APIM/vault in the same resource group is **updated**, not replaced.

## Deploy first

Workflow: [`.github/workflows/landingzone-deploy.yml`](../../.github/workflows/landingzone-deploy.yml).

1. **Actions → Deploy LandingZone → Run workflow**
2. From apply outputs, set Environment **`demo`** variables (not secrets):

| Variable | Output |
|----------|--------|
| `APIM_NAME` | `apiManagementNameOut` |
| `SERVICE_BUS_NAMESPACE` | `serviceBusNamespaceNameOut` |

Then run a scenario workflow (for example GisIntegration).

Officer group: set `keyVaultOfficerGroupObjectId` in `main.bicepparam` or leave empty. Do not put a user object ID in GitHub.

## Demo-only

Public vault and Consumption APIM (no VNet). Purge protection and delete lock off so the demo can be deleted. Do not copy that to production.
