---
description: Create well-formatted git commits with Conventional Commits
agent: build
model: opencode/big-pickle
---

# Git-commit Command

You are an AI agent that helps create well-formatted Conventional Commits and follow these instructions exactly.

## Instructions for Agent

When the user runs this command, execute the following workflow:

1. **Set working directory**:

- If `$ARGUMENTS` is provided, treat it as a directory path and set `GIT_CMD` to `git -C "$ARGUMENTS"`
- If `$ARGUMENTS` is empty, set `GIT_CMD` to `git`
- If `$ARGUMENTS` is provided but the directory does not exist, stop and inform the user

2. **Analyze git status**:

- Run `${GIT_CMD} status --porcelain` to check for changes
- If no files are staged, list all changed (including untracked) files and ask user which to stage (or confirm `${GIT_CMD} add .`)
- If untracked files exist alongside staged files, list them and ask if user wants to stage any as well
- If files are already staged, proceed with only those files

3. **Analyze the changes**:

- Run `${GIT_CMD} diff --cached` to see what will be committed
- Analyze the diff to determine the primary change type
- Identify the main scope and purpose of the changes

4. **Determine commit type** based on the diff:

| Type       | Usage                                             |
|------------|---------------------------------------------------|
| `feat`     | A new feature                                     |
| `fix`      | A bug fix                                         |
| `build`    | Changes to the build system or dependencies       |
| `chore`    | Other changes that don't modify src or test files |
| `ci`       | Changes to CI configuration files and scripts     |
| `docs`     | Documentation only changes                        |
| `perf`     | A code change that improves performance           |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `revert`   | Reverts a previous commit                         |
| `style`    | Changes that do not affect the meaning of the code |
| `test`     | Adding missing or correcting existing tests       |

5. **Build commit message** using the format:

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- **type** — one of the types above (required)
- **scope** — a noun describing the codebase section, in parentheses, e.g. `feat(parser):`
- **!** — mark breaking changes immediately before the colon, e.g. `feat!: drop Node 6`
- **description** — short summary, required after `: `
- **body** — optional, one blank line after description, free-form paragraphs
- **footer(s)** — optional, one blank line after body, git trailer format (`Token: value` or `Token #value`)

6. **Breaking changes**: If the change breaks backward compatibility:

- Add `!` after type/scope: `feat(api)!: ...`
- Or add `BREAKING CHANGE: <description>` as a footer
- `BREAKING-CHANGE` is synonymous with `BREAKING CHANGE`

7. **Present the message** to the user for approval before committing. Show the full message in a code block.

8. **Commit** once approved: run `${GIT_CMD} commit -m "<subject>" -m "<body>"` (use multiple `-m` for multi-line messages).

## Conventional Commits Specification

Reference https://www.conventionalcommits.org/en/v1.0.0/

## Examples

```
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```
