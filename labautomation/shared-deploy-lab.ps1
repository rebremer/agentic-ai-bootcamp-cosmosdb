param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation,

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

# Runs once per subscription before any deploy-lab.ps1. Registration is subscription-wide, so doing it here
# avoids every parallel participant deployment racing on it. Registration stays asynchronous;
# deploy-lab.ps1 waits for it. Idempotent.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($provider in 'Microsoft.DocumentDB', 'Microsoft.CognitiveServices') {
    $registered = @(Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop |
        Where-Object { $_.RegistrationState -eq 'Registered' }).Count -gt 0
    if ($registered) {
        Write-Host "$provider is already registered in $SubscriptionId."
    } else {
        Write-Host "Registering $provider in $SubscriptionId..."
        Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
    }
}
