---
description: Install/uninstall opencode  plugins for the project
---

# Projectplugin Command

Install or uninstall opencode plugins for a project.

## Instructions for Agent

When the user runs this command (`/projectplugin`), follow these rules:

1. **Arguments** — The arguments are optional.
   - `install <plugin>`: Install plugin.
   - `uninstall <plugin>`: Uninstall plugin.
2. **`<plugin>`** — The plugin name, switch to `@<org>/<repo>`.
   - `dap` → `@debugtalk/opencode-dap`.
   - `ponytail` → `@dietrichgebert/ponytail`.
3. **No arguments** — Only display this field message and exit.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Exit otherwise.

## Install plugin

- If `.opencode/opencode.json` does not exist in the project root, create it with:
  ```json
  {
    "$schema": "https://opencode.ai/config.json"
  }
  ```
- If the `plugin` array field is missing in `.opencode/opencode.json`, add:
  ```json
  "plugin": [

  ]
  ```
- If `plugin` array field already exists but lacks the `@<org>/<repo>`, merge it into the existing array.

## Uninstall plugin

- Read `.opencode/opencode.json`.
- If the `plugin` array contains the `@<org>/<repo>`, remove it.
- If the `plugin` array becomes empty after removal, remove the `plugin` array field entirely.
- If the only remaining field is `$schema`, you may optionally delete the file. Otherwise, save the updated config.
- Skip silently if `.opencode/opencode.json` does not exist.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
