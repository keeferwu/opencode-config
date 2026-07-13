---
description: Install/uninstall opencode plugins to project
---

# Project-plugin Command

Install or uninstall opencode plugins to project's opencode config.

## Arguments for command

When the user runs this command (`/project-plugin`), follow these rules:

1. **No $ARGUMENTS** — Only display the argument list(`Argument requirements`,`<plugin>`) and stop.
2. **Argument requirements** — Proceed based on the arguments:
   - `install <plugin>`: Install plugin.
   - `uninstall <plugin>`: Uninstall plugin.
3. **`<plugin>`** — The plugin name, switch to `@<org>/<repo>`.
   - `dap` → `@debugtalk/opencode-dap`.
   - `ponytail` → `@dietrichgebert/ponytail`.

## Install plugin

Run bash command:

```bash
opencode plugin @<org>/<repo> --force
```

`@<org>/<repo>` is provided by `/project-plugin` argument.

## Uninstall plugin

- If `.opencode/opencode.json` does not exist, skip silently.
- Read `.opencode/opencode.json`.
  - If the `plugin` array contains the `@<org>/<repo>`, remove it.
  - If the `plugin` array becomes empty after removal, remove the `plugin` array field entirely.

## Post-configuration

**Restart opencode** after modifying `.opencode/opencode.json` for the changes to take effect.
