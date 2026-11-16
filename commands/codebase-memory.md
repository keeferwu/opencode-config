---
description: Initialize project codebase knowledge graph
agent: build
model: opencode/big-pickle
---

# Codebase-memory Command

Initialize the codebase knowledge graph for a project.

## Precondition

Only run if the project root contains `AGENTS.md` or `.opencode/AGENTS.md`. Skip otherwise.

## Instructions

1. **Check installation**:
   - Run `command -v codebase-memory-mcp` to verify
   - If not found: `sudo npm install -g codebase-memory-mcp`

2. **Ensure codebase-memory-mcp server is configured**:
   - Read `.opencode/opencode.json[c]`.
   - If it does not exist in the project root, create it with:
     ```json
     {
       "$schema": "https://opencode.ai/config.json"
     }
     ```
   - If `mcp` or `mcp.servers` is missing, add:
     ```json
     "mcp": {
        "servers": {
           "codebase-memory-mcp": {
              "type": "local",
              "command": [
                 "codebase-memory-mcp"
              ],
              "disabled": false
           }
        }
     }
     ```
   - If `mcp.servers` already exists but lacks `codebase-memory-mcp`, merge into the existing `mcp.servers` object

3. **Sync codebase memory config**:
   - Ensure the destination `.opencode/` exists before syncing
   - Sync the `agents/`, `plugins/`, and `skills/` directories (not `AGENTS.md`) into `.opencode/`:
     ```bash
     rsync -av --exclude='AGENTS.md' ~/.config/opencode/codebase_memory/ .opencode/
     ```
   - Append the codebase-memory section to the project-root `AGENTS.md` when the `# Codebase Memory` section is missing:
     ```bash
     SRC=~/.config/opencode/codebase_memory/AGENTS.md
     grep -q '# Codebase Memory' AGENTS.md 2>/dev/null || cat "$SRC" >> AGENTS.md
     ```
4. **Generate `.cbmignore` if it does not exist**:
   - Resolve the project root (git-aware; works without git):
     ```bash
     ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
     ```
   - Inspect the set the indexer will actually read — tracked plus
     untracked-but-not-ignored (`git ls-files --cached --others --exclude-standard`,
     not plain `git ls-files`). Derive patterns from the data; never hardcode an
     extension list:
     ```bash
     FLIST=$(mktemp); git ls-files --cached --others --exclude-standard > "$FLIST"   # non-git: rg --files > "$FLIST"
     sed 's/.*\///' "$FLIST" | awk -F'[.]' '{print (NF>1 ? tolower($NF) : "(none)")}' | sort | uniq -c | sort -rn | head -40   # extensions
     cut -d/ -f1,2 "$FLIST" | sort | uniq -c | sort -rn | head -20                                                            # top dirs
     tr '\n' '\0' < "$FLIST" | xargs -0 du -k 2>/dev/null | sort -rn | head -20                                                # large files
     ```
   - Write `$ROOT/.cbmignore` (gitignore syntax): keep whatever a developer would
     query as source/config, exclude the rest preferring whole directories — build
     outputs/objects, toolchains, dependency caches (e.g. `node_modules/`, vendored
     `thirdparty/`), binary/media, and huge generated files. It **complements**
     `.gitignore`, so don't re-list what is already ignored.
   - **Subdirectory gotcha**: when `repo_path` is a subdirectory only
     `<subdir>/.cbmignore` is read, so copy the needed rules into each indexed
     subdir and re-root their paths (root `a/b/` → `b/` in `a/.cbmignore`):
     ```bash
     cbm_reroot() {   # usage: cbm_reroot <subdir>  -> writes <subdir>/.cbmignore
        local sub="${1#./}"; : > "$sub/.cbmignore"
        while IFS= read -r p; do
           case "$p" in ""|\#*) printf '%s\n' "$p"; continue;; esac
           local neg=""; case "$p" in \!*) neg="!"; p="${p#!}";; esac
           p="${p#/}"; case "$p" in "$sub"/*) p="${p#"$sub"/}";; esac
           printf '%s%s\n' "$neg" "$p"
        done < "$ROOT/.cbmignore" >> "$sub/.cbmignore"
     }
     ```
   - **Verify + quantify** before indexing:
     ```bash
     KEEP="path/to/known/source/file"   # must remain indexed
     git -c core.excludesFile=.cbmignore check-ignore -q --no-index "$KEEP" && echo "WARN: source is ignored!" || echo "source kept"
     total=$(wc -l < "$FLIST")
     ignored=$(git -c core.excludesFile=.cbmignore check-ignore --no-index --stdin < "$FLIST" 2>/dev/null | wc -l)
     echo "indexed after .cbmignore: $((total - ignored)) / $total"
     ```
   - **User confirmation (gate)**: show the generated `.cbmignore` content and the
     kept/excluded summary, then **stop and wait** for the user to confirm. Do not
     start step 5 until the user approves.

5. **Index codebase**:
   - Only after steps 1-4 are verified **and the user has confirmed the `.cbmignore`**,
     dispatch a `general` subagent to index the codebase
   - Instruct the subagent to run the indexer with `timeout: 600000` in its `shell` tool call (the `subagent` tool itself has no timeout parameter)
   - Have it run the indexer **throttled** so it can't starve the host: hard-cap memory with a
     cgroup v2 scope, deprioritize CPU with `nice`/`ionice`, and pass the tool a memory budget
     (best-effort — probes the exact cgroup props first and falls back to `nice` alone if
     systemd user scopes are unavailable):
     ```bash
     ram=$(( $(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) / 1048576 ))      # total RAM (MB)
     props=(-p MemoryHigh=$((ram*60/100))M -p MemoryMax=$((ram*80/100))M -p MemorySwapMax=256M)
     mem=(); systemd-run --user --scope -q "${props[@]}" -- true 2>/dev/null \
        && mem=(systemd-run --user --scope -q "${props[@]}" --)
     nce=(nice -n 19); command -v ionice >/dev/null && nce=(nice -n 19 ionice -c3)
     CBM_MEM_BUDGET_MB=$((ram*30/100)) nohup "${mem[@]}" "${nce[@]}" \
        codebase-memory-mcp cli --progress index_repository --repo-path "$PWD" --mode fast
     ```
   - After completion, the subagent returns the execution result (success/failure + output) to the main agent

6. **Report status**:
   - Show a summary of what was done (`.opencode/opencode.json[c]` created/modified, sync result, `.cbmignore` created, index result)
   - Config reloads automatically; tell the user to run `/reload` only if the new MCP server does not appear
