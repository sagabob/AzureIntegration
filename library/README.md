# Library

| Path | What |
|------|------|
| [`LandingZones/`](LandingZones/README.md) | Shared platform (`main.bicep`) |
| [`modules/`](modules/) | Generic Bicep used by the landing zone and by every scenario |
| [`policies/`](policies/) | Global APIM XML, plus the Twilio SMS spec/policy (loaded by the scenario catalog) |

No environment URLs and no swagger filenames in `modules/`.

| Module | Use |
|--------|-----|
| `keyVault.bicep` | Vault (RBAC, no secret values) |
| `keyVaultAssignRole.bicep` | Secrets User or Officer |
| `apiManagement.bicep` | Shared gateway + global policy |
| `apimProduct.bicep` | One product + optional `*-demo` subscription |
| `apimOpenApi.bicep` | Import OpenAPI; caller passes JSON text |
| `apimNamedValue.bicep` | One non-secret named value |
| `serviceBus.bicep` | Shared namespace; optional Data Sender |
| `serviceBusQueue.bicep` | One queue; optional Data Receiver |
| `storageAccount.bicep` | Function host storage (no key outputs) |
| `functionApp.bicep` | Linux Consumption Function + system-assigned identity |

`loadTextContent` of a named spec stays in the **scenario** catalog file (`Scenarios/.../apis/<name>.bicep`).
