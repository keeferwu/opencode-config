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

## Install plugin

Run bash command:

```bash
opencode plugin @<org>/<repo>@latest --force
```

`@<org>/<repo>` is provided by `/project-plugin` argument.

## Uninstall plugin

- If `.opencode/opencode.json` does not exist, skip silently.
- Read `.opencode/opencode.json`.
  - If the `plugin` array contains the `@<org>/<repo>`, remove it.
  - If the `plugin` array becomes empty after removal, remove the `plugin` array field entirely.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
