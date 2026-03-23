# set-env.ps1
# ─────────────────────────────────────────────────────────────
# Fetches ALL credentials from Azure Key Vault using your SPN.
# No az login required — uses PowerShell REST calls only.
#
# HOW TO USE:
#   1. Fill in $clientSecret below (last hardcoded value ever)
#   2. Open PowerShell terminal in VS Code
#   3. Run: .\set-env.ps1
#   4. Then run: terraform plan / terraform apply
#
# This file is gitignored — it never goes to source control.
# ─────────────────────────────────────────────────────────────

# ── FILL THIS IN ──────────────────────────────────────────────
$kvName       = "tfsecretdev"
$tenantId     = "36801539-1844-45a2-b9ba-a999548dafde"   # paste your tenant ID here
$clientId     = "a34cc706-3aa5-43b7-9e53-94dfbdc84f62"   # paste your SPN app ID here
$clientSecret = "2pn8Q~iXkL.KnmJWkx.eLYDMZjTQyLC91_IWjc5k"   # paste your SPN secret here
# ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Step 1/3 — Authenticating to Azure AD..." -ForegroundColor Cyan

# Get OAuth token from Azure AD using SPN credentials
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$body = @{
  grant_type    = "client_credentials"
  client_id     = $clientId
  client_secret = $clientSecret
  resource      = "https://vault.azure.net"
}

try {
  $token = (Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body).access_token
  Write-Host "         Got access token." -ForegroundColor Green
} catch {
  Write-Host "FAILED: Could not get token. Check clientId, clientSecret, tenantId." -ForegroundColor Red
  Write-Host $_.Exception.Message
  exit 1
}

# ─── Helper: fetch one secret by name ────────────────────────
function Get-KVSecret($secretName) {
  $uri     = "https://$kvName.vault.azure.net/secrets/$secretName/?api-version=7.4"
  $headers = @{ Authorization = "Bearer $token" }
  try {
    return (Invoke-RestMethod -Uri $uri -Headers $headers).value
  } catch {
    Write-Host "FAILED: Could not read secret '$secretName' from Key Vault." -ForegroundColor Red
    Write-Host "Check the secret exists and SPN has 'Get' access policy on the vault." -ForegroundColor Yellow
    Write-Host $_.Exception.Message
    exit 1
  }
}

Write-Host "Step 2/3 — Fetching secrets from Key Vault: $kvName..." -ForegroundColor Cyan

# Load SPN credentials into environment variables for Terraform
$env:ARM_CLIENT_ID       = Get-KVSecret "spn-client-id"
$env:ARM_CLIENT_SECRET   = Get-KVSecret "spn-client-secret"
$env:ARM_TENANT_ID       = Get-KVSecret "spn-tenant-id"
$env:ARM_SUBSCRIPTION_ID = Get-KVSecret "spn-subscription-id"

Write-Host "         Loaded: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID" -ForegroundColor Green

Write-Host "Step 3/3 — Verifying environment variables are set..." -ForegroundColor Cyan

# Quick sanity check — confirm vars are not empty
$missing = @()
if (-not $env:ARM_CLIENT_ID)       { $missing += "ARM_CLIENT_ID" }
if (-not $env:ARM_CLIENT_SECRET)   { $missing += "ARM_CLIENT_SECRET" }
if (-not $env:ARM_TENANT_ID)       { $missing += "ARM_TENANT_ID" }
if (-not $env:ARM_SUBSCRIPTION_ID) { $missing += "ARM_SUBSCRIPTION_ID" }

if ($missing.Count -gt 0) {
  Write-Host "FAILED: These variables are empty: $($missing -join ', ')" -ForegroundColor Red
  exit 1
}

Write-Host "         All variables verified." -ForegroundColor Green
Write-Host ""
Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " Ready! Run: terraform plan" -ForegroundColor Yellow
Write-Host " Credentials exist only in this PowerShell session." -ForegroundColor DarkGray
Write-Host " Nothing was written to disk." -ForegroundColor DarkGray
Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
