# Walkthrough Challenge 2 - Build the chat app

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-01.md) - [Next Challenge Solution](solution-03.md)

Duration: 20 minutes

## Prerequisites

Please ensure that you successfully completed [challenge 1](../challenges/challenge-01.md) before continuing.

### **Task 1: Mock chat**

1. Paste prompts 05 and 06 from [prompt.txt](../prompt.txt). Copilot creates `chatapp` with a mock bot and gives you a Live Server URL.
2. Open the URL and check keyboard use and a 400 px-wide window.

### **Task 2: Live chat with history**

1. Paste prompt 07. Copilot connects the chat to `gpt-4.1-mini` and stores each conversation in the `chats` container (partition key `/sessionId`).
2. Ask a question and a follow-up, then reload the page and check that the history is in Cosmos DB.

💡 Access tokens live in a git-ignored file (`chatapp/config.local.js`); never commit it.

You successfully completed challenge 2! 🚀🚀🚀
