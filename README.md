# Agentic AI bootcamp: build a bike store website with GitHub Copilot

In this bootcamp you build **Summit & Spoke**, an outdoor and bike store website with an AI gear expert, in Visual Studio Code with GitHub Copilot (GHCP). You do not write the code yourself: you steer Copilot with two files.

| File | What it is |
|---|---|
| [`.github/copilot-instructions.md`](.github/copilot-instructions.md) | The **instructions** (the "constitution"). Copilot reads it automatically in every chat. It sets the guardrails: plain HTML, CSS and JavaScript, no backend, protect credentials, build one step at a time, and how to connect to Azure. |
| [`prompt.txt`](prompt.txt) | The **prompts**. Numbered steps that you paste into Copilot chat one at a time, in order. |

## How it works

1. Copilot follows the instructions file for the whole session, so every step stays within the same rules.
2. You paste the next prompt from `prompt.txt` into Copilot chat.
3. Copilot builds it, tests it and reports what changed. You check the result in the browser before moving on.

## What you build

The prompts take you from an empty folder to a working store:

1. **Set up:** create the `chatapp` folder and install the Live Server extension in VS Code.
2. **Connectivity:** sign in with your hackathon account and check access to Azure Cosmos DB and the model endpoint in Azure API Management.
3. **Chat:** a mock chat first, then connected to the real LLM, with the conversation history stored in Cosmos DB.
4. **Product store:** vectorize the product file `products.sample.json` into Cosmos DB, and add `CosmosDBadmin.html` to inspect containers, chat history and embeddings.
5. **RAG:** connect the chat to the vectorized products so you can ask questions about the catalog (retrieval-augmented generation).
6. **Polish:** make the site look like a real outdoor and bike store.

## Prerequisites

- Visual Studio Code with GitHub Copilot (agent mode).
- The Live Server extension (`ritwickdey.LiveServer`).
- The hackathon user account and Temporary Access Pass you receive from the organizers. Copilot asks for them in step 02.

## Run it

1. Open this folder in VS Code and open Copilot chat.
2. Paste the prompts from `prompt.txt` one by one, checking each result before the next.
3. Open `chatapp/index.html` with Live Server (right-click, **Open with Live Server**).

## Good to know

- Everything runs locally in the browser. Nothing is deployed to Azure.
- Access tokens are short-lived and kept in a git-ignored file (`chatapp/config.local.js`). Never commit credentials.
- Direct browser access to Azure services is fine for this controlled bootcamp, but it is not a production architecture.
