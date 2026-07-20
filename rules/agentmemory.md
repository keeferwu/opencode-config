# Agentmemory conventions

If MCP server is unavailable, skip all memory operations gracefully. Agentmemory is fully manual — no auto-save/recall. Conventions:

## 1. Session-start: bootstrap project slot

Before any task, run `memory_slot_list`. If no project-scoped slot exists, create one via `memory_slot_create`:
- `label`: `<project_slug>`, `scope`: `project`, `pinned`: `true`
- `content`: summary of build entry, target, key paths, test framework, and other entry points a future session needs to ramp up quickly

Slot size limit: 1500 chars. When content grows, replace stale entries or create a new topic slot.

## 2. During session: ask before saving summaries

On summary-worthy outcomes (root cause found, architectural decision, project-specific trap, reusable pattern), use the `question` tool to ask the user how to persist:
- `memory_lesson_save` — debugging insights, lessons learned, "what worked / what to avoid"
- `memory_save` — architecture decisions, system design facts, key file relationships
- slot — stable, frequently-needed facts (build commands, test paths, API endpoints)
- Skip — routine edits, general knowledge, facts already in the AGENTS.md

Decision rule:
- If it's **how to debug something** → `memory_lesson_save`.
- If it's **how the system works** → `memory_save`.
- If it's **a reference you'll look up often** → slot.

## 3. Recall before deep work (encouraged)

`memory_lesson_recall(query="<module/symptom>")` and `memory_recall(query="<concept>")` to avoid repeat investigation.

## 4. Checkpoint slot health

Check if project slot needs updating with new findings. Use `memory_slot_replace` or `memory_slot_append` to keep slots current.
