# CosmosDBbootcampSingleTenant

Dedicated Cosmos DB and Microsoft Foundry endpoints per bootcamp participant, without APIM.
All participants and subscriptions belong to **one Microsoft Entra tenant**; "single tenant" does not mean a new Entra tenant per participant.
This is a standalone deployment project in `deploy/singletenant`; it is independent of the shared-gateway (APIM) variant.

## What is deployed

For each participant, the numbered name `<namePrefix>-NNN` (`cosmosbc-001` ... `cosmosbc-999`, `NNN` matching `hackuserNNN`) identifies their environment:

| Resource | Name |
|---|---|
| Resource group | `<namePrefix>-NNN-rg` |
| Cosmos DB database | `<namePrefix>-NNN`, the database a participant selects |
| Cosmos DB account and Foundry account | `<namePrefix>-<random>-NNN` |

Cosmos DB account names and Foundry endpoint hosts are global, so they carry a 13-character random segment (`uniqueString` of subscription, participant and `nameSeed`) to avoid collisions. The segment is deterministic, so reruns update the same resources. If a name is still reserved (for example by a soft-deleted Foundry account), set a different `nameSeed`.
Model deployments keep their model names (`gpt-4.1-mini`, `text-embedding-3-small`), because clients address them by name.

| Resource | Configuration |
|---|---|
| Resource group | `<namePrefix>-NNN-rg`, in the chosen subscription |
| Cosmos DB | Dedicated serverless NoSQL account, vector search, session consistency, TLS 1.2, keys disabled |
| Database | `<namePrefix>-NNN`; `chats` (`/sessionId`), `products` (`/category`, 1536-dimensional cosine vector index), `test` (`/id`) |
| Foundry | Dedicated `AIServices` S0 account; `gpt-4.1-mini` and `text-embedding-3-small` model deployments |
| Participant access | Cosmos DB Built-in Data Contributor scoped to their database; Cognitive Services OpenAI User on their Foundry account; Reader on their resource group |

Endpoints are public **by explicit bootcamp choice** and require Entra tokens; no account keys or passwords are generated or output.
Participants can use their data and inference endpoints and discover resources in the portal, but cannot administer resource groups/subscriptions or create databases/containers.
Existing broader/inherited Azure roles are not removed: use otherwise unprivileged participant accounts for isolation.
No APIM, gateway app registration, new Entra users, new subscriptions, Foundry projects, agents, or central Log Analytics workspace are created.

## Isolation modes

| `isolationMode` | Placement |
|---|---|
| `resourceGroup` (default) | One resource group per participant in the organizer's existing subscription |
| `subscription` | One resource group per participant in a **different existing subscription** per participant |

`participantCount` defaults to **3** (range 1-999).
Subscription mode requires exactly that many distinct subscription IDs in the organizer's tenant. It does **not** create billed subscriptions or grant subscription ownership.
The deployment uses subscription-scoped Bicep modules, not billing APIs or management-group privileges.

## Prerequisites

- PowerShell 7+, Azure CLI with Bicep support (`az bicep version`).
- Sign in to the tenant containing the organizer subscription and existing participants.
- Default organizer subscription: `5e54a3dc-946e-4ba6-9aeb-5fdd3c07bb86`; override with `-SubscriptionId`.
- Existing users `hackuser001@caldova03652943.onmicrosoft.com` through `hackuserNNN@...`.
  The helper reads these users from Entra; it never creates or resets them. Directory lookup permission is needed.
- The deployer needs subscription-level resource deployment permissions and role-assignment write permissions in **each target subscription** (for example Contributor plus User Access Administrator, or Owner).
  Cross-subscription mode also needs deployment permission on the organizer subscription.
- Register `Microsoft.DocumentDB` and `Microsoft.CognitiveServices` in every target subscription before deployment, for example:

```powershell
az provider register --namespace Microsoft.DocumentDB --subscription <subscription-id> --wait
az provider register --namespace Microsoft.CognitiveServices --subscription <subscription-id> --wait
```

The helper checks registration without changing it or switching your active subscription.
Check model/version availability, account limits and quota in `aiLocation` first.
The defaults retain the source project's model versions; availability is not guaranteed in every subscription/region.

## Deploy

From this directory:

```powershell
az login --tenant caldova03652943.onmicrosoft.com

# Read-only preflight and local parameter compilation; no Azure deployments.
.\deploy.ps1 -WhatIf

# Azure-side validation and change preview; neither creates participant resources.
.\deploy.ps1 -ValidateOnly
.\deploy.ps1 -Preview

# Three independent environments in the existing organizer subscription.
.\deploy.ps1

# Six environments in that subscription.
.\deploy.ps1 -ParticipantCount 6

# One existing subscription per participant, in participant order.
.\deploy.ps1 -IsolationMode subscription -ParticipantCount 3 `
  -ParticipantSubscriptionIds '<subscription-for-001>', '<subscription-for-002>', '<subscription-for-003>'
```

Preview before creating resources; provisioning and subsequent use incur Azure charges.
`-ValidateOnly` and `-Preview` must be used separately.
An Azure error stops the helper immediately; an error after provisioning has begun may leave partial resources.

### Configuration and existing users

Edit [`infra/main.bicepparam`](infra/main.bicepparam) for region, prefix, participant count, mode, subscriptions, CORS origins, chat/embedding models and capacity.
Helper command-line options override the corresponding values in that file. `-ParametersFile` selects an alternative parameter file.
`aiLocation` can differ from the Cosmos DB `location`.

Leave `participantObjectIds = []` to let the helper resolve `hackuser001` through `hackuserNNN`.
Use `-UserPrefix` and `-UserDomain` for another naming convention.
Alternatively set exactly `participantCount` distinct Entra user object IDs in that array, ordered by participant; the helper then skips directory lookups.
Use **object IDs**, not client/application IDs.
User identities and subscription IDs are supplied by the operator, not created by Bicep.

Resource names are deterministic (random segment derived from subscription, participant and `nameSeed`). Rerunning with the same prefix, mode, subscriptions and seed updates the same resources; if a name is still reserved (for example by a soft-deleted Foundry account), change `nameSeed`.
Changing placement or reducing the participant count does **not** delete previous environments.
Changing an existing Cosmos DB vector policy/dimensions requires migration or container recreation.
Model capacity is expressed in **model/SKU-specific quota units**, not a universal TPM unit.

### Direct Bicep usage

Fill `participantObjectIds` explicitly first; the empty array is only an input for the helper's user resolution.
In subscription mode also fill `participantSubscriptionIds`.
For direct deployments you must enforce the same exact-count, uniqueness and same-tenant requirements yourself.

```powershell
az bicep build --file .\infra\main.bicep
az bicep build-params --file .\infra\main.bicepparam
az deployment sub what-if --subscription <organizer-subscription-id> `
  --location swedencentral --name cosmosdb-bootcamp `
  --template-file .\infra\main.bicep --parameters .\infra\main.bicepparam
az deployment sub create --subscription <organizer-subscription-id> `
  --location swedencentral --name cosmosdb-bootcamp `
  --template-file .\infra\main.bicep --parameters .\infra\main.bicepparam
```

## Participant endpoints and authentication

Read the `environments` output, ordered by participant:

```powershell
az deployment sub show --subscription <organizer-subscription-id> `
  --name cosmosdb-bootcamp --query properties.outputs --output json
```

Each entry includes participant/object ID, subscription, resource group, Cosmos account/endpoint/database, Foundry endpoint, OpenAI endpoint, model deployment names and vector dimensions.
These outputs contain no keys or credentials.

| Service | Entra token scope | Usage |
|---|---|---|
| Cosmos DB | `https://cosmos.azure.com/.default` | SDK/REST against `cosmosEndpoint`, database `cosmosDatabase` |
| Foundry OpenAI models | `https://cognitiveservices.azure.com/.default` | SDK with `openAiEndpoint`; REST chat: `{openAiEndpoint}openai/deployments/{chatDeployment}/chat/completions?api-version=2024-10-21` |

Embeddings use the same OpenAI endpoint with `openai/deployments/{embeddingDeployment}/embeddings?api-version=2024-10-21`.
Use `Authorization: Bearer <token>` for OpenAI calls. Cosmos SDKs handle the Cosmos-specific authorization format.
RBAC propagation can take several minutes.
Cosmos CORS defaults to local development origins; add the actual frontend origin if necessary.
Removing APIM also removes its JWT app/group validation, CORS handling and custom per-user token limiter.
Direct Foundry browser calls must meet that service's own CORS requirements; prefer an SDK/local backend where browser calls are unsupported.

## Limits, security and cost

- Dedicated accounts isolate data and endpoints, **not subscription-level quota**. Resource-group mode shares regional model quota and account limits. Plan total model capacity across all participants.
- No custom per-user TPM cap, retry gateway or cross-region failover remains. Clients must handle `429` responses.
- Use only lab data. Public networking is not a production security baseline; keys remain disabled and access is scoped to the participant.
- The original deployment's `SecurityControl=Ignore` tag is intentionally not copied. If Azure Policy blocks public access, request an approved policy exception or change the network design; do not silently bypass policy.
- No budgets or cost alerts are configured. Cosmos serverless bills for consumed RUs/storage; models incur inference charges. Monitor and remove environments after the event.

## Validation and cleanup

Local checks (no Azure deployment):

```powershell
az bicep build --file .\infra\main.bicep
az bicep build-params --file .\infra\main.bicepparam
.\tests\deploy.Tests.ps1
```

Local compilation and mocked helper tests do not prove live model availability, quota, Azure Policy compliance or data-plane access.
After deployment, sign in as each participant and verify inference and Cosmos item operations in their environment, and denied access to another participant's environment.

Delete only the named participant resource groups after reviewing them:

```powershell
az group delete --subscription <participant-subscription-id> --name cosmosbc-001-rg
```

Repeat for every participant, using the output's subscription and resource-group mapping. Deleting the organizer deployment record alone does not delete resources.
Existing subscriptions and Entra users are retained. Foundry account soft deletion can temporarily reserve names; review soft-deleted accounts if redeployment encounters a name conflict.
