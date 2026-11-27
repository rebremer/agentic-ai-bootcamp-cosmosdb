# Walkthrough Challenge 1 - Connect to Cosmos DB and Foundry

**[Home](../Readme.md)** - [Next Challenge Solution](solution-02.md)

Duration: 20 minutes

## Prerequisites

Please ensure that you verified the [general prerequisites](../Readme.md#prerequisites) before continuing with this challenge.

### **Task 1: Prepare VS Code**

1. Create the folder `bootcamp-cosmosdb`, open it in VS Code and open Copilot chat.
2. Add `.github/copilot-instructions.md` from this repository and install the Live Server extension (`code --install-extension ritwickdey.LiveServer`).
3. Paste prompt 00d from [prompt.txt](../prompt.txt) and fill in `CosmosAccountName`, `CosmosDatabase` and `FoundryEndpoint` from your dashboard.

### **Task 2: Discuss the constitution and sign in**

1. Paste prompts 01 and 02. Copilot asks for your hackathon user and a Temporary Access Pass; give it only when asked.

💡 The browser-only architecture is a deliberate hackathon shortcut. In production, a backend would hold the Azure access.

### **Task 3: Check connectivity**

1. Paste prompt 03: Copilot lists `chats`, `products` and `test` in your database.
2. Paste prompt 04: Copilot asks `gpt-4.1-mini` for the capital of France and prints the answer (Paris).

🔑 **On 401/403** wait a few minutes for RBAC propagation and retry once; the constitution tells Copilot to stop and ask after that.

You successfully completed challenge 1! 🚀🚀🚀
