# Challenge 1 - Connect to Cosmos DB and Foundry

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

## Goal

Set up VS Code with GitHub Copilot, agree on the guardrails in the constitution and verify that you can reach your own Cosmos DB account and Foundry model endpoint with your Entra identity.

## Actions

* Create a new folder `bootcamp-cosmosdb`, open it in VS Code and open Copilot chat (prompts 00a-00b).
* Download `.github/copilot-instructions.md` from this repository into the folder `.github`.
* Install the Live Server extension (`ritwickdey.LiveServer`).
* Fill in the values from your lab dashboard (prompt 00d).
* Paste prompts 01-04 from [prompt.txt](../prompt.txt) one by one: read the constitution, sign in, list the Cosmos DB containers and ask `gpt-4.1-mini` for the capital of France.

## Success criteria

* You discussed the constitution with Copilot and understand why the app is browser-only.
* Copilot lists the containers `chats`, `products` and `test` in your database.
* Copilot gets an answer from `gpt-4.1-mini` through your Foundry endpoint.
* No token or credential was shown in the chat or saved in a committed file.

## Learning resources

* [Azure Cosmos DB role-based access control](https://learn.microsoft.com/en-us/azure/cosmos-db/role-based-access-control)
* [Azure OpenAI in Foundry Models with Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/managed-identity)
