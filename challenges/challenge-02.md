# Challenge 2 - Build the chat app

**[Home](../Readme.md)** - [Previous Challenge](challenge-01.md) - [Next Challenge](challenge-03.md)

## Goal

Build a simple chat GUI, first with a mock bot and then connected to the real LLM, with the conversation history stored in Cosmos DB.

## Actions

* Create the folder `chatapp` for all files (prompt 05).
* Create a mock chat in plain HTML, CSS and JavaScript and open it with Live Server (prompt 06).
* Connect the chat to `gpt-4.1-mini` and keep the history in the `chats` container (prompt 07).

## Success criteria

* The chat works on a 400 px-wide screen and with the keyboard only.
* The UI clearly shows whether it uses the mock or the live service.
* Answers come from the real LLM and follow-up questions use the earlier conversation.
* Chat history is visible in the `chats` container of your database.
* Stopping a response does not create an empty assistant message.

## Learning resources

* [Azure Cosmos DB for NoSQL REST API](https://learn.microsoft.com/en-us/rest/api/cosmos-db/)
* [Azure OpenAI chat completions](https://learn.microsoft.com/en-us/azure/ai-services/openai/reference)
