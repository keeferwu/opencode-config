---
name: session-clean
description: Browsing and cleaning OpenCode sessions. Includes paginated listing, preview-before-delete, automated cleanup of DB + storage artifacts. Use when user wants to delete/clean/manage opencode sessions or reduce space.
---

# session-clean

Browse and clean OpenCode session data interactively.

## Autonomy Rules

- Auto-start on trigger: run `stats` + `list_projects` immediately, show project page.
- Never ask open-ended questions — only use `question` tool with the fixed options defined in each step.

## Workflow

### 1. Entry

Call `./clean_sessions.py stats` to get total counts:
```
python3 <skill_dir>/clean_sessions.py stats
```
Display: "OpenCode has {total_sessions} sessions, {total_projects} projects"

### 2. Project Page

Call `./clean_sessions.py list_projects` to get all projects.

**If empty:** message "No projects found" and exit.

Otherwise paginate with `question` tool (10 per page). Put all display info in `label`, leave `description` empty:

Format per option: `{label: "<name_or_worktree> — <session_count> sessions", description: ""}`

After the paginated list, add action options:
- `{label: "next", description: "next page"}` — show only when `current_page < total_pages`
- `{label: "prev", description: "prev page"}` — show only when `current_page > 1`
- `{label: "cancel", description: "cancel & exit"}`

### 3. Session Page

Call `./clean_sessions.py list_sessions <project_id>` to get sessions.
Call `./clean_sessions.py current_session` to get current session ID.

Display project info + paginated session list (10 per page). Two-step interaction:

**Step 3a — select sessions** (`question` with `multiple: true`):

Session options on this page:
- `{label: "<slug>: <title>", description: "<preview> — <time_created>"}`
- `{label: "select all", description: "select all sessions on current page and proceed"}`

User may pick zero, one, or many sessions. If "select all on this page" is in selection, treat as selecting all sessions on current page, then apply current session protection (below), then skip to step 3b. Otherwise, selection stored for step 3b.

**Current session protection:** After user selects (including "select all"), filter out any session matching the current session ID from the selection. If current session was in selection, report: "Current session (<slug>) excluded — cannot delete active session". Proceed with remaining selected sessions. If no sessions remain after filtering, skip to step 3b with 0 selected.

**Step 3b — choose action** (`question`, single-select):

**MANDATORY** — Include page info in `question` text: `"Page {current_page}/{total_pages}"`

- `{label: "delete selected (<N>)", description: "preview then delete"}` — N is count after current session filtering; hidden when 0
- `{label: "change selection", description: "back to step 3a"}`
- `{label: "next", description: "next page"}` — show only when `current_page < total_pages`
- `{label: "prev", description: "prev page"}` — show only when `current_page > 1`
- `{label: "cancel", description: "cancel & exit"}`
- `{label: "back project ", description: "back to project list"}`

Pagination resets selection (new page starts at 3a with no carry-over).

**If project has 0 sessions:** offer `delete project` option (label only). Show preview via `preview_delete_project`, then auto-delete.

### 4. Preview & Execute Deletion

Show preview before deletion, then auto-delete:

**Session preview** — call `preview_delete_sessions <id1,id2,...>`:
```
Will delete:
- Database session records: <count>
- Storage DCP files: <count>
- Session diff files: <count>
```

Then delete: `python3 <skill_dir>/clean_sessions.py delete_sessions <id1,id2,...>`

**Project deletion** — call `preview_delete_project <project_id>`:
```
Will delete:
- Project: <worktree> (<session_count> sessions)
- Database records: project + <N> sessions (CASCADE)
- Storage DCP files: <count>
- Session diff files: <count>
- Snapshot directory: <path>
```

Then delete: `python3 <skill_dir>/clean_sessions.py delete_project <project_id>`

Report result: "Deleted N sessions" / "Deleted project and N sessions"

### 5. Post-deletion

After any deletion, return to **project list page** (step 2). Do NOT exit to shell.

## Notes

- All `question` tool selections accept number input (not raw IDs)
- Step 3a returns an array of selected labels; map each label back to its session id by page position, then pass `id1,id2,...` to preview/delete commands
- When mapping labels to ids, the list_sessions output order (DESC time_updated) matches the displayed page order so index aligns
- Always show project worktree path for identification (not just internal ID)
- Convert epoch ms timestamps to readable date in display
- The Python script handles DB operations + file cleanup atomically
- `ON DELETE CASCADE` in DB handles related tables automatically
