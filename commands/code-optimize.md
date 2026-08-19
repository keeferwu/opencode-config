---
description: Optimize code files using code-simplifier subagent with AGENTS.md standards
agent: build
model: opencode/big-pickle
---

# Code-optimize Command

Optimize code files by applying project standards from AGENTS.md using the code-simplifier subagent.

## Precondition

Only run if the project root contains `AGENTS.md`. Stop and inform the user that `AGENTS.md` is required if not found.

## Instructions

1. **Parse arguments** (`$ARGUMENTS`):
   - If no arguments provided, stop and inform the user to specify a file or directory path.
   - If a single file path is provided, verify it exists and target only that file.
   - If a directory path is provided, recursively discover all code files within it.
     - Detect file extensions based on project type (default): `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.go`, `.rs`, `.java`, `.c`, `.cpp`, `.h`, `.hpp`, `.rb`, `.php`, `.swift`, `.kt`, `.vue`, `.svelte`.
     - Skip common non-source directories: `node_modules`, `.git`, `venv`, `.venv`, `__pycache__`, `dist`, `build`, `.next`, `target`, `vendor`, `.cache`, `third_party`.
     - If no code files found in the directory, stop and inform the user.
   - If the path does not exist, stop and inform the user.
   - Before proceeding, check if the working directory is a git repo with uncommitted changes. If so, prompt the user to commit or stash before continuing (to enable easy rollback).

2. **Read AGENTS.md**:
   - Read `AGENTS.md` to extract project coding standards, conventions, and patterns.
   - Keep the content available to pass to the subagent.

3. **Optimize using code-simplifier**:
   - Dispatch a `code-simplifier` subagent per file (single mode) or per batch of up to 20 files (directory mode, splitting if >20 files to avoid context overflow).
   - Pass to the subagent: the file list, AGENTS.md content as the standards reference, and a lint/typecheck command if specified in AGENTS.md.
   - Provide the subagent with these instructions:
     - Refine the code files according to the project standards in AGENTS.md
     - For each file, read then rewrite it. Apply AGENTS.md rules spanning:
       - Naming conventions (variables, functions, classes, files)
       - Code organization (import order, function length, file structure)
       - Preferred language features and syntax patterns
       - Comment and documentation style
       - Error handling patterns
       - Type annotation requirements
     - Do not change any functionality, logic, or behavior
     - After editing, verify the file is syntactically valid using a parser check (e.g. `ast.parse` for Python, `tsc --noEmit` for TypeScript) if the tool is available; otherwise flag that manual verification is needed
     - Focus on clarity, maintainability, and adherence to project standards

4. **Verify results**:
   - Confirm all targeted files were processed successfully.
   - Run the project's lint/typecheck commands: prefer AGENTS.md-declared commands first, then fall back to `package.json` scripts (`lint`, `typecheck`, `type-check`).
   - If any file failed, report which ones and why.
   - Report summary of files optimized.
   - Recommend the user review the diff and run tests before committing.
