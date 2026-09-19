# Connect GitHub Actions to Azure (OIDC)

## Ready to run (checklist)

You can start the workflow when all of these are true. Skip a step if you already did it.

1. **Entra app** exists (no client secret). You have **client ID**, **tenant ID**, **subscription ID**.
2. **Federated credential** exists (you already ran `New-GitHubFederatedCredential.ps1`).
3. **Subscription roles** on that app:

```powershell
$APP_ID = '<application-client-id>'   # e.g. 14253335-d707-4dbe-bc7c-db8bdc03c624
$sub = (az account show --query id -o tsv)
az role assignment create --assignee $APP_ID --role Contributor --scope "/subscriptions/$sub"
az role assignment create --assignee $APP_ID --role 'User Access Administrator' --scope "/subscriptions/$sub"
```

4. **Push this repo to GitHub** (`main`) so the workflow file is on the remote.
5. GitHub repo **Settings → Environments → New environment** → name it exactly **`demo`**. Add **Required reviewers** so Apply does not start until someone reads the what-if.
6. On that **`demo`** environment, set these as **variables** (no hardcoded defaults in the workflow):

| Name | Typical value |
|------|----------------|
| `AZURE_CLIENT_ID` | App **application (client) ID** |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |
| `APIM_PUBLISHER_EMAIL` | Your email (APIM contact only, not login) |
| `AZURE_RESOURCE_GROUP` | `rg-integration-demo` |
| `AZURE_LOCATION` | e.g. `australiaeast` |

7. **Actions → Deploy GisIntegration → Run workflow**.

Do **not** set `AZURE_CLIENT_SECRET` or `KEYVAULT_OFFICER_OBJECT_ID`. The Key Vault officers **group** is optional (`keyVaultOfficerGroupObjectId` in Bicep) and is not required to start the workflow.

---

This repo deploys Azure resources from GitHub Actions **without a client secret**. GitHub proves who it is with a short-lived OpenID Connect (OIDC) token. Microsoft Entra exchanges that token for an Azure access token for an **app registration** (service principal).

GisIntegration workflow: [`.github/workflows/gisintegration-deploy.yml`](../.github/workflows/gisintegration-deploy.yml).

## How the handshake works

```text
GitHub Actions job (environment: demo)
        │  id-token: write
        ▼
GitHub OIDC provider
  iss: https://token.actions.githubusercontent.com
  aud: api://AzureADTokenExchange
  sub: repo:<org>@<owner-id>/<repo>@<repo-id>:environment:demo
        │
        ▼
azure/login
        │
        ▼
Microsoft Entra ID  →  matches federated credential on the app
        │
        ▼
Azure Resource Manager  →  az / Bicep deploy as that app
```

Nothing in GitHub stores an Azure password. If the **subject** (`sub`) on the token does not match the federated credential exactly, login fails with `AADSTS70021`.

The workflow runs only when you start it: **Actions → Deploy GisIntegration → Run workflow**. Pushes and pull requests do not deploy.

## What you create (once)

| Piece | Where | Purpose |
|-------|--------|---------|
| App registration + service principal | Microsoft Entra ID | The Azure identity GitHub acts as |
| Federated credential | On that app | Trust GitHub OIDC for this repo + `demo` environment |
| Role assignments | Subscription | Contributor + User Access Administrator |
| GitHub Environment `demo` | Repo Settings → Environments | Matches the workflow `environment: demo` |
| Actions variables | On `demo` (or the repo) | Client ID, tenant, subscription, publisher email |

Do **not** create an Azure client secret. Do **not** add `AZURE_CLIENT_SECRET` in GitHub.

Use a **demo/dev subscription**, not production.

## 1. Create the Entra app

Portal: **Microsoft Entra ID → App registrations → New registration**.

- Name: `github-azureintegration-gisint` (any unique name)
- Supported account types: **Single tenant**
- Redirect URI: none

CLI:

```powershell
az login
az account show --query '{name:name, id:id, tenantId:tenantId}' -o json

$APP_ID = az ad app create --display-name 'github-azureintegration-gisint' --query appId -o tsv
az ad sp create --id $APP_ID
```

Copy these three values:

| Value | Where |
|-------|--------|
| Application (client) ID | App registration **Overview** (`$APP_ID`) |
| Directory (tenant) ID | App registration **Overview** |
| Subscription ID | `az account show` → `id` |

## 2. Grant subscription RBAC

Custom **role definitions** are created at subscription (or management group) scope, not on a resource group. The GitHub app needs subscription-level authorization so later pipelines can define custom roles and assign them.

```powershell
$sub = '<subscription-id>'
az group create --name rg-integration-demo --location australiaeast

az role assignment create --assignee $APP_ID --role Contributor `
  --scope "/subscriptions/$sub"

az role assignment create --assignee $APP_ID --role 'User Access Administrator' `
  --scope "/subscriptions/$sub"
```

| Role | Why |
|------|-----|
| **Contributor** | Create resource groups, Key Vault, APIM, and later scenario resources |
| **User Access Administrator** | Assign RBAC (for example APIM → Key Vault Secrets User) and **create/update custom roles** |

**Owner** is not required. These two roles are enough.

If you previously assigned the same roles only on `rg-integration-demo`, add them again at `/subscriptions/<id>`.

## 3. Federated credential (trust GitHub)

The credential **subject** must match the OIDC `sub` claim from the deploy job.

This workflow sets `environment: demo`, so the subject **ends with** `:environment:demo`. Do not use `:ref:refs/heads/main` for this job.

### Subject format

Repositories created **after 15 July 2026** (and older repos that opted in) use **immutable** owner and repo IDs:

```text
repo:<org>@<owner-id>/<repo>@<repo-id>:environment:demo
```

Example: `repo:my-org@123456/AzureIntegration@789012:environment:demo`

Older repos that have not opted in still use:

```text
repo:<org>/<repo>:environment:demo
```

The script looks those IDs up for you (see below). Manual lookup if needed:

```powershell
gh api repos/<org>/<repo> --jq '{owner:.owner.login, owner_id:.owner.id, repo:.name, repo_id:.id}'
```

### Create the credential (`New-GitHubFederatedCredential.ps1`)

Script: [`scripts/New-GitHubFederatedCredential.ps1`](../scripts/New-GitHubFederatedCredential.ps1). Comment-based help: `Get-Help .\scripts\New-GitHubFederatedCredential.ps1 -Full`.

This is **one-time OIDC setup**, not a deploy. You run it locally with Azure CLI, as someone who can edit the Entra app.

| It does | It does not |
|---------|-------------|
| Add a federated credential on an **existing** app | Create the Entra app |
| Trust GitHub OIDC for `environment:demo` (or `-EnvironmentName`) | Create the GitHub Environment or Actions variables |
| Look up immutable `owner@id/repo@id` from the GitHub API | Grant subscription RBAC |
| Skip if the same name or subject already exists | Create a resource group, Key Vault, or APIM |
| | Create `AZURE_CLIENT_SECRET` |

On Windows PowerShell, `az ad app federated-credential create --parameters` must be a **JSON file**. Passing `(@{ ... } | ConvertTo-Json)` inline fails (multiline JSON is treated as a path or the quotes break). The script writes a temp file, calls `az`, then deletes the file.

It also:

- Logs in with `az login` if needed
- Resolves the app **object ID** from the application (client) ID
- Builds the immutable subject from the GitHub API unless you pass `-Subject` or `-NameOnlySubject`

From the repo root:

```powershell
.\scripts\New-GitHubFederatedCredential.ps1 -AppId '<application-client-id>'
```

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `-AppId` | (required) | Application (client) ID or object ID |
| `-Owner` | `sagabob` | GitHub user or org |
| `-Repo` | `AzureIntegration` | Repository name |
| `-EnvironmentName` | `demo` | Must match the GitHub Environment and the workflow `environment:` |
| `-Name` | `github-demo-environment` | Entra **display name** of the federated identity (not a secret). Named `-Name` so PSScriptAnalyzer does not treat it as a password (`*Credential*` in a parameter name triggers that rule). |
| `-Subject` | (built automatically) | Override the OIDC `sub` if you already know it |
| `-NameOnlySubject` | off | Use `repo:owner/repo:environment:demo` (older repos that did not opt in to immutable subjects) |

Examples:

```powershell
# This repo, immutable subject
.\scripts\New-GitHubFederatedCredential.ps1 -AppId '<application-client-id>'

# Another repo
.\scripts\New-GitHubFederatedCredential.ps1 -AppId '<application-client-id>' -Owner my-org -Repo AzureIntegration

# Older name-only subject
.\scripts\New-GitHubFederatedCredential.ps1 -AppId '<application-client-id>' -NameOnlySubject
```

Confirm:

```powershell
az ad app federated-credential list --id '<application-client-id>' -o table
```

| Field written by the script | Value |
|-----------------------------|--------|
| Issuer | `https://token.actions.githubusercontent.com` |
| Audience | `api://AzureADTokenExchange` |
| Subject | Exact `sub` for this repo + `demo` (see above) |

Portal alternative: App registration → **Certificates & secrets → Federated credentials → Add credential**. Prefer **Other issuer** and paste issuer, subject, and audience. The GitHub-shaped wizard often writes the name-only subject, which fails on new repos.

## 4. GitHub Environment and variables

1. Repo **Settings → Environments → New environment**.
2. Name it **`demo`** (must match `environment: demo` in the workflow).
3. **Required reviewers** (company path): add yourself or a teammate. The workflow uses this environment for **What-if (plan)** and **Apply**, so each of those jobs waits for approval. Read the what-if log, then approve Apply — or reject it. Also restrict deployments to branch `main` if you use branch protection.
4. On that environment (or **Settings → Secrets and variables → Actions → Variables**), add:

| Variable | Required | Purpose |
|----------|----------|---------|
| `AZURE_CLIENT_ID` | Yes | App registration client ID |
| `AZURE_TENANT_ID` | Yes | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Yes | Target subscription |
| `APIM_PUBLISHER_EMAIL` | Yes | APIM publisher email |
| `AZURE_RESOURCE_GROUP` | Yes | Resource group to create/deploy into |
| `AZURE_LOCATION` | Yes | Azure region for the resource group |

These are identifiers, not passwords. Do not add a user object ID for Key Vault. Human vault access is an **Entra group** in Bicep (`keyVaultOfficerGroupObjectId`).

The workflow needs:

```yaml
permissions:
  id-token: write   # request the OIDC token
  contents: read    # checkout the repo
```

That is already set on the **What-if (plan)** and **Apply** jobs. `id-token: write` does not let the job change GitHub; it only allows requesting the OIDC token.

## 5. Run and verify

**Actions → Deploy GisIntegration → Run workflow**.

Expected path: **lint → what-if (plan) → apply**. Plan always runs; there is no skip. Missing Environment variables fail at the start of plan (before apply). If Environment **`demo`** has required reviewers, approve plan, read the what-if, then approve apply. Consumption APIM often takes several minutes.

Confirm Azure login as the app:

- Workflow log step **Log in to Azure (OIDC)** succeeds.
- Deployment identity is the app display name, not your user.

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `AADSTS70021` / no matching federated identity | Subject mismatch: wrong org/repo, missing `@owner-id/@repo-id`, or `:ref:refs/heads/main` instead of `:environment:demo` |
| `AADSTS700016` | Wrong `AZURE_CLIENT_ID` or tenant |
| Authorization failed creating resources | App is missing **Contributor** on the subscription |
| Authorization failed creating a role assignment or custom role | App is missing **User Access Administrator** on the **subscription** (RG-only is not enough for custom roles) |
| Job skipped / waiting | GitHub Environment `demo` has required reviewers, or the environment name does not match |
| Workflow never starts | It is manual only — use **Actions → Deploy GisIntegration → Run workflow** |

## Related

- [Federated credential script](../scripts/New-GitHubFederatedCredential.ps1)
- [GisIntegration scenario](../Scenarios/GisIntegration/README.md)
- [Deploy workflow](../.github/workflows/gisintegration-deploy.yml)
