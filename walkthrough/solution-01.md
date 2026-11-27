# Solution 01: Connect to Cosmos DB and Foundry

**[Home](../Readme.md)** - [Next Challenge Solution](solution-02.md)

Duration: 20 minutes

## Prerequisites

Please ensure that you verified the [general prerequisites](../Readme.md#prerequisites) before continuing with this challenge.

### **Task 1: Prepare VS Code**

1. Create the folder `bootcamp-cosmosdb`, open it in VS Code and open Copilot chat.
2. Add `.github/copilot-instructions.md` from this repository and install the Live Server extension (`code --install-extension ritwickdey.LiveServer`).
3. Paste prompt 00d and fill in `CosmosAccountName`, `CosmosDatabase` and `FoundryEndpoint` from your dashboard:

```text
Fill in the values from your lab dashboard. They are used in all remaining steps:
COSMOS_ACCOUNT_NAME = "<<CosmosAccountName, e.g. cosmosbc-akxrmfe6rcnty>>"
COSMOS_DATABASE = "<<CosmosDatabase, e.g. cosmosbc>>"
FOUNDRY_ENDPOINT = "<<FoundryEndpoint, e.g. https://cosmosbc-akxrmfe6rcnty.services.ai.azure.com>>"
```

### **Task 2: Discuss the constitution and sign in**

1. Paste prompts 01 and 02. Copilot asks for your hackathon user and a Temporary Access Pass; give it only when asked.

```text
Read the constitution in folder .github. Discuss its main choices and trade-offs with me. Don't deploy anything yet.
```

```text
Prompt for the user account and the TAP key. In the remaining of the hackathon, these accounts will be used to authenticate to Azure and the Foundry and Cosmos DB endpoints. Don't output other users in the chat.
```

💡 The browser-only architecture is a deliberate hackathon shortcut. In production, a backend would hold the Azure access.

### **Task 3: Check connectivity**

1. Paste prompt 03: Copilot lists `chats`, `products` and `test` in your database.

```text
Check for connectivity to Cosmos DB account "<COSMOS_ACCOUNT_NAME from 00d>" (endpoint https://<COSMOS_ACCOUNT_NAME from 00d>.documents.azure.com:443/) and db name "<COSMOS_DATABASE from 00d>". List all containers in database.
```

2. Paste prompt 04: Copilot asks `gpt-4.1-mini` for the capital of France and prints the answer (Paris).

```text
Check for connectivity to Foundry endpoint <FOUNDRY_ENDPOINT from 00d> by asking what is the capital of France using model "gpt-4.1-mini". Use the Entra token with audience https://cognitiveservices.azure.com
```

🔑 **On 401/403** wait a few minutes for RBAC propagation and retry once; the constitution tells Copilot to stop and ask after that.

You successfully completed challenge 1! 🚀🚀🚀
