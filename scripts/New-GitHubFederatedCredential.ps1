#Requires -Version 5.1
<#
.SYNOPSIS
  One-time OIDC trust: add a federated credential on an Entra app for GitHub Actions.

.DESCRIPTION
  Lets the GitHub Environment (default: demo) request tokens as this app. No Azure
  client secret is created.

  This script does not create the Entra app, GitHub Environment, subscription RBAC,
  resource group, or any Bicep resources. Run it once on a machine with Azure CLI,
  as someone who can edit the app registration.

  Writes a JSON file then calls az ad app federated-credential create. Do not pass
  ConvertTo-Json inline to --parameters on Windows PowerShell.

  After success, create Environment "demo" (if missing) and set Actions variables:
  AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, APIM_PUBLISHER_EMAIL,
  AZURE_RESOURCE_GROUP, AZURE_LOCATION.

.PARAMETER AppId
  Application (client) ID or object ID of the existing Entra app.

.PARAMETER Owner
  GitHub user or org. Default: sagabob.

.PARAMETER Repo
  GitHub repository name. Default: AzureIntegration.

.PARAMETER EnvironmentName
  GitHub Environment name. Must match the workflow environment: value. Default: demo.

.PARAMETER Name
  Display name of the federated identity in Entra (not a secret).

.PARAMETER Subject
  Full OIDC sub if you already have it. Otherwise the script looks up owner/repo IDs.

.PARAMETER NameOnlySubject
  Use repo:owner/repo:environment:name (older repos that did not opt in to immutable IDs).

.EXAMPLE
  .\New-GitHubFederatedCredential.ps1 -AppId '14253335-d707-4dbe-bc7c-db8bdc03c624'

.EXAMPLE
  .\New-GitHubFederatedCredential.ps1 -AppId '<app-id>' -Owner sagabob -Repo AzureIntegration

.LINK
  docs/github-azure-oidc.md
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string] $AppId,

  [string] $Owner = 'sagabob',
  [string] $Repo = 'AzureIntegration',
  [string] $EnvironmentName = 'demo',

  # Entra display name of the federated identity (not a secret). Avoid *Credential* in the
  # parameter name — PSScriptAnalyzer treats that as a password.
  [string] $Name = 'github-demo-environment',
  [string] $Subject,
  [switch] $NameOnlySubject
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
  param([Parameter(Mandatory)] [string[]] $AzArgs)
  & az @AzArgs
  if ($LASTEXITCODE -ne 0) {
    throw "az $($AzArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw 'Azure CLI (az) is not on PATH.'
}

az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Not logged in. Opening az login...'
  Invoke-Az @('login')
}

if (-not $Subject) {
  if ($NameOnlySubject) {
    $Subject = "repo:${Owner}/${Repo}:environment:${EnvironmentName}"
  }
  else {
    $uri = "https://api.github.com/repos/$Owner/$Repo"
    Write-Host "Looking up GitHub IDs: $uri"
    try {
      $repoInfo = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'AzureIntegration-oidc-setup' }
    }
    catch {
      throw "Could not read $uri. Pass -Subject or check owner/repo. $_"
    }
    $Subject = "repo:$($repoInfo.owner.login)@$($repoInfo.owner.id)/$($repoInfo.name)@$($repoInfo.id):environment:${EnvironmentName}"
  }
}

$resolvedAppId = (az ad app show --id $AppId --query id -o tsv 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedAppId)) {
  throw "Could not find Entra app '$AppId'. Use the application (client) ID or object ID."
}

Write-Host "App object ID: $resolvedAppId"
Write-Host "Subject:       $Subject"

$existing = az ad app federated-credential list --id $resolvedAppId -o json 2>$null
if ($LASTEXITCODE -eq 0 -and $existing) {
  $match = $existing | ConvertFrom-Json | Where-Object { $_.name -eq $Name -or $_.subject -eq $Subject }
  if ($match) {
    Write-Host "Federated credential already exists (name or subject matches). Skipping create."
    $match | Format-List name, subject, issuer
    return
  }
}

$credFile = Join-Path ([System.IO.Path]::GetTempPath()) "github-fic-$Name.json"
$body = @{
  name        = $Name
  issuer      = 'https://token.actions.githubusercontent.com'
  subject     = $Subject
  description = "GitHub Actions environment $EnvironmentName"
  audiences   = @('api://AzureADTokenExchange')
}
$body | ConvertTo-Json | Set-Content -Path $credFile -Encoding utf8

try {
  Write-Host "Creating federated credential from $credFile"
  Invoke-Az @(
    'ad', 'app', 'federated-credential', 'create',
    '--id', $resolvedAppId,
    '--parameters', $credFile
  )
}
finally {
  Remove-Item -LiteralPath $credFile -Force -ErrorAction SilentlyContinue
}

Write-Host 'Done. GitHub Environment name must be exactly:' $EnvironmentName
Write-Host 'This script only added OIDC trust. Still required: Environment, six Actions variables, subscription RBAC.'
Write-Host 'Variables: AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID APIM_PUBLISHER_EMAIL AZURE_RESOURCE_GROUP AZURE_LOCATION'
