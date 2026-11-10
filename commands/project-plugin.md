---
description: Install/uninstall opencode plugins to project
agent: build
model: opencode/big-pickle
---

# Project-plugin Command

Install or uninstall opencode plugins to project's opencode config.

## Instructions for Agent

When the user runs this command (`/project-plugin`), follow these rules:

1. **No arguments** — Read `.opencode/opencode.json[c]` via the `read` tool:
   - If file exists, list the current `plugins` array contents, then display the `Arguments` and `<plugin>` sections below and stop.
   - If file does not exist, directly display the `Arguments` and `<plugin>` sections below and stop.
   - Do NOT perform any other operations.
2. **Arguments** — Proceed based on the arguments:
   - `install <plugin>`: Install plugin.
   - `uninstall <plugin>`: Uninstall plugin.
3. **`<plugin>`** — The plugin reference, resolve aliases first. Accepted forms:
   - Aliases:
     - `graphify` → `graphify local plugin`
     - `context-mode` → `context-mode`
     - `omo-slim` → `oh-my-opencode-slim`
     - `ponytail` → `@dietrichgebert/ponytail`
     - `superpowers` → `superpowers@git+https://github.com/obra/superpowers.git`
   - Forms after resolution:
     - `graphify` — local plugin (special handling).
     - `<name>` — unscoped npm package, e.g. `context-mode`, `oh-my-opencode-slim`.
     - `@<org>/<repo>` — scoped plugin, e.g. `@dietrichgebert/ponytail`.
     - `<name>@<spec>` — named plugin with version or git spec, e.g. `superpowers@git+https://github.com/obra/superpowers.git`.

## Install plugin

Run bash command:

For `graphify`:
If `graphify` command is available, install by command:
```bash
graphify install --project --platform opencode
```
Local plugin do not need to be explicitly declared, so remove `.opencode/plugins/graphify.js` from `.opencode/opencode.json[c]` plugins array.
Move the graphify section from `AGENTS.md` to `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is exists before moving, append to the end of file.

For `<name>`, `@<org>/<repo>`, `<name>@<spec>` form plugins:
Add the resolved reference as an entry of the `plugins` array in `.opencode/opencode.json[c]`. If the file does not exist, create it:
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    "context-mode",
    "oh-my-opencode-slim",
    "@dietrichgebert/ponytail",
    "superpowers@git+https://github.com/obra/superpowers.git"
  ]
}
```
Do NOT use `opencode plugin add <ref>` here: it installs to the global config (`~/.config/opencode/opencode.json[c]`), not the project. Only use it if the user explicitly wants a global install. It has no `--force` flag.

## Uninstall plugin

For `graphify`:
If `graphify` command is available, remove by command:
```bash
graphify uninstall --project --platform opencode
```
Remove the graphify section from `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is empty after removal, delete the file.

For `<name>`, `@<org>/<repo>`, `<name>@<spec>`, and other npm package plugins:
- If `.opencode/opencode.json[c]` does not exist, skip silently.
- Read `.opencode/opencode.json[c]`.
  - If the `plugins` array contains the resolved reference, remove it.
  - If the `plugins` array becomes empty after removal, remove the `plugins` field entirely.

## Post-configuration

Config reloads automatically; tell the user to run `/reload` only if the plugin does not appear.
