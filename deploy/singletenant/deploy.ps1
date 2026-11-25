#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId = '5e54a3dc-946e-4ba6-9aeb-5fdd3c07bb86',
    [string]$ParametersFile = "$PSScriptRoot\infra\main.bicepparam",
    [ValidateSet('resourceGroup', 'subscription')]
    [string]$IsolationMode,
    [ValidateRange(1, 999)]
    [int]$ParticipantCount,
    [string[]]$ParticipantSubscriptionIds,
    [string]$UserPrefix = 'hackuser',
    [string]$UserDomain = 'caldova03652943.onmicrosoft.com',
    [string]$DeploymentName = 'cosmosdb-bootcamp',
    [switch]$ValidateOnly,
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Az {
    param([string[]]$Arguments)
    $result = & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed (exit $LASTEXITCODE): az $($Arguments -join ' ')"
    }
    return $result
}

if ($ValidateOnly -and $Preview) {
    throw 'Choose either -ValidateOnly or -Preview, not both.'
}

$parameterPath = (Resolve-Path -LiteralPath $ParametersFile).Path
$temporaryParameters = [System.IO.Path]::GetTempFileName()
try {
    Invoke-Az -Arguments @('bicep', 'build-params', '--file', $parameterPath, '--outfile', $temporaryParameters) | Out-Null
    $document = Get-Content -LiteralPath $temporaryParameters -Raw | ConvertFrom-Json -AsHashtable
    $parameters = $document.parameters
    foreach ($override in @{
        IsolationMode = 'isolationMode'
        ParticipantCount = 'participantCount'
        ParticipantSubscriptionIds = 'participantSubscriptionIds'
    }.GetEnumerator()) {
        if ($PSBoundParameters.ContainsKey($override.Key)) {
            $parameters[$override.Value] = @{ value = $PSBoundParameters[$override.Key] }
        }
    }

    $count = [int]$parameters.participantCount.value
    $mode = [string]$parameters.isolationMode.value
    $subscriptionIds = @($parameters.participantSubscriptionIds.value)
    if ($count -lt 1 -or $count -gt 999) {
        throw 'participantCount must be between 1 and 999.'
    }
    if ($mode -notin @('resourceGroup', 'subscription')) {
        throw 'isolationMode must be resourceGroup or subscription.'
    }
    if ($parameters.namePrefix.value -cnotmatch '^[a-z][a-z0-9]{2,11}$') {
        throw 'namePrefix must be 3-12 lowercase alphanumeric characters, starting with a letter.'
    }
    if ($parameters.chatModel.value.name -eq $parameters.embeddingModel.value.name) {
        throw 'Chat and embedding deployment names must differ.'
    }
    if ($mode -eq 'subscription') {
        if ($subscriptionIds.Count -ne $count -or @($subscriptionIds | Sort-Object -Unique).Count -ne $count) {
            throw 'Subscription mode requires exactly participantCount distinct existing subscription IDs.'
        }
    } elseif ($subscriptionIds.Count -ne 0) {
        throw 'participantSubscriptionIds must be empty in resourceGroup mode.'
    }

    $organizer = Invoke-Az -Arguments @('account', 'show', '--subscription', $SubscriptionId, '--output', 'json') |
        ConvertFrom-Json
    if ($organizer.state -ne 'Enabled') {
        throw "Organizer subscription $SubscriptionId is not enabled."
    }
    $targetSubscriptions = if ($mode -eq 'subscription') { $subscriptionIds } else { @($organizer.id) }
    foreach ($targetId in $targetSubscriptions) {
        $parsedId = [guid]::Empty
        if (-not [guid]::TryParseExact($targetId, 'D', [ref]$parsedId)) {
            throw "Supply subscription GUIDs, not names: $targetId"
        }
        $target = Invoke-Az -Arguments @('account', 'show', '--subscription', $targetId, '--output', 'json') |
            ConvertFrom-Json
        if ($target.tenantId -ne $organizer.tenantId -or $target.state -ne 'Enabled') {
            throw "Subscription $targetId must be enabled and belong to organizer tenant $($organizer.tenantId)."
        }
        foreach ($provider in @('Microsoft.DocumentDB', 'Microsoft.CognitiveServices')) {
            $providerState = Invoke-Az -Arguments @('provider', 'show', '--namespace', $provider, '--subscription', $targetId,
                '--query', 'registrationState', '--output', 'tsv')
            if ($providerState -ne 'Registered') {
                throw "$provider is not registered in $targetId. Run az provider register --namespace $provider --subscription $targetId --wait first."
            }
        }
    }

    $objectIds = @($parameters.participantObjectIds.value)
    if ($objectIds.Count -eq 0) {
        $login = Invoke-Az -Arguments @('account', 'show', '--output', 'json') | ConvertFrom-Json
        if ($login.tenantId -ne $organizer.tenantId) {
            throw "Sign in to organizer tenant $($organizer.tenantId) before resolving participant users."
        }
        Write-Verbose "Resolving participants in tenant $($organizer.tenantId)."
        $objectIds = @(for ($number = 1; $number -le $count; $number++) {
            $upn = '{0}{1:D3}@{2}' -f $UserPrefix, $number, $UserDomain
            $user = Invoke-Az -Arguments @('ad', 'user', 'show', '--id', $upn, '--output', 'json') | ConvertFrom-Json
            $user.id
        })
    }
    if ($objectIds.Count -ne $count -or @($objectIds | Sort-Object -Unique).Count -ne $count) {
        throw 'Supply exactly participantCount distinct participantObjectIds, or leave the array empty to resolve hackuserNNN.'
    }
    foreach ($objectId in $objectIds) {
        $parsedId = [guid]::Empty
        if (-not [guid]::TryParseExact($objectId, 'D', [ref]$parsedId)) {
            throw "Invalid participant object ID: $objectId"
        }
    }
    $parameters.participantObjectIds = @{ value = $objectIds }
    $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temporaryParameters -Encoding utf8 -WhatIf:$false

    $action = if ($ValidateOnly) { 'validate' } elseif ($Preview) { 'what-if' } else { 'create' }
    $arguments = @(
        'deployment', 'sub', $action,
        '--subscription', $organizer.id,
        '--name', $DeploymentName,
        '--location', $parameters.location.value,
        '--template-file', "$PSScriptRoot\infra\main.bicep",
        '--parameters', "@$temporaryParameters"
    )
    if ($ValidateOnly -or $Preview) {
        Invoke-Az $arguments
    } elseif ($PSCmdlet.ShouldProcess("$count participant environments ($mode) in tenant $($organizer.tenantId)", 'Deploy Cosmos DB and Foundry resources')) {
        Invoke-Az ($arguments + @('--query', 'properties.outputs', '--output', 'json'))
    }
} finally {
    Remove-Item -LiteralPath $temporaryParameters -Force -ErrorAction Stop -WhatIf:$false
}
