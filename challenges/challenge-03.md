# Challenge 03: Build the product store with RAG

**[Home](../Readme.md)** - [Previous Challenge](challenge-02.md) - [Next Challenge](challenge-04.md)

## Goal

Vectorize the product catalog into Cosmos DB and use it to answer questions with retrieval-augmented generation (RAG).

## Actions

* Vectorize `products.sample.json` with `text-embedding-3-small` and store it in the `products` container (prompt 08).
* Create `CosmosDBadmin.html` to inspect the containers, their configuration, chats and products (prompt 09).
* Connect the chat to the vectorized products so you can ask questions about the catalog (prompt 10).

## Success criteria

* Every product in the `products` container has a 1536-dimensional `embedding`.
* `CosmosDBadmin.html` shows the `chats` and `products` containers and their configuration.
* Questions about the catalog are answered from retrieved products, and follow-up questions work.
* Cosmos DB queries are bounded and service errors are shown clearly.

## Learning resources

* [Vector search in Azure Cosmos DB for NoSQL](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/vector-search)
* [Embeddings with Azure OpenAI](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/embeddings)
