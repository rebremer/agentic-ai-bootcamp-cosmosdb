#requires -Version 7.0
# Local checks of deploy-lab.ps1 with the platform/Azure commands stubbed; nothing is deployed.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'deploy-lab.ps1'
$userA = '40000000-0000-0000-0000-000000000001'
$userB = '40000000-0000-0000-0000-000000000002'

$state = @{}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw "Unexpected error: $($_.Exception.Message)" }
        return
    }
    throw "Expected an error matching '$Pattern'."
}

function Reset-State {
    $state.GroupExists = $true
    $state.Resources = @()
    $state.ProviderState = 'Registered'
    $state.HelperCalls = [System.Collections.Generic.List[hashtable]]::new()
    $state.DeploymentCalls = [System.Collections.Generic.List[hashtable]]::new()
    $state.Outputs = @{
        cosmosAccountName = 'cosmosbc-abc'; cosmosEndpoint = 'https://cosmosbc-abc.documents.azure.com:443/'
        cosmosDatabase = 'cosmosbc'; foundryEndpoint = 'https://cosmosbc-abc.services.ai.azure.com'
        openAiEndpoint = 'https://cosmosbc-abc.openai.azure.com/'; chatDeployment = 'gpt-4.1-mini'
        embeddingDeployment = 'text-embedding-3-small'; embeddingDimensions = 1536
    }
}

function Update-MhhToken { }
function Get-MhhStableHash { param($Value, $Length) 'h' * $Length }
function Register-AzResourceProvider { param($ProviderNamespace) }
function Get-AzResourceProvider {
    param($ProviderNamespace)
    [pscustomobject]@{ RegistrationState = $state.ProviderState }
}
function Get-AzResourceGroup {
    param($Name)
    if ($state.GroupExists) { [pscustomobject]@{ ResourceGroupName = $Name; Location = 'norwayeast' } }
}
function Get-AzResource { param($ResourceGroupName) $state.Resources }
function Invoke-MhhDeploymentWithRegionFallback {
    param($PreferredLocations, $ResourceGroupName, $RgOwnerEntraObjectIds, $TemplateFile, $TemplateParameterObject, $DeploymentNamePrefix)
    $state.HelperCalls.Add(@{ Locations = $PreferredLocations; Group = $ResourceGroupName; Owners = $RgOwnerEntraObjectIds; Parameters = $TemplateParameterObject })
    @{ Success = $true; LocationUsed = $PreferredLocations[-1]; Outputs = $state.Outputs }
}
function New-AzResourceGroupDeployment {
    param($Name, $ResourceGroupName, $TemplateFile, $TemplateParameterObject, $Mode)
    $state.DeploymentCalls.Add(@{ Group = $ResourceGroupName; Mode = $Mode; Parameters = $TemplateParameterObject })
    $wrapped = @{}
    foreach ($key in $state.Outputs.Keys) { $wrapped[$key] = [pscustomobject]@{ Value = $state.Outputs[$key] } }
    [pscustomobject]@{ ProvisioningState = 'Succeeded'; DeploymentName = $Name; Outputs = $wrapped }
}

function Invoke-Lab {
    param([hashtable]$Arguments)
    @(& $script @Arguments)
}

function Merge-Args {
    param([hashtable]$Overrides)
    $merged = $base.Clone()
    foreach ($key in $Overrides.Keys) { $merged[$key] = $Overrides[$key] }
    $merged
}

function Get-Credential {
    param($Output, [string]$Name)
    ($Output | Where-Object { $_.HackboxCredential.name -eq $Name }).HackboxCredential.value
}

$base = @{
    DeploymentType = 'resourcegroup'; SubscriptionId = '50000000-0000-0000-0000-000000000001'
    ResourceGroupName = 'rg-test'; PreferredLocation = @('swedencentral', 'norwayeast'); AllowedEntraUserIds = @($userA, $userB)
}

# Empty resource group: first provisioning uses the region fallback helper and grants both users.
Reset-State
$output = Invoke-Lab $base
Assert-True ($state.HelperCalls.Count -eq 1 -and $state.DeploymentCalls.Count -eq 0) 'Empty scope must use the region fallback helper.'
Assert-True ($null -eq $state.HelperCalls[0].Owners) 'Helper must not be asked to grant participants RG owner.'
Assert-True (($state.HelperCalls[0].Parameters.participantObjectIds -join ',') -eq "$userA,$userB") 'Template must receive every participant.'
$names = @($output | ForEach-Object { $_.HackboxCredential.name })
Assert-True ($names.Count -eq 9 -and 'CosmosEndpoint' -in $names -and 'FoundryEndpoint' -in $names) 'Expected the nine participant credentials.'
Assert-True ('Lab Resource Group' -notin $names) 'Resource group deployments must not emit Lab Resource Group.'
Assert-True ((Get-Credential $output 'Region') -eq 'norwayeast') 'Region must be the effective region.'

# Populated resource group: incremental deployment in place, never the destructive helper.
Reset-State
$state.Resources = @([pscustomobject]@{ Name = 'cosmosbc-abc' })
$output = Invoke-Lab $base
Assert-True ($state.HelperCalls.Count -eq 0 -and $state.DeploymentCalls.Count -eq 1) 'Populated scope must deploy in place.'
Assert-True ($state.DeploymentCalls[0].Mode -eq 'Incremental') 'In-place deployment must be incremental.'
Assert-True ((Get-Credential $output 'CosmosEndpoint') -eq $state.Outputs.cosmosEndpoint) 'In-place deployment must publish template outputs.'

# Comma-separated regions are accepted.
Reset-State
Invoke-Lab (Merge-Args @{ PreferredLocation = @('swedencentral, norwayeast') }) | Out-Null
Assert-True (($state.HelperCalls[0].Locations -join ',') -eq 'swedencentral,norwayeast') 'Comma-separated regions must be split.'

# Subscription deployment derives the resource group and publishes it.
Reset-State
$state.GroupExists = $false
$output = Invoke-Lab (Merge-Args @{ DeploymentType = 'subscription'; ResourceGroupName = '' })
Assert-True ($state.HelperCalls[0].Group -match '^lab-h{24}$') 'Subscription mode must derive a stable lab-<hash> resource group.'
Assert-True ((Get-Credential $output 'Lab Resource Group') -eq $state.HelperCalls[0].Group) 'Derived resource group must be published.'

# Invalid input and incomplete deployments fail without publishing credentials.
Reset-State
Assert-Throws { Invoke-Lab (Merge-Args @{ PreferredLocation = @(' ', '') }) } 'preferred region'
Assert-Throws { Invoke-Lab (Merge-Args @{ AllowedEntraUserIds = @() }) } 'user object ID'
Assert-Throws { Invoke-Lab (Merge-Args @{ AllowedEntraUserIds = @('not-a-guid') }) } 'Invalid Entra user'
Assert-Throws { Invoke-Lab (Merge-Args @{ ResourceGroupName = '' }) } 'ResourceGroupName must be provided'
$state.Outputs.Remove('cosmosEndpoint')
Assert-Throws { Invoke-Lab $base } "output 'cosmosEndpoint' is missing"

Write-Host 'deploy-lab tests passed.'
