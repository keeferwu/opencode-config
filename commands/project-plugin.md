---
description: Install/uninstall opencode plugins to project
agent: build
model: opencode/big-pickle
---

# Project-plugin Command

Install or uninstall opencode plugins and project tooling integrations in a project.

## Instructions for Agent

When the user runs this command (`/project-plugin`), follow these rules:

1. **No arguments** — Read `.opencode/opencode.json[c]` via the `read` tool:
   - If file exists, list the current `plugins` array contents, then display the `Arguments` and `<plugin>` sections below and stop.
   - If file does not exist, directly display the `Arguments` and `<plugin>` sections below and stop.
   - Do NOT perform any other operations.
2. **Arguments** — Proceed based on the arguments:
   - `install <plugin>`: Install plugin or project tooling.
   - `uninstall <plugin>`: Uninstall plugin or project tooling.
   - If `<plugin>` is a project tooling alias (`codegraph`, `openspec`, `speckit`), follow the `Install/Uninstall project tooling` sections; otherwise follow the plugin sections.
3. **`<plugin>`** — The plugin reference, resolve aliases first. Accepted forms:
   - Project tooling aliases (installed into the current project, never written to the `plugins` array):
     - `codegraph` → project-local CodeGraph MCP server plus `.codegraph/` index
     - `openspec` → OpenSpec shared skills
     - `speckit` → Spec Kit commands and runtime plugin
   - Plugin aliases:
     - `graphify` → `graphify local plugin`
     - `context-mode` → `context-mode`
     - `ponytail` → `@dietrichgebert/ponytail`
     - `superpowers` → `superpowers@git+https://github.com/obra/superpowers.git`
   - Forms after resolution:
     - `graphify` — local plugin (special handling).
     - `<name>` — unscoped npm package, e.g. `context-mode`.
     - `@<org>/<repo>` — scoped plugin, e.g. `@dietrichgebert/ponytail`.
     - `<name>@<spec>` — named plugin with version or git spec, e.g. `superpowers@git+https://github.com/obra/superpowers.git`.

## Install project tooling

Resolve project tooling aliases here; everything else continues in the next section.
These commands install and register the tooling and generate its project data (`.codegraph/`, `openspec/`, `.specify/`). Do NOT add them to the `plugins` array.

### codegraph

Requires the `codegraph` CLI. If it is missing, stop and ask the user to install it first. Run from the project root:

```bash
codegraph install --target=opencode --location=local --yes
codegraph init .
```

- `--location=local` writes the MCP server config and instructions into this project instead of the global config. Omit `--yes` to answer the installer prompts interactively.
- `codegraph init .` actively builds the `.codegraph/` index for this project. Indexing a large repository can take a long time, so run this command with the command timeout disabled (`timeout: 0` in the bash tool) and do not interrupt it early.

### openspec

Requires the `openspec` CLI. If it is missing, stop and ask the user to install it first. Run from the project root:

```bash
openspec init --tools opencode
```

OpenSpec 2.0 installs skills only. It actively generates the shared skill set at `.agents/skills/openspec-*` and the `openspec/` directory for specs and changes; it no longer writes slash-command files under `.opencode/`.

### speckit

Requires the `specify` CLI. If it is missing, stop and ask the user to install it first. Run from the root of an existing project:

```bash
specify init --here --force --integration opencode --non-interactive
```

Commit or stash existing work first, then review the diff: `--here` targets the current directory and `--force` allows initialization in a non-empty directory, replacing files at conflicting managed paths. It does not rewrite the rest of the application or infer specs for existing behavior. `--non-interactive` keeps the agent from hanging on the script-type picker.

This writes `.specify/`, `.opencode/commands/speckit-*.md`, `.opencode/plugin/speckit-events.ts`, and merges its plugin reference into `.opencode/opencode.json[c]`.

## Install plugin

### graphify

Requires the `graphify` CLI. If it is missing, stop and ask the user to install it first, then run:
```bash
graphify install --project --platform opencode
```
Local plugin do not need to be explicitly declared, so remove `.opencode/plugins/graphify.js` from `.opencode/opencode.json[c]` plugins array.
Move the graphify section from `AGENTS.md` to `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is exists before moving, append to the end of file.

### npm package plugins

For `<name>`, `@<org>/<repo>`, `<name>@<spec>` forms, add the resolved reference as an entry of the `plugins` array in `.opencode/opencode.json[c]`. If the file does not exist, create it:
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    "context-mode",
    "@dietrichgebert/ponytail",
    "superpowers@git+https://github.com/obra/superpowers.git"
  ]
}
```
Do NOT use `opencode plugin add <ref>` here: it installs to the global config (`~/.config/opencode/opencode.json[c]`), not the project. Only use it if the user explicitly wants a global install. It has no `--force` flag.

## Uninstall project tooling

Uninstall the tool and remove the data it generated. Run `git status --short` first, review the paths, and back up anything written by hand before deleting.

### codegraph

```bash
codegraph uninstall --target=opencode --keep-cli  --location=local --yes
codegraph uninit . --force
```
- `codegraph uninstall` strips the MCP server config, instructions section, and permissions from this project's agent config. `--keep-cli` keeps the global CLI; drop it to remove the CLI too.
- `codegraph uninit` removes the project index and `.codegraph/` data; `--force` skips the prompt.

### openspec

```bash
rm -rf .agents/skills/openspec-*
rm -rf openspec/
```

OpenSpec has no project uninstall command. Remove the shared skills under `.agents/skills/` and the `openspec/` directory created by `openspec init`. Back up any hand-written specs or change proposals first if they must be kept.

### speckit

```bash
specify integration uninstall opencode --force
rm -rf .specify/
```

- `specify integration uninstall` removes `.opencode/commands/speckit-*.md` and the `speckit-events` plugin reference using its manifest; `--force` also removes generated files that were modified, while without it those files are kept and reported.
- `rm -rf .specify/` removes the constitution, specs, plans, and tasks generated by `specify init`. Back them up first if they must be kept.
- If `.opencode/opencode.json[c]` still references `speckit-events`, remove that entry manually.

## Uninstall plugin

### graphify

Remove by command:
```bash
graphify uninstall --project --platform opencode
```
Remove the graphify section from `.opencode/AGENTS.md`. If `.opencode/AGENTS.md` is empty after removal, delete the file.

### npm package plugins

For `<name>`, `@<org>/<repo>`, `<name>@<spec>`, and other npm package plugins:
- If `.opencode/opencode.json[c]` does not exist, skip silently.
- Read `.opencode/opencode.json[c]`.
  - If the `plugins` array contains the resolved reference, remove it.
  - If the `plugins` array becomes empty after removal, remove the `plugins` field entirely.

## Post-configuration

Config reloads automatically; tell the user to run `/reload` only if the plugin does not appear.
`codegraph`, `openspec`, and `speckit` change skills, commands, MCP servers, and plugins, so tell the user to restart opencode after installing or removing them; `/reload` alone does not pick up new MCP servers or skills.
