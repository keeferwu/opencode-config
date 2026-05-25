---
description: Create well-formatted commits with conventional commit messages
---

# Commit Command

You are an AI agent that helps create well-formatted git commits, follow these instructions exactly.

## Instructions for Agent

When the user runs this command, execute the following workflow:

1. **Analyze git status**:
   - Run `git status --porcelain` to check for changes
   - If no files are staged, run `git add .` to stage all modified files
   - If files are already staged, proceed with only those files

2. **Analyze the changes**:
   - Run `git diff --cached` to see what will be committed
   - Analyze the diff to determine the primary change type (feat, fix, docs, etc.)
   - Identify the main scope and purpose of the changes

3. **Generate commit message**:
   - Create message following `Commit Message Guidelines`
   - Show the proposed message to user for confirmation

4. **Execute the commit**:
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
- **Conventional format**: Use `[Model][type][I#][M#][TM#]`
  - Model: the name of the repository
  - type: one of:
    - `Fix`: Bug fix, the content consists of Bug/Cause/Solution fields
    - `New`: Add new feature
    - `Refactor`: Code changes that neither fix bugs nor add features
    - `perf`: Performance improvements
    - `test`: Adding or fixing tests
  - I#: the issue number
  - M#: Mantis ID
  - TM#: Taiwan Mantis ID
  - All fields should ask user to provide.
  - If M# field is not empty, Bug field should ask user to provide, and Cause/Solution field should be generated based on perspective of design
  - If type is not `Fix`, use * as a prefix to write detail description

## Commit Examples

Use these as examples when generating commit messages:

### Example 1:
ipv4:check if IPv4 address is valid

[Cypress][Refactor][I#10690]
* old code checks if IPv4 address belongs to Class A, B or C, and check if
  IPv4 address is valid Class C by mistake.
* if IPv4 address belongs class A/B/C, also check if it is a valid class A/B/C
  IPv4 address.

### Example 2:
fwup:fix that fw can't downgrade to 1.10

[TRENDnet][Fix][I#10708][M#21468]
Bug: FW cannot downgrade from 2.10.xxx to 1.10.xxx by Utility.
Cause: tftp only do fw checking when receive the first packet, but the
       firmware version in the tail of the fw.
Solution: check firmware after fw transmission finish.

## Agent Behavior Notes

- **Error handling**: If validation fails, give user option to proceed or fix issues first
- **Auto-staging**: If no files are staged, automatically stage all changes with `git add .`
- **Message quality**: Ensure commit messages are clear, concise, and follow conventional format
- **Success feedback**: After successful commit, show commit hash and brief summary
