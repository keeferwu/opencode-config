---
description: Install/uninstall @debugtalk/opencode-dap plugin for the project
---

# Dap Command

Install or uninstall `@debugtalk/opencode-dap` plugin for a project.

## Parameters

- `--uninstall`: Remove `@debugtalk/opencode-dap` from the project configuration.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Skip otherwise.

## Install (default / without `--uninstall`)

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

## Uninstall (with `--uninstall`)

- Read `.opencode/opencode.jsonc`.
- If the `plugin` array contains `@debugtalk/opencode-dap`, remove it.
- If the `plugin` array becomes empty after removal, remove the `plugin` field entirely.
- If the only remaining field is `$schema`, you may optionally delete the file. Otherwise, save the updated config.
- Skip silently if `.opencode/opencode.jsonc` does not exist.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.jsonc` for the changes to take effect.

