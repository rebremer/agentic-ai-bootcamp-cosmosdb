# Walkthrough Challenge 3 - Build the product store with RAG

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-02.md) - [Next Challenge Solution](solution-04.md)

Duration: 20 minutes

## Prerequisites

Please ensure that you successfully completed [challenge 2](../challenges/challenge-02.md) before continuing.

### **Task 1: Vectorize the products**

1. Paste prompt 08 from [prompt.txt](../prompt.txt). Copilot embeds every product in [products.sample.json](../products.sample.json) with `text-embedding-3-small` and writes it to the `products` container.

💡 The container has a 1536-dimensional cosine vector index on `/embedding`, partition key `/category`. Copilot cannot create containers, so they were pre-created by the lab automation.

### **Task 2: Inspect the containers**

1. Paste prompt 09 and open `CosmosDBadmin.html` with Live Server. Check the configuration of `chats` and `products` and the stored items.

### **Task 3: Ask questions about the catalog**

1. Paste prompt 10 and ask for a product, for example a warm jacket for cycling, then a follow-up about price or size.

🔑 **Key to RAG:** the question is embedded, the closest products are retrieved with a bounded vector query, and they are added to the LLM prompt.

You successfully completed challenge 3! 🚀🚀🚀
