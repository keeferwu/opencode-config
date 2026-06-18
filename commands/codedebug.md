---
description: Install @debugtalk/opencode-dap plugin for the project
---

# Codedebug Command

Install `@debugtalk/opencode-dap` plugin for a project.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Skip otherwise.

## Configuration

- If `.opencode/opencode.jsonc` does not exist in the project root, create it with:
  ```json
  {
    "$schema": "https://opencode.ai/config.json"
  }
  ```
- If the `plugin` field is missing in `.opencode/opencode.jsonc`, add:
  ```json
  "plugin": [
    "@debugtalk/opencode-dap"
  ]
  ```
- If `plugin` already exists but lacks `@debugtalk/opencode-dap`, merge it into the existing array.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.jsonc` for the changes to take effect.

