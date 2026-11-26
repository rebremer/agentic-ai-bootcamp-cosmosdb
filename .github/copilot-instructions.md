# Cosmos Copilot Constitution

Discuss and agree on this constitution before building anything. It defines the guardrails for the hackathon; later prompts define the implementation details.

## 1. Goal

Build **Cosmos Copilot**, a simple chat app that:

- answers questions about an outdoor and bike product catalog;
- uses a Microsoft Foundry embeddings model and LLM model that is exposed via Foundry endpoints;
- uses Azure Cosmos DB for chat history and product vector search;
- supports follow-up questions with retrieval-augmented generation (RAG).
- the solution shall be built locally in a new chatapp folder. Nothing is deployed to Azure, this constitution lives in ./.github/copilot-instructions.md

## 2. Keep it simple

- Use plain HTML, CSS, and JavaScript.
- Do not add a backend, framework, package manager, or build step.
- Run the app locally with VS Code Live Server. Do not start any other web server (Python, Node, etc.). If Live Server cannot be started from the chat, ask the user to open `index.html` with Live Server and give the URL.
- Build only what the current hackathon step requests.

These constraints are intentional: the hackathon focuses on prompting, AI integration, Cosmos DB, and RAG rather than application scaffolding.

## 3. Work incrementally

Each step must:

1. preserve the behavior completed in earlier steps;
2. be tested before moving on;
3. report what changed and what was checked;
4. stop and ask when a requirement is unclear.

Do not implement later features early.

## 4. Protect credentials and data

- Never hardcode, display, log, or commit credentials.
- Keep local configuration and tokens in git-ignored files.
- Use only the hackathon identity given in step 02 for all Azure actions (CLI, REST, and tools). Never output other accounts in the chat.
- Before any Azure action, verify the active identity. Do not use other accounts, tenants, or subscriptions cached on the machine, even to search for resources.
- If a resource isn't reachable as the hackathon user, stop and ask. Don't switch identities or look elsewhere.
- Ask for a Temporary Access Pass only when sign-in is required; never save it.
- Render user, model, and product text safely as text, not as HTML.

Direct browser access to Azure services is allowed only for this controlled hackathon environment. It is not the recommended production architecture.

## 5. Create the service clients yourself

- Create Cosmos DB and Foundry clients yourself and add them to the solution folder.
- Show service errors clearly; do not hide failures or silently fall back.
- Keep Cosmos DB queries bounded because browser-based queries cannot use continuation tokens.

## 6. User experience

The app must remain:

- understandable at each stage, starting with a mock chat;
- accessible by keyboard;
- usable on a 400 px-wide screen;
- clear about whether it is using mock or live services;
- concise and helpful in its answers.

Stopping a response must not create an empty assistant message. If part of the answer was already generated, keep that partial answer.

## 7. Definition of done

A step is done when:

- the requested behavior works in a real browser;
- earlier behavior still works;
- expected errors are visible and understandable;
- no credentials were exposed;
- the changed files and checks are summarized.

## 8. How to connect

Endpoints and audiences come from the prompts. Use the hackathon identity's Entra token only; no keys.

- **Cosmos DB:** token with `az account get-access-token --resource https://cosmos.azure.com`. REST header: `Authorization: type=aad&ver=1.0&sig=<token>` (URL-encoded), plus `x-ms-version: 2018-12-31` and `x-ms-date`. The database name is the username without the `hack` prefix. Containers are pre-created; this identity can read and write data but cannot create containers.
- **Foundry (Azure OpenAI):** token with `az account get-access-token --resource https://cognitiveservices.azure.com`, sent as `Authorization: Bearer <token>`. No API key. Call `POST <foundry endpoint>/openai/deployments/<deployment>/chat/completions?api-version=2024-10-21`. For embeddings call `POST <foundry endpoint>/openai/deployments/<embeddings deployment>/embeddings?api-version=2024-10-21`. `<foundry endpoint>` is the bare host from the prompt, without a `/openai` suffix.
- **On 401/403:** retry at most once, then stop and ask. Do not guess audiences, paths, or accounts.
- **Output:** show only status codes and answers, never tokens. Run commands that may prompt or hang with a timeout.

## Agreement

Before coding, discuss:

1. Why are we using a browser-only architecture?
2. Which shortcuts are acceptable for a hackathon but not for production?
3. Why do we build and verify one step at a time?
4. Are there any rules the team wants to change?

Continue only after the team accepts the constitution.