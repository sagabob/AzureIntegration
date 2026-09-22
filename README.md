# AzureIntegration

Shared **landing zone** (one APIM, one Key Vault, optional Service Bus) plus **scenarios** that only add products and APIs.

**GitHub → Azure:** [Connect GitHub Actions to Azure (OIDC)](docs/github-azure-oidc.md)

| Piece | What it deploys |
|-------|-----------------|
| [Landing zone](library/LandingZones/README.md) | Key Vault, Consumption APIM, Service Bus namespace, `entra-tenant-id` |
| [Library](library/README.md) | Shared Bicep modules (no scenario names) |
| [GisIntegration](Scenarios/GisIntegration/README.md) | Product `gis` + Tdp GIS OpenAPI on the shared APIM |
| [TwilioIntegration](Scenarios/TwilioIntegration/README.md) | Product `twilio` + queue + Function that sends SMS |

Deploy **LandingZone** first. Copy `apiManagementNameOut`, `serviceBusNamespaceNameOut`, and `keyVaultNameOut` to Environment variables `APIM_NAME`, `SERVICE_BUS_NAMESPACE`, and `KEY_VAULT_NAME`, then run a scenario workflow.
