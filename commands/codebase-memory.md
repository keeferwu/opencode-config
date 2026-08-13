---
description: Initialize project codebase knowledge graph
---

# Codebase-memory Command

Initialize the codebase knowledge graph for a project.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Skip otherwise.

## Instructions

1. **Check installation**:
   - Run `command -v codebase-memory-mcp` to verify
   - If not found: `sudo npm install -g codebase-memory-mcp`

2. **Ensure codebase-memory-mcp server is configured**:
   - Read `.opencode/opencode.json`.
   - If `.opencode/opencode.json` not exists in the project root, create it with:
     ```json
     {
       "$schema": "https://opencode.ai/config.json"
     }
     ```
   - If `mcp` field is missing in `.opencode/opencode.json`, add:
     ```json
     "mcp": {
        "codebase-memory-mcp": {
           "enabled": true,
           "type": "local",
           "command": [
              "codebase-memory-mcp"
           ]
        }
     }
     ```
   - If `mcp` already exists but lacks `codebase-memory-mcp`, merge into the existing `mcp` object

3. **Index codebase**:
   - After configuration is verified (steps 1-3 done), dispatch a subagent to index the codebase
   - Launch subagent with terminal timeout of 10min
   - The subagent executes: `codebase-memory-mcp cli index_repository '{"repo_path":"'$(pwd)'"'`
   - After completion, the subagent returns the execution result (success/failure + output) to the main agent

4. **Report status**:
   - Show a summary of what was done (`.opencode/opencode.json` created/modified, index result)
   - Remind the user to restart opencode to pick up the new configuration
