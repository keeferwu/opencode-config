---
description: Install/uninstall opencode plugins for the project
---

# Project-plugin Command

Install or uninstall opencode plugins in the project's `.opencode/opencode.json`.

## Arguments for command

When the user runs this command (`/project-plugin`), follow these rules:

1. **Arguments** — The arguments are optional.
   - `install <plugin>`: Install plugin.
   - `uninstall <plugin>`: Uninstall plugin.
2. **`<plugin>`** — The plugin name, switch to `@<org>/<repo>`.
   - `dap` → `@debugtalk/opencode-dap`.
   - `ponytail` → `@dietrichgebert/ponytail`.
3. **No arguments** — Only display argument message and exit.

## Precondition

Only run if the project root contains `.opencode/opencode.json`. Otherwise ask user whether to create the file (with `{ "$schema": "https://opencode.ai/config.json" }`) or not.

## Install plugin

- Read `.opencode/opencode.json`.
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
- Skip silently if `.opencode/opencode.json` does not exist.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
