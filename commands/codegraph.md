---
description: Initialize project code knowledge graph
---

# CodeGraph Init Command

Use codegraph create pre-indexed code knowledge graph for a project

## Precondition

Only initialize CodeGraph if the project contains `AGENTS.md` or `AGENT.md` in its root directory. Skip otherwise.

## Instructions

1. **Check if codegraph is installed**:
   - Run `command -v codegraph || which codegraph 2>/dev/null` to verify installation
   - If not found, install it:
     - Try `npx @colbymchenry/codegraph` first (zero-install via npm)
     - If that fails, try the direct install script: `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh`

2. **Initialize the project**:
   - Run `codegraph init -i` in the current working directory
   - If the project already has a `.codegraph/` directory, confirm with the user before re-indexing
   - Wait for indexing to complete and report the result

3. **Report status**:
   - Show a summary of what was initialized
   - Mention that `/codegraph` can be re-run later to update the index
