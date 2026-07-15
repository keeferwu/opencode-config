---
description: Pre-warm OmniRoute models to eliminate cold start delays before starting a session.
---

# OmniRoute Model Pre-warm

Pre-warm selected OmniRoute models by sending test requests, eliminating cold start delays.

## Steps

1. Read the global config file at `~/.config/opencode/opencode.json`. Check if `provider.omniroute` does NOT exist, stop immediately — do not proceed to any further steps.

2. Extract `baseURL` from `provider.omniroute.options.baseURL` and `apiKey` from `provider.omniroute.options.apiKey`. These are the provider credentials.

3. Call `GET {baseURL}/models` with header `Authorization: Bearer {apiKey}` to verify connectivity. If the request fails, inform the user and stop.

4. Parse the JSON response.
   - Filter models where `owned_by` equals `"combo"` — these are the combo models.
   - Extract their `id` fields.
   - Sort the list: user-created combos first, then built-in auto combos (IDs starting with `auto/`).

5. Use the `question` tool for paginated selection(two steps).

   **Question 1 — select models** (`multiple: true`):
   - Show up to 10 combo model IDs on current page as selectable options.
   - User selects one or more models, then go to Step question 2.

   **Question 2 — choose action** (single-select):
   - **MANDATORY** — Include page info in `question` text: `"Page {current_page}/{total_pages}"`
   - `{label: "pre-warm", description: "start pre-warming selected models"}`
   - `{label: "next", description: "next page"}` — show only when `current_page < total_pages`
   - `{label: "prev", description: "prev page"}` — show only when `current_page > 1`
   - `{label: "cancel", description: "cancel & exit"}`

   After receiving the results:
   - If user chose "next" or "prev", go back to step 5 (show new page). Selections are reset — do NOT carry over from previous pages.
   - If user chose "model selected", proceed to step 6 with the models selected on the current page only.
   - If user chose "cancel", stop immediately.

6. For each selected model, send a pre-warm request via curl:
   ```
   curl -s -X POST {baseURL}/chat/completions \
     -H "Authorization: Bearer {apiKey}" \
     -H "Content-Type: application/json" \
     -d '{"model":"{id}","messages":[{"role":"user","content":"hi"}],"max_tokens":1}' \
     --max-time 60
   ```
   Run requests **sequentially** (not in parallel) to avoid overwhelming the backend.

7. After all requests complete, display a summary table showing each model's status (success/failure) and response time.
