# AzureIntegration

Shared **landing zone** (one APIM, one Key Vault, optional Service Bus) plus **scenarios** that only add products and APIs.

**GitHub → Azure:** [Connect GitHub Actions to Azure (OIDC)](docs/github-azure-oidc.md)

| Piece | What it deploys |
|-------|-----------------|
| [Landing zone](library/LandingZones/README.md) | Key Vault, Consumption APIM, Service Bus namespace, `entra-tenant-id` |
| [Library](library/README.md) | Shared Bicep modules (no scenario names) |
| [GisIntegration](Scenarios/GisIntegration/README.md) | Product `gis` + Tdp GIS OpenAPI on the shared APIM |

Deploy **LandingZone** first. Copy `apiManagementNameOut` to Environment variable `APIM_NAME`, then run a scenario workflow.
