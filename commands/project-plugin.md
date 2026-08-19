---
description: Install/uninstall opencode plugins to project
---

# Project-plugin Command

Install or uninstall opencode plugins to project's opencode config.

## Instructions for Agent

When the user runs this command (`/project-plugin`), follow these rules:

1. **No arguments** — Read `.opencode/opencode.json` via the `read` tool:
   - If file exists, list the current `plugin` array contents, then display the `Arguments` and `<plugin>` sections below and stop.
   - If file does not exist, directly display the `Arguments` and `<plugin>` sections below and stop.
   - Do NOT perform any other operations.
2. **Arguments** — Proceed based on the arguments:
   - `install <plugin>`: Install plugin.
   - `uninstall <plugin>`: Uninstall plugin.
3. **`<plugin>`** — The plugin name, switch to `@<org>/<repo>`.
   - `dap` → `@debugtalk/opencode-dap`.
   - `ponytail` → `@dietrichgebert/ponytail`.
   - `graphify` → `graphify local plugin`.

## Install plugin

Run bash command:

For `graphify`:
If `graphify` command is available, install by command:
```bash
graphify install --project --platform opencode
```
Local plugin do not need to be explicitly declared, so remove `.opencode/plugins/graphify.js` from `.opencode/opencode.json` plugin array.
Move the graphify section from `AGENTS.md` to `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is not empty before moving, append to the end of file.

For `@<org>/<repo>` plugins:
```bash
opencode plugin @<org>/<repo>@latest --force
```

## Uninstall plugin

For `graphify`:
If `graphify` command is available, remove by command:
```bash
graphify uninstall --project --platform opencode
```
Remove the graphify section from `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is empty after removal, delete the file.

For `@<org>/<repo>` plugins:
- If `.opencode/opencode.json` does not exist, skip silently.
- Read `.opencode/opencode.json`.
  - If the `plugin` array contains the `@<org>/<repo>`, remove it.
  - If the `plugin` array becomes empty after removal, remove the `plugin` array field entirely.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
