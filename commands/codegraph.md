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
   - If `.codegraph/` directory exists in the project root: dispatch a subagent to run `codegraph sync`
   - Otherwise: dispatch a subagent to run `codegraph init -i`
   - The subagent must fully complete the task, do not return early or timeout
   - Since the default bash timeout (120s) is insufficient for large projects:
    - Pass an explicit `timeout` of **1800000ms** (0.5 hours) to the `codegraph sync` bash call
    - Pass an explicit `timeout` of **9000000ms** (2.5 hours) to the `codegraph init -i` bash call
   - If even 2 hours is insufficient, use `codegraph init` (without `-i`) which is faster but indexes fewer relationships, then follow up with `codegraph sync` to catch remaining files.

3. **Ensure codegraph MCP server is configured**:
   - If `.opencode/opencode.jsonc` not exists in the project root, create it with:
     ```json
     {
       "$schema": "https://opencode.ai/config.json"
     }
     ```
   - If `mcp` field is missing in `.opencode/opencode.jsonc`, add:
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
   - Show a summary of what was done (initialized or synced, `.opencode/opencode.jsonc` created/modified)
   - Mention that the work was delegated to a subagent and it completed successfully
   - Mention that `/codegraph` can be re-run later to update the index
