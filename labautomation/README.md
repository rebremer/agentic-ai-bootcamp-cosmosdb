# Cosmos DB bootcamp lab automation

MicroHack lab automation that gives every participant a dedicated Cosmos DB account and Microsoft Foundry account in an **existing**,
platform-provisioned Azure scope. It is the converted form of [`deploy/singletenant`](../deploy/singletenant), which creates
resource groups itself with subscription-scoped Bicep. Here the platform creates the scope and the participant RBAC and runs
the hook **once per participant**. Contract: the [MicroHack lab automation README](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md)
and the [foundry-bootcamp labautomation README](https://github.com/JoranBergfeld/foundry-bootcamp/blob/main/labautomation/README.md).
This folder is not participant download material.

| File | Purpose |
|---|---|
| `lab-defaults.json` | Platform configuration: resource-group scope, 20 labs per subscription, region `swedencentral`, estimated cost |
| `shared-deploy-lab.ps1` | Once per subscription, before the labs: registers `Microsoft.DocumentDB` and `Microsoft.CognitiveServices` |
| `deploy-lab.ps1` | Per participant: deploys `main.bicep` and publishes the participant values |
| `main.bicep` | Resource-group-scoped template for one participant |
| `tests/deploy-lab.Tests.ps1` | Local checks of the hook with stubbed Azure/platform commands |

## What changed compared to `deploy/singletenant`

| Single-tenant project | labautomation |
|---|---|
| Subscription-scoped `main.bicep` loops over `participantCount` participants | Resource-group-scoped `main.bicep` for one participant; the platform does the fan-out |
| Creates `<prefix>-NNN-rg` and `hackuserNNN` mapping | Resource group and users come from the platform (`ResourceGroupName`, `AllowedEntraUserIds`); no Owner role is requested |
| Participant Reader role on the resource group | Dropped; participants only get the data-plane roles from `main.bicep` |
| `location` and `aiLocation` parameters | One `location` that follows the resource group; the platform picks the region from `PreferredLocation` and falls back on capacity errors |
| Database `<prefix>-NNN` | Database `cosmosbc` (`databaseName`), published on the dashboard; the participant number no longer exists |
| Operator output `environments` | `HackboxCredential` values on the participant dashboard |
| `isolationMode`, `participantSubscriptionIds`, `deploy.ps1` | Replaced by the platform's `deploymentType` and its subscription allocation |

Resources per participant are unchanged: serverless Cosmos DB (vector search, keys disabled, TLS 1.2) with `chats` (`/sessionId`),
`products` (`/category`, 1536-dimensional cosine vector index) and `test` (`/id`); an `AIServices` S0 Foundry account with
`gpt-4.1-mini` and `text-embedding-3-small` (GlobalStandard, capacity 10 each). Participants get *Cosmos DB Built-in Data
Contributor* scoped to their database and *Cognitive Services OpenAI User* on their Foundry account. No keys, passwords or tokens are created or emitted.
Account names are `cosmosbc-<uniqueString(subscription, resource group, nameSeed)>`, so reruns update the same resources.

## How `deploy-lab.ps1` behaves

- Keeps the platform parameter contract (`DeploymentType`, `SubscriptionId`, `ResourceGroupName`, `PreferredLocation`, `AllowedEntraUserIds`) and never signs in or switches subscriptions.
- Fails before any Azure operation if no region or no valid Entra user object ID is supplied. `PreferredLocation` may be an array or comma-separated.
- `subscription` deployments derive `lab-<stable hash>` from the participant IDs (the resource group is created by the helper); other types require `ResourceGroupName`.
- Waits for the two resource providers to be registered.
- **Empty resource group (first run):** `Invoke-MhhDeploymentWithRegionFallback` deploys and falls back to the next preferred region on quota/capacity errors.
- **Resource group that already contains resources (rerun):** an incremental deployment in place, in the resource group's region. The helper is **not** used, because it can wipe the resource group on recycle and would destroy chat history and vectorized products.
- Emits credentials only after a complete successful deployment (all values are non-secret).

| Credential | Value |
|---|---|
| `Region` | Effective deployment region |
| `CosmosAccountName` / `CosmosEndpoint` / `CosmosDatabase` | Account, `https://<account>.documents.azure.com:443/`, database name |
| `FoundryEndpoint` | `https://<account>.services.ai.azure.com` (bare host, no `/openai` suffix) |
| `OpenAIEndpoint` | `https://<account>.openai.azure.com/` |
| `ChatDeploymentName` / `EmbeddingDeploymentName` | `gpt-4.1-mini` / `text-embedding-3-small` |
| `EmbeddingDimensions` | `1536` |
| `Lab Resource Group` | Only for `subscription` deployments; the platform emits `Resource Group Name` itself otherwise |

## Operator notes

- Check `gpt-4.1-mini` and `text-embedding-3-small` availability and quota in the event regions, for example
  `az cognitiveservices usage list --location <region> --subscription <id>`. Reserve 20 x the declared capacity per subscription and region.
- Default Cosmos DB account (50) and Foundry account limits per region and subscription cap `labsPerSubscription`; 20 leaves headroom.
- Dedicated accounts isolate data, not quota. Clients must handle `429`.
- `deploy-lab.ps1` does not pass `-RgOwnerEntraObjectIds` to `Invoke-MhhDeploymentWithRegionFallback`, so participants should only get the data-plane roles from `main.bicep`.
  Verify after deployment that no Owner role exists on the resource group; if the platform still grants it, participants can re-enable keys.
- Cosmos CORS defaults to Live Server origins (`http://localhost:5500`, `http://127.0.0.1:5500`); extend `corsOrigins` in `main.bicep` if needed.
- Foundry soft-delete can reserve account names after teardown; change `nameSeed` if a name collides.
- `estimatedDailyCostsUsd` (2.0) and `groups` (empty) are placeholders: tune the cost and add `GHCPUsers` if the platform should assign Copilot seats.
- The bootcamp [prompts](../prompt.txt) and [constitution](../.github/copilot-instructions.md) still describe `cosmosbc-<number>` names; point them at the dashboard values instead.

## Local validation

No Azure deployment is performed:

```powershell
az bicep build --file labautomation\main.bicep --stdout > $null
az bicep lint --file labautomation\main.bicep
pwsh -File labautomation\tests\deploy-lab.Tests.ps1
```

For a live test use the [`adminpwsh`](https://github.com/qxsch/adminpwsh) container as described in the MicroHack README, with a pre-created empty resource group:

```powershell
./deploy-lab.ps1 -DeploymentType resourcegroup -SubscriptionId (Get-AzContext).Subscription.Id `
  -ResourceGroupName lab-local-test -PreferredLocation 'swedencentral' -AllowedEntraUserIds (Get-AzADUser -SignedIn).Id
```

Local checks do not prove live model availability, quota, Azure Policy compliance or data-plane access.
