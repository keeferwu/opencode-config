---
description: Initialize or update project code knowledge graph
---

# CodeGraph Command

Initialize or update the codegraph knowledge graph for a project

## Precondition

Only run CodeGraph if the project contains `AGENTS.md` or `.opencode/AGENTS.md` in its root directory. Skip otherwise.

## Instructions

1. **Check if codegraph is installed**:
   - Run `command -v codegraph || which codegraph 2>/dev/null` to verify installation
   - If not found, install it:
     - Try `npx @colbymchenry/codegraph` first (zero-install via npm)
     - If that fails, try the direct install script: `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh`

2. **Run or update the index**:
   - If `.codegraph/` directory exists in the project root: run `codegraph sync`
   - Otherwise: run `codegraph init -i`
   - Wait for the command to complete

3. **Ensure codegraph MCP server is configured**:
   - If `.opencode/opencode.json` not exists in the project root, create it with:
     ```json
     {
       "$schema": "https://opencode.ai/config.json"
     }
     ```
   - If `mcp` field is missing in `.opencode/opencode.json`, add:
     ```json
     "mcp": {
       "codegraph": {
         "type": "local",
         "command": [
           "codegraph",
           "serve",
           "--mcp",
           "--no-watch"
         ],
         "enabled": true
       }
     }
     ```
   - If `mcp` already exists but lacks `codegraph`, merge into the existing `mcp` object

4. **Report status**:
   - Show a summary of what was done (initialized or synced, .opencode/opencode.json created/modified)
   - Mention that `/codegraph` can be re-run later to update the index
