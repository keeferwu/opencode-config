---
description: Add/remove references to project
agent: build
model: opencode/big-pickle
---

# Project-reference Command

Add, remove, or list references to the project's opencode config.

## Arguments for command

Arguments: `$ARGUMENTS`

The command accepts an optional action argument that selects which sub-action to run. Determine `<action>` FIRST, before collecting any other input:

- `/project-reference add` — add a new reference (collects name, type, path/repository, branch, description)
- `/project-reference remove` — remove an existing reference (collects name only)
- `/project-reference list` — list configured references (no further input needed)
- No action argument — ask the user to choose `add`, `remove`, or `list` via the `question` tool before collecting any other input.

Only collect the fields the chosen `<action>` requires (see ## Input arguments).

## Input arguments

After `<action>` is determined, collect the inputs that action needs via interactive prompts using the `question` tool. Ask one field at a time, in this exact order:

- `list`: no further input needed. Skip straight to ## List references.
- `remove`: ask step 1 only.
- `add`: ask step 1 through step 5.

Steps:

- step 1: Prompt the user to enter the reference **name**. Store as `<name>`.
- step 2: Prompt the user to choose the reference **type**: `local path` or `git repository`. Store as `<type>`.
- step 3: If `<type>` is `local path`:
    - step 3a: prompt the user to enter the reference **path** (relative, absolute, or `~/`). Store as `<path>`. If the path is relative, prepend `../` when storing.
    - step 3b: Verify the path exists with the `read` tool (or `ls` via `shell`); if not, re-prompt until valid or the user declines.
- step 4: If `<type>` is `git repository`:
    - step 4a: prompt the user to enter the **repository** (`owner/repo` or a full Git URL). Store as `<repository>`.
    - step 4b: prompt the user to enter the **branch** (optional, e.g. `main`). Store as `<branch>`; if the user leaves it blank, store nothing.
- step 5: Prompt the user to enter the reference **description**; if blank, auto-derive it from `<type>`. Store as `<description>` in **English**.

Rules:

- Ask each question separately; do not batch fields into a single prompt.
- Do not proceed to the next step until the current step has a non-empty answer (except `branch` and `description`, which are optional).
- If the user declines or skips a required step, abort the command silently.

## Precondition

- **⚠️ MUST use the `read` tool (or `ls` via `shell`) to check whether the project root contains `.opencode/opencode.json[c]` — DO NOT use `glob` as a substitute.**
- If file does not exist, use `question` tool to ask user whether to create the file (with `{ "$schema": "https://opencode.ai/config.json" }`) or not.

## Add reference

- Read `.opencode/opencode.json[c]`.
- If the `references` object field is missing, add:
  ```json
  "references": {

  }
  ```
- If a reference with the same `<name>` already exists, ask the user whether to overwrite. Skip silently if declined.
- Set the entry based on `<type>`:
  - `local path`:
    ```json
    "<name>": {
      "path": "<path>",
      "description": "<description>"
    }
    ```
  - `git repository`:
    ```json
    "<name>": {
      "repository": "<repository>",
      "description": "<description>"
    }
    ```
    Include `"branch": "<branch>"` between `repository` and `description` only if `<branch>` is non-empty. Example with branch:
    ```json
    "<name>": {
      "repository": "<repository>",
      "branch": "<branch>",
      "description": "<description>"
    }
    ```
- Save the updated config with pretty-printed JSON (2-space indent). Do not emit trailing commas; opencode rejects invalid JSON.

## Remove reference

- Read `.opencode/opencode.json[c]`.
- If `references` object contains `<name>`, remove the entry.
- If `references` becomes empty after removal, remove the `references` field entirely.
- Skip silently if `.opencode/opencode.json[c]` does not exist or the `<name>` is absent.

## List references

- Read `.opencode/opencode.json[c]`.
- If `references` exists, print each entry. For `path` entries: `name -> path: description`. For `repository` entries: `name -> repository@branch: description` (omit `@branch` when no branch is set).
- If absent, print `No references configured.`

## Post-configuration

Config reloads automatically; tell the user to run `/reload` only if the reference does not appear.
