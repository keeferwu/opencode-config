---
description: Create well-formatted commits with conventional commit messages
---

# Commit Command

You are an AI agent that helps create well-formatted git commits, follow these instructions exactly.

## Instructions for Agent

When the user runs this command, execute the following workflow:

1. **Analyze git status**:
   - Run `git status --porcelain` to check for changes
   - If no files are staged, list all changed files and ask user which to stage (or confirm `git add .`)
   - If files are already staged, proceed with only those files

2. **Analyze the changes**:
   - Run `git diff --cached` to see what will be committed
   - Analyze the diff to determine the primary change type (feat, fix, etc.)
   - Identify the main scope and purpose of the changes

3. **Collect required fields from user**:
   - Ask user for **Project** (repository name)
   - Ask user for **I#** (issue number)
   - If type is `fix` (bug fix):
     - Ask user for **M#** (Mantis ID)
     - If user provides M# → ask user for **Bug** description only; generate Cause + Solution from diff
     - If user does NOT provide M# → generate Bug, Cause, Solution all from diff analysis
     - Ask user for **TM#** (Taiwan Mantis ID) — optional; only include in message if provided

4. **Generate commit message**:
   - Create message following `Commit Message Guidelines` using the collected fields
   - Show the proposed message to user for confirmation

5. **Execute the commit**:
   - Run `git commit -m "<generated message>"`
   - Display the commit hash and confirm success

## Commit Message Guidelines

When generating commit messages, follow these rules:

- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Present tense, imperative mood**: Write commit messages as commands (e.g., "add feature" not "added feature")
- **Message content : Include `Concise first line` and `Conventional format`
- **Concise first line**: Keep the first line under 72 characters, Use `<module>: <subject>`
  - module: Module name related to this modification
  - subject: Give a short summary of the change
- **Conventional format**: Use `[Project][type][I#][M#][TM#]`
  - **Project**: the name of the repository — asked from user
  - **type**: one of:
    - `fix`: Bug fix, the content consists of Bug/Cause/Solution fields
    - `feat`: Add new feature
    - `refactor`: Code changes that neither fix bugs nor add features
    - `perf`: Performance improvements
    - `test`: Adding or fixing tests
  - **I#**: the issue number — asked from user (always required)
  - **M#**: Mantis ID — asked from user if type is `fix`
  - **TM#**: Taiwan Mantis ID — optional, asked from user if type is `fix`; only include if provided
  - For type `fix`:
    - If M# is provided → user provides Bug; Cause + Solution generated from diff
    - If M# is NOT provided → Bug, Cause, Solution all generated from diff analysis
  - For non-`fix` types (feat/refactor/perf/test), use * as prefix to write detail description

## Commit Examples

Use these as examples when generating commit messages:

### Example 1:
ipv4:check if IPv4 address is valid

[Cypress][refactor][I#10690]
* old code checks if IPv4 address belongs to Class A, B or C, and check if
  IPv4 address is valid Class C by mistake.
* if IPv4 address belongs class A/B/C, also check if it is a valid class A/B/C
  IPv4 address.

### Example 2:
fwup:fix that fw can't downgrade to 1.10

[TRENDnet][fix][I#10708][M#21468]
Bug: FW cannot downgrade from 2.10.xxx to 1.10.xxx by Utility.
Cause: tftp only do fw checking when receive the first packet, but the
       firmware version in the tail of the fw.
Solution: check firmware after fw transmission finish.

## Agent Behavior Notes

- **Error handling**: If validation fails, give user option to proceed or fix issues first
- **Auto-staging**: If no files are staged, list changed files and ask user which to stage
- **Message quality**: Ensure commit messages match the examples format exactly, with all required fields collected from user
- **Success feedback**: After successful commit, show commit hash and brief summary
