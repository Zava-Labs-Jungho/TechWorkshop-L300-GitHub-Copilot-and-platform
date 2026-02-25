<#
.SYNOPSIS
    Assigns all required Azure RBAC roles for the GitHub Actions service principal
    used in the build-deploy.yml workflow.

.DESCRIPTION
    The CI/CD workflow performs three operations that require specific RBAC roles:
      1. az acr build   — Needs Contributor on the ACR (schedules build tasks + pushes images)
      2. az webapp config container set — Needs Contributor on the App Service
      3. az webapp restart              — Needs Contributor on the App Service

    This script auto-discovers the subscription, resource group, ACR, and App Service
    from the currently logged-in Azure CLI session. It finds the GitHub Actions service
    principal by searching for app registrations with federated credentials that reference
    the current repository.

.PARAMETER ResourceGroupName
    (Optional) Override the auto-discovered resource group name. If omitted, the script
    finds the resource group containing the ACR.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"

# ============================================================================
# 1. Discover current subscription from the logged-in Azure CLI session
# ============================================================================
Write-Host "Discovering parameters from current Azure CLI session..." -ForegroundColor Cyan
Write-Host ""

$SubscriptionId = az account show --query "id" -o tsv
$SubscriptionName = az account show --query "name" -o tsv
if (-not $SubscriptionId) {
    Write-Error "Not logged in to Azure CLI. Run 'az login' first."
    exit 1
}
Write-Host "  Subscription: $SubscriptionName ($SubscriptionId)" -ForegroundColor Gray

# ============================================================================
# 2. Discover the ACR in this subscription
# ============================================================================
$acrJson = az acr list --query "[0].{name:name, resourceGroup:resourceGroup, id:id}" -o json | ConvertFrom-Json
if (-not $acrJson) {
    Write-Error "No Azure Container Registry found in subscription '$SubscriptionName'."
    exit 1
}
$AcrName = $acrJson.name
if (-not $ResourceGroupName) {
    $ResourceGroupName = $acrJson.resourceGroup
}
Write-Host "  ACR: $AcrName (Resource Group: $ResourceGroupName)" -ForegroundColor Gray

# ============================================================================
# 3. Discover the App Service in the same resource group
# ============================================================================
$AppServiceName = az webapp list --resource-group $ResourceGroupName --query "[0].name" -o tsv
if (-not $AppServiceName) {
    Write-Error "No App Service found in resource group '$ResourceGroupName'."
    exit 1
}
Write-Host "  App Service: $AppServiceName" -ForegroundColor Gray

# ============================================================================
# 4. Find the GitHub Actions service principal (app registration with
#    federated credentials referencing this repository)
# ============================================================================
Write-Host ""
Write-Host "Searching for GitHub Actions service principal..." -ForegroundColor Cyan

# Get the remote origin URL to determine the GitHub org/repo
$repoUrl = git remote get-url origin 2>$null
if ($repoUrl -match "github\.com[:/](.+?)(?:\.git)?$") {
    $repoFullName = $Matches[1]
}
else {
    Write-Error "Could not determine the GitHub repository from git remote 'origin'."
    exit 1
}
Write-Host "  Repository: $repoFullName" -ForegroundColor Gray

# List all app registrations owned by the current user and check for federated
# credentials that reference this repository
$apps = az ad app list --show-mine --query "[].{appId:appId, displayName:displayName}" -o json | ConvertFrom-Json
$AppId = $null

foreach ($app in $apps) {
    $fedCreds = az ad app federated-credential list --id $app.appId --query "[].subject" -o tsv 2>$null
    if ($fedCreds -and ($fedCreds -match [regex]::Escape($repoFullName))) {
        $AppId = $app.appId
        Write-Host "  Found SP: $($app.displayName) ($AppId)" -ForegroundColor Gray
        break
    }
}

if (-not $AppId) {
    Write-Error "No app registration found with federated credentials for repo '$repoFullName'. Create one first."
    exit 1
}

# ============================================================================
# 5. Assign roles
# ============================================================================
$acrScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/$AcrName"
$appServiceScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$AppServiceName"

$assignments = @(
    @{
        Role        = "Contributor"
        Scope       = $acrScope
        Description = "Allows az acr build to schedule build tasks and push images"
    }
    @{
        Role        = "Contributor"
        Scope       = $appServiceScope
        Description = "Allows az webapp config container set and az webapp restart"
    }
)

Write-Host ""
Write-Host "Assigning roles to service principal: $AppId" -ForegroundColor Cyan
Write-Host ""

foreach ($assignment in $assignments) {
    Write-Host "  Assigning [$($assignment.Role)] on scope:" -ForegroundColor Yellow
    Write-Host "    $($assignment.Scope)" -ForegroundColor Gray
    Write-Host "    Reason: $($assignment.Description)" -ForegroundColor Gray

    az role assignment create `
        --assignee $AppId `
        --role $assignment.Role `
        --scope $assignment.Scope `
        --only-show-errors 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    -> Assigned successfully." -ForegroundColor Green
    }
    else {
        Write-Host "    -> Failed (may already exist or insufficient permissions)." -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Done. All role assignments processed." -ForegroundColor Cyan
