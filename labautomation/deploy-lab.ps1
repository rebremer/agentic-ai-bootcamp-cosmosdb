<#
.SYNOPSIS
Deploys one participant's Cosmos DB and Microsoft Foundry environment into a pre-provisioned Azure scope.
.DESCRIPTION
MicroHack per-participant hook. Runs once per participant, in its own process, with the Azure context
already pointed at SubscriptionId. It never signs in or switches subscriptions.
Derived from deploy/singletenant: subscription, resource group, participant RBAC and region
preference are supplied by the platform instead of by subscription-scoped Bicep.
Resources: dedicated serverless Cosmos DB account (vector search, keys disabled) with database,
chats/products/test containers, and a dedicated Foundry (AIServices) account with chat and
embedding model deployments. Access is Entra only; no keys are created or emitted.
.PARAMETER DeploymentType
Deployment scope; allowed values are subscription, resourcegroup or resourcegroup-with-subscriptionowner.
.PARAMETER SubscriptionId
Azure subscription that contains the lab resources.
.PARAMETER ResourceGroupName
Existing participant resource group. Empty for subscription deployments, where a stable name is derived.
.PARAMETER PreferredLocation
Preferred Azure regions in priority order (array or comma-separated).
.PARAMETER AllowedEntraUserIds
Entra user object IDs that may use the lab resources.
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$template = Join-Path $PSScriptRoot 'main.bicep'
$requiredProviders = @('Microsoft.DocumentDB', 'Microsoft.CognitiveServices')

$locations = @($PreferredLocation | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($locations.Count -eq 0) {
    throw 'At least one preferred region is required.'
}

$userIds = @($AllowedEntraUserIds | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($userIds.Count -eq 0) {
    throw 'At least one Entra user object ID is required.'
}
foreach ($userId in $userIds) {
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParseExact($userId, 'D', [ref]$parsedId)) {
        throw "Invalid Entra user object ID: $userId"
    }
}

if ($DeploymentType -eq 'subscription') {
    $effectiveResourceGroup = 'lab-{0}' -f (Get-MhhStableHash -Value $userIds -Length 24)
} elseif ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    throw "ResourceGroupName must be provided when DeploymentType is '$DeploymentType'."
} else {
    $effectiveResourceGroup = $ResourceGroupName
}

# Registration is normally done by shared-deploy-lab.ps1 but is asynchronous, so wait for it here.
foreach ($provider in $requiredProviders) {
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    while ($true) {
        $registered = @(Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop |
            Where-Object { $_.RegistrationState -eq 'Registered' }).Count -gt 0
        if ($registered) { break }
        if ([DateTime]::UtcNow -ge $deadline) {
            throw "$provider is not registered in subscription $SubscriptionId."
        }
        Write-Host "Waiting for resource provider $provider to register..."
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
        Start-Sleep -Seconds 15
    }
}

# A populated resource group holds participant data (chats, products); never let the helper recycle it.
$existingGroup = Get-AzResourceGroup -Name $effectiveResourceGroup -ErrorAction SilentlyContinue
$populated = $false
if ($existingGroup) {
    $populated = @(Get-AzResource -ResourceGroupName $effectiveResourceGroup -ErrorAction Stop).Count -gt 0
}

$templateParameters = @{ participantObjectIds = $userIds }

Update-MhhToken | Out-Null
if ($populated) {
    $location = $existingGroup.Location
    if ($location -notin $locations) {
        Write-Warning "Resource group '$effectiveResourceGroup' is in '$location', which is not in the preferred regions ($($locations -join ', ')). Redeploying in place."
    }
    Write-Host "Resource group '$effectiveResourceGroup' already contains resources; deploying incrementally in '$location'."
    $deployment = New-AzResourceGroupDeployment `
        -Name ('lab-{0}' -f (Get-Date -Format 'yyyyMMddHHmmss')) `
        -ResourceGroupName $effectiveResourceGroup `
        -TemplateFile $template `
        -TemplateParameterObject $templateParameters `
        -Mode Incremental `
        -ErrorAction Stop
    if ($deployment.ProvisioningState -ne 'Succeeded') {
        throw "Deployment '$($deployment.DeploymentName)' ended as '$($deployment.ProvisioningState)'."
    }
    $outputs = @{}
    foreach ($entry in $deployment.Outputs.GetEnumerator()) { $outputs[$entry.Key] = $entry.Value.Value }
    $locationUsed = $location
} else {
    $result = Invoke-MhhDeploymentWithRegionFallback `
        -PreferredLocations $locations `
        -ResourceGroupName $effectiveResourceGroup `
        -TemplateFile $template `
        -TemplateParameterObject $templateParameters `
        -DeploymentNamePrefix 'lab'
    $outputs = $result.Outputs
    $locationUsed = $result.LocationUsed
}

foreach ($name in 'cosmosAccountName', 'cosmosEndpoint', 'cosmosDatabase', 'foundryEndpoint', 'openAiEndpoint',
    'chatDeployment', 'embeddingDeployment', 'embeddingDimensions') {
    if (-not $outputs.ContainsKey($name) -or [string]::IsNullOrWhiteSpace([string]$outputs[$name])) {
        throw "Deployment succeeded but output '$name' is missing; not publishing credentials."
    }
}

# Credentials are emitted only after a complete, successful deployment. None of them is a secret.
$credentials = [ordered]@{
    'Region'                  = $locationUsed
    'CosmosAccountName'       = $outputs.cosmosAccountName
    'CosmosEndpoint'          = $outputs.cosmosEndpoint
    'CosmosDatabase'          = $outputs.cosmosDatabase
    'FoundryEndpoint'         = $outputs.foundryEndpoint
    'OpenAIEndpoint'          = $outputs.openAiEndpoint
    'ChatDeploymentName'      = $outputs.chatDeployment
    'EmbeddingDeploymentName' = $outputs.embeddingDeployment
    'EmbeddingDimensions'     = $outputs.embeddingDimensions
}
if ($DeploymentType -eq 'subscription') {
    # The platform emits 'Resource Group Name' itself only for resource group deployments.
    $credentials['Lab Resource Group'] = $effectiveResourceGroup
}
foreach ($credential in $credentials.GetEnumerator()) {
    @{ HackboxCredential = @{ name = $credential.Key; value = [string]$credential.Value; note = '' } }
}
