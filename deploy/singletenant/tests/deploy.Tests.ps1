#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$fixturePath = [System.IO.Path]::GetTempFileName()
try {
    & az bicep build-params --file "$root\infra\main.bicepparam" --outfile $fixturePath
    if ($LASTEXITCODE -ne 0) { throw 'Bicep parameter compilation failed.' }
    $baseline = Get-Content -LiteralPath $fixturePath -Raw
} finally {
    Remove-Item -LiteralPath $fixturePath -Force
}

$state = @{
    OrganizerId = '10000000-0000-0000-0000-000000000001'
    TenantId = '20000000-0000-0000-0000-000000000001'
    Subscriptions = @(
        '30000000-0000-0000-0000-000000000001'
        '30000000-0000-0000-0000-000000000002'
        '30000000-0000-0000-0000-000000000003'
    )
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Reset-Fixture {
    $state.Fixture = $baseline | ConvertFrom-Json -AsHashtable
    $state.Fixture.parameters.participantCount.value = 3
    $state.UserLookups = [System.Collections.Generic.List[string]]::new()
    $state.DeploymentActions = [System.Collections.Generic.List[string]]::new()
    $state.CapturedParameters = $null
    $state.TemporaryPath = $null
    $state.ForeignSubscription = ''
    $state.ProviderState = 'Registered'
    $state.FailUserLookup = $false
}

# All Azure operations inside the helper are mocked, including deployment create.
function az {
    $arguments = @($args)
    $global:LASTEXITCODE = 0
    if ($arguments[0] -eq 'bicep' -and $arguments[1] -eq 'build-params') {
        $state.TemporaryPath = $arguments[$arguments.IndexOf('--outfile') + 1]
        [System.IO.File]::WriteAllText($state.TemporaryPath, ($state.Fixture | ConvertTo-Json -Depth 100))
    } elseif ($arguments[0] -eq 'account' -and $arguments[1] -eq 'show') {
        $id = if ($arguments -contains '--subscription') {
            $arguments[$arguments.IndexOf('--subscription') + 1]
        } else { $state.OrganizerId }
        @{
            id = $id
            tenantId = $(if ($id -eq $state.ForeignSubscription) { 'other-tenant' } else { $state.TenantId })
            state = 'Enabled'
        } | ConvertTo-Json
    } elseif ($arguments[0] -eq 'provider' -and $arguments[1] -eq 'show') {
        $state.ProviderState
    } elseif ($arguments[0] -eq 'ad' -and $arguments[1] -eq 'user') {
        if ($state.FailUserLookup) {
            $global:LASTEXITCODE = 1
            return
        }
        $upn = $arguments[$arguments.IndexOf('--id') + 1]
        $state.UserLookups.Add($upn)
        @{ id = '40000000-0000-0000-0000-{0:D12}' -f $state.UserLookups.Count } | ConvertTo-Json
    } elseif ($arguments[0] -eq 'deployment' -and $arguments[1] -eq 'sub') {
        $state.DeploymentActions.Add($arguments[2])
        $path = $arguments[$arguments.IndexOf('--parameters') + 1].Substring(1)
        $state.CapturedParameters = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    } else {
        throw "Unexpected Azure CLI call in test: $($arguments -join ' ')"
    }
}

function Expect-Failure {
    param([scriptblock]$Action, [string]$MessagePattern)
    $failed = $false
    try { & $Action } catch {
        $failed = $true
        Assert-True ($_.Exception.Message -like $MessagePattern) "Unexpected error: $($_.Exception.Message)"
    }
    Assert-True $failed 'Expected helper to reject invalid inputs.'
    Assert-True ($state.DeploymentActions.Count -eq 0) 'Invalid inputs reached an Azure deployment.'
    Assert-True (-not (Test-Path -LiteralPath $state.TemporaryPath)) 'Temporary parameters were not cleaned up.'
}

$tests = [ordered]@{
    'Three participants create exactly three mapped environments' = {
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -Confirm:$false
        Assert-True ($state.UserLookups.Count -eq 3) 'Expected exactly three user lookups.'
        Assert-True ($state.UserLookups[0] -eq 'hackuser001@caldova03652943.onmicrosoft.com') 'Wrong first user.'
        Assert-True ($state.UserLookups[2] -eq 'hackuser003@caldova03652943.onmicrosoft.com') 'Wrong last user.'
        Assert-True ($state.CapturedParameters.parameters.participantObjectIds.value.Count -eq 3) 'Object ID output shape is wrong.'
        Assert-True ($state.CapturedParameters.parameters.isolationMode.value -eq 'resourceGroup') 'Wrong default isolation.'
        Assert-True ($state.DeploymentActions[0] -eq 'create') 'Expected create.'
        Assert-True (-not (Test-Path -LiteralPath $state.TemporaryPath)) 'Temporary parameters were not removed.'
    }
    'Participant count override and preview' = {
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -ParticipantCount 5 -Preview
        Assert-True ($state.UserLookups.Count -eq 5) 'Count override did not resolve five users.'
        Assert-True ($state.CapturedParameters.parameters.participantCount.value -eq 5) 'Count override was not passed to ARM.'
        Assert-True ($state.DeploymentActions[0] -eq 'what-if') 'Preview must call Azure what-if, not create.'
    }
    'Single participant retains array parameter shape' = {
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -ParticipantCount 1 -ValidateOnly
        $ids = $state.CapturedParameters.parameters.participantObjectIds.value
        Assert-True ($ids -is [array] -and $ids.Count -eq 1) 'A single participant must remain an array.'
        Assert-True ($state.UserLookups.Count -eq 1) 'Expected exactly one user lookup.'
    }
    'Separate subscriptions preserve participant order' = {
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -IsolationMode subscription `
            -ParticipantSubscriptionIds $state.Subscriptions -ValidateOnly
        $values = $state.CapturedParameters.parameters
        Assert-True ($values.isolationMode.value -eq 'subscription') 'Wrong isolation mode.'
        Assert-True (($values.participantSubscriptionIds.value -join ',') -eq ($state.Subscriptions -join ',')) 'Subscription order changed.'
        Assert-True ($state.DeploymentActions[0] -eq 'validate') 'ValidateOnly must not create.'
    }
    'Supplied object IDs do not query directory' = {
        $state.Fixture.parameters.participantObjectIds.value = @(1..3 | ForEach-Object { '50000000-0000-0000-0000-{0:D12}' -f $_ })
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -ValidateOnly
        Assert-True ($state.UserLookups.Count -eq 0) 'Explicit IDs must bypass directory lookup.'
    }
    'WhatIf never deploys' = {
        & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -WhatIf
        Assert-True ($state.DeploymentActions.Count -eq 0) 'WhatIf called an Azure deployment.'
        Assert-True (-not (Test-Path -LiteralPath $state.TemporaryPath)) 'WhatIf left temporary parameters.'
    }
    'Reject missing subscription IDs' = {
        Expect-Failure { & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -IsolationMode subscription } '*exactly participantCount distinct existing subscription IDs*'
    }
    'Reject duplicate subscription IDs' = {
        Expect-Failure {
            & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -IsolationMode subscription `
                -ParticipantSubscriptionIds @($state.Subscriptions[0], $state.Subscriptions[0], $state.Subscriptions[2])
        } '*exactly participantCount distinct existing subscription IDs*'
    }
    'Reject subscriptions from another tenant' = {
        $state.ForeignSubscription = $state.Subscriptions[1]
        Expect-Failure {
            & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId -IsolationMode subscription `
                -ParticipantSubscriptionIds $state.Subscriptions
        } '*must be enabled and belong to organizer tenant*'
    }
    'Reject duplicate participant IDs' = {
        $state.Fixture.parameters.participantObjectIds.value = @($state.OrganizerId, $state.OrganizerId, $state.OrganizerId)
        Expect-Failure { & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId } '*exactly participantCount distinct participantObjectIds*'
    }
    'Missing provider fails without automatic registration' = {
        $state.ProviderState = 'NotRegistered'
        Expect-Failure { & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId } '*not registered*'
    }
    'Directory lookup failure is surfaced and cleaned up' = {
        $state.FailUserLookup = $true
        Expect-Failure { & "$root\deploy.ps1" -SubscriptionId $state.OrganizerId } '*Azure CLI failed*'
    }
}

foreach ($test in $tests.GetEnumerator()) {
    Reset-Fixture
    & $test.Value
    Write-Host "PASS: $($test.Key)"
}
Write-Host "$($tests.Count) tests passed; all deployment calls were mocked."
