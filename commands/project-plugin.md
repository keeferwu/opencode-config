---
description: Install/uninstall opencode plugins to project
agent: build
model: opencode/big-pickle
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
3. **`<plugin>`** — The plugin reference, resolve aliases first. Three accepted forms:
   - Aliases:
     - `dap` → `@debugtalk/opencode-dap`
     - `ponytail` → `@dietrichgebert/ponytail`
     - `omo` → `oh-my-openagent@latest`
     - `superpowers` → `superpowers@git+https://github.com/obra/superpowers.git`
     - `graphify` → `graphify local plugin`
   - Forms after resolution:
     - `graphify` — local plugin (special handling).
     - `@<org>/<repo>` — scoped plugin, e.g. `@debugtalk/opencode-dap`, `@dietrichgebert/ponytail`.
     - `<name>@<spec>` — named plugin with version or git spec, e.g. `oh-my-openagent@latest`, `superpowers@git+https://github.com/obra/superpowers.git`.

## Install plugin

Run bash command:

For `graphify`:
If `graphify` command is available, install by command:
```bash
graphify install --project --platform opencode
```
Local plugin do not need to be explicitly declared, so remove `.opencode/plugins/graphify.js` from `.opencode/opencode.json` plugin array.
Move the graphify section from `AGENTS.md` to `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is exists before moving, append to the end of file.

For `@<org>/<repo>` plugins:
```bash
opencode plugin @<org>/<repo>@latest --force
```

For `<name>@<spec>` plugins:
```bash
opencode plugin <name>@<spec> --force
```
Do not append `@latest` to a spec that already contains one (or a `git+` URL).

## Uninstall plugin

For `graphify`:
If `graphify` command is available, remove by command:
```bash
graphify uninstall --project --platform opencode
```
Remove the graphify section from `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is empty after removal, delete the file.

For `@<org>/<repo>` or `<name>@<spec>` plugins:
- If `.opencode/opencode.json` does not exist, skip silently.
- Read `.opencode/opencode.json`.
  - If the `plugin` array contains the resolved reference, remove it.
  - If the `plugin` array becomes empty after removal, remove the `plugin` array field entirely.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
