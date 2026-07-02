---
description: Initialize project codebase knowledge graph
---

# Codebase Command

Initialize the codebase knowledge graph for a project.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Skip otherwise.

## Instructions

1. **Check installation**:
   - Run `command -v codebase-memory-mcp` to verify
   - If not found: `sudo npm install -g codebase-memory-mcp`

2. **Ensure codebase-memory-mcp server is configured**:
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

3. **Ensure AGENTS.md has codebase-memory-mcp instructions**:
   - Check whether `AGENTS.md` or `.opencode/AGENTS.md` already contains the codebase-memory-mcp usage block (look for `codebase-memory-mcp:start` marker)
   - If the block is missing, append the following content to the file:
     ```
     <!-- codebase-memory-mcp:start -->
     # Codebase Knowledge Graph (codebase-memory-mcp)

     This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
     ALWAYS prefer MCP graph tools over grep/glob/file-search for code discovery.

     ## Priority Order
     1. `search_graph` — find functions, classes, routes, variables by pattern
     2. `trace_path` — trace who calls a function or what it calls
     3. `get_code_snippet` — read specific function/class source code
     4. `query_graph` — run Cypher queries for complex patterns
     5. `get_architecture` — high-level project summary

     ## When to fall back to grep/glob
     - Searching for string literals, error messages, config values
     - Searching non-code files (Dockerfiles, shell scripts, configs)
     - When MCP tools return insufficient results

     ## Examples
     - Find a handler: `search_graph(name_pattern=".*OrderHandler.*")`
     - Who calls it: `trace_path(function_name="OrderHandler", direction="inbound")`
     - Read source: `get_code_snippet(qualified_name="pkg/orders.OrderHandler")`
     <!-- codebase-memory-mcp:end -->
     ```
   - If neither `AGENTS.md` nor `.opencode/AGENTS.md` exists, skip this step

4. **Index codebase**:
   - After configuration is verified (steps 1-3 done), dispatch a subagent to index the codebase
   - Launch subagent with terminal timeout of 10min
   - The subagent executes: `codebase-memory-mcp cli index_repository '{"repo_path":"'$(pwd)'"'`
   - After completion, the subagent returns the execution result (success/failure + output) to the main agent

5. **Report status**:
   - Show a summary of what was done (`.opencode/opencode.json` created/modified, AGENTS.md updated, index result)
   - Remind the user to restart opencode to pick up the new configuration
