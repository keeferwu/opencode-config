---
name: session-manager
description: Browsing, exporting, and cleaning OpenCode sessions. Includes paginated listing, export-to-markdown, preview-before-delete, automated cleanup of DB + storage artifacts. Use when user wants to export, delete, clean, or manage opencode sessions or reduce space.
---

# session-manager

Browse, export, and manage OpenCode sessions interactively.

## Direct Action Shortcut

**"export current session"** or similar intent (e.g., "export this session", "export current"):

1. Call `./session_manager.py current_session` to get current session ID
2. Call `./session_manager.py export_sessions <id>`
3. Report result per section 5, then exit

## Autonomy Rules

- Auto-start on trigger: run `stats` + `list_projects` immediately, show project page.
- Never ask open-ended questions — only use `question` tool with the fixed options defined in each step.

## Workflow

### 1. Entry

Call `./session_manager.py stats` to get total counts:
```
./session_manager.py stats
```
Display: "OpenCode has {total_sessions} sessions, {total_projects} projects"

### 2. Project Page

Call `./session_manager.py list_projects` to get all projects.

**If empty:** message "No projects found" and exit.

Otherwise paginate with `question` tool (10 per page). Put all display info in `label`, leave `description` empty:

Format per option: `{label: "<name_or_worktree> — <session_count> sessions", description: ""}`

After the paginated list, add action options:
- `{label: "next", description: "next page"}` — show only when `current_page < total_pages`
- `{label: "prev", description: "prev page"}` — show only when `current_page > 1`
- `{label: "cancel", description: "cancel & exit"}`

### 3. Session Page

Call `./session_manager.py list_sessions <project_id>` to get sessions.
Call `./session_manager.py current_session` to get current session ID.

Display project info + paginated session list (10 per page). Two-step interaction:

**Step 3a — select sessions** (`question` with `multiple: true`):

Session options on this page:
- `{label: "<slug>: <title>", description: "<preview> — <time_created>"}`
- `{label: "select all", description: "select all sessions on current page and proceed"}`

User may pick zero, one, or many sessions. Store selection as `selected_ids`. Track `current_session_id` for action-time filtering.

If "select all on this page" is in selection, treat as selecting all sessions on current page and proceed to step 3b.

**Current session advisory:** After user selects, check if current session is in `selected_ids`. If so, report: "Current session (<slug>) — will be skipped on delete, but can be exported". Do NOT remove it from `selected_ids` — filtering happens per-action below.

**Step 3b — choose action** (`question`, single-select):

**MANDATORY** — Include page info in `question` text: `"Page {current_page}/{total_pages}"`

- `{label: "delete selected (<N>)", description: "preview then delete"}` — N = `selected_ids` count after excluding current session
- `{label: "export selected (<N>)", description: "export to markdown"}` — N = `selected_ids` count (may include current session)
- `{label: "change selection", description: "back to step 3a"}`
- `{label: "next", description: "next page"}` — show only when `current_page < total_pages`
- `{label: "prev", description: "prev page"}` — show only when `current_page > 1`
- `{label: "cancel", description: "cancel & exit"}`
- `{label: "back project ", description: "back to project list"}`

Pagination resets selection (new page starts at 3a with no carry-over).

**If project has 0 sessions:** offer `delete project` option (label only). Show preview via `preview_delete_project`, then auto-delete.

### 4. Preview & Execute Deletion

When user picks "delete selected", filter out current session from `selected_ids` before proceeding.

Show preview before deletion, then auto-delete:

**Session preview** — call `preview_delete_sessions <id1,id2,...>` (current session already excluded):
```
Will delete:
- Database session records: <count>
- Storage DCP files: <count>
- Session diff files: <count>
```

Then delete: `./session_manager.py delete_sessions <id1,id2,...>`

**Project deletion** — call `preview_delete_project <project_id>`:
```
Will delete:
- Project: <worktree> (<session_count> sessions)
- Database records: project + <N> sessions (CASCADE)
- Storage DCP files: <count>
- Session diff files: <count>
- Snapshot directory: <path>
```

Then delete: `./session_manager.py delete_project <project_id>`

Report result: "Deleted N sessions" / "Deleted project and N sessions"

### 5. Export Sessions

When user picks "export selected", pass `selected_ids` as-is (current session included if selected):
```
./session_manager.py export_sessions <id1,id2,...>
```

Report per session:
- On success: "Exported <slug> → <filepath> (<text_chars> chars)"
- On error: "Failed <slug>: <error>"

### 6. Post-action

After any deletion or export, return to **project list page** (step 2). Do NOT exit to shell.

## Notes

- All `question` tool selections accept number input (not raw IDs)
- Step 3a returns an array of selected labels; map each label back to its session id by page position, then pass `id1,id2,...` to preview/delete/export commands
- When mapping labels to ids, the list_sessions output order (DESC time_updated) matches the displayed page order so index aligns
- `selected_ids` keeps all user picks; delete filters out current session at execution time, export does not
- Always show project worktree path for identification (not just internal ID)
- Convert epoch ms timestamps to readable date in display
- The Python script handles DB operations + file cleanup atomically
- `ON DELETE CASCADE` in DB handles related tables automatically
