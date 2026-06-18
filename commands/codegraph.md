---
description: Initialize or update project code knowledge graph
---

# CodeGraph Command

Initialize or update the codegraph for a project

## Precondition

Only run if the project contains `AGENTS.md` or `.opencode/AGENTS.md` in its root directory. Skip otherwise.

## Instructions

1. **Check if codegraph is installed**:
   - Run `command -v codegraph || which codegraph 2>/dev/null` to verify installation
   - If not found, install it: `sudo npm install -g @opencode/codegraph`

2. **Run or update the index**:
   - If `.codegraph/` directory exists in the project root: dispatch a subagent to run `codegraph sync`
   - Otherwise: dispatch a subagent to run `codegraph init -i`
   - The subagent must fully complete the task, do not return early or timeout
   - Since the default bash timeout (120s) is insufficient for large projects:
    - Pass an explicit `timeout` of **1800000ms** (30 minutes) to the `codegraph sync` bash call
    - Pass an explicit `timeout` of **18000000ms** (5 hours) to the `codegraph init -i` bash call
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

4. **Ensure AGENTS.md has CodeGraph instructions**:
   - Check whether `AGENTS.md` or `.opencode/AGENTS.md` already contains the CodeGraph usage block (look for `CODEGRAPH_START` marker)
   - If the block is missing, append the following content to the file:
     ```
     <!-- CODEGRAPH_START -->
     ## CodeGraph

     In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

     - **MCP tools** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them. `codegraph_node` returns one symbol's source + callers, or reads a whole file with line numbers. If the tools are listed but deferred, load them by name via tool search.
     - **Shell** (always works): `codegraph explore "<symbol names or question>"` and `codegraph node <symbol-or-file>` print the same output.

     If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
     <!-- CODEGRAPH_END -->
     ```
   - If neither `AGENTS.md` nor `.opencode/AGENTS.md` exists, skip this step

5. **Report status**:
   - Show a summary of what was done (initialized or synced, `.opencode/opencode.jsonc` created/modified, AGENTS.md updated)
   - Mention that the work was delegated to a subagent and it completed successfully
   - Mention that `/codegraph` can be re-run later to update the index
