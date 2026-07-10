---
description: Manage opencode-mem memory plugin — search/add/delete/list memories, view/update user profile, troubleshoot errors (doctor).
---

# Opencode-mem Command

opencode-mem is the memory plugin for opencode. It uses vector embeddings to provide long-term memory and user profile learning.

## Precondition: Plugin Load Check

Before any action, verify opencode-mem plugin is loaded:

```bash
opencode debug info | grep -q opencode-mem
```
If plugin not loaded (grep fail or no output), exit immediately — do nothing.

## Instructions for Agent

When the user runs this command (`/opencode-mem`), follow these rules:

1. **Run precondition check**. If plugin not loaded, exit silently.
2. **No arguments** — Show a brief summary of available commands and the Web UI URL. Ask the user what they want to do.
3. **`help`** — Display the **Usage Reference**.
4. **`doctor`** — Skip everything else; run the **Error Diagnosis** workflow below.
5. **`web`** — Read `~/.config/opencode/opencode-mem.jsonc`, extract `webServerPort` (default: 4747), then open `http://localhost:<port>` in the default browser.
6. **Any other arguments** — Convert and execute as the corresponding `memory` command:
   - `/opencode-mem search <query>` → `memory search <query>`
   - `/opencode-mem add <content>` → `memory add <content>`
   - `/opencode-mem list` → `memory list`
   - `/opencode-mem profile` → `memory profile`
   - `/opencode-mem forget <id>` → `memory forget <id>`
   - If needed clarification (e.g., search with no query), ask the user before proceeding

## Usage Reference

### Commands

User runs these directly in opencode chat:

| Command | Description |
|---------|-------------|
| `memory search <query>` | Semantic search of past memories |
| `memory add <content>` | Manually add a memory |
| `memory list` | List all memories |
| `memory profile` | View/update user profile |
| `memory forget <id>` | Delete a memory by ID |
| Web UI | `http://localhost:<webServerPort>` Visual search & management (default: 4747) |

### Key Config

Config file: `~/.config/opencode/opencode-mem.jsonc`:
- `autoCaptureEnabled` — Auto-capture key info from sessions
- `opencodeProvider` / `opencodeModel` — Which LLM processes memories
- `similarityThreshold` — Memory search similarity threshold (default: 0.6)
- `webServerEnabled` / `webServerPort` — Web UI (default: 4747)
- `embeddingModel` — Local embedding model (default: `Xenova/nomic-embed-text-v1`)
- `storagePath` — Data storage path (default: `~/.opencode-mem/data/`)

### Data Storage

- `~/.opencode-mem/data/` — Vector database
- `~/.opencode-mem/metadata.db` — Metadata
- `~/.opencode-mem/user-profiles.db` — User profiles
- `~/.opencode-mem/user-prompts.db` — Prompt history
- `~/.opencode-mem/opencode-mem.log` — Runtime log (check this first when troubleshooting)

---

## Error Diagnosis

Run this workflow when `doctor` is specified or the user asks for error diagnosis/troubleshooting.

### Step 1: Check Log

```bash
if [ -f ~/.opencode-mem/opencode-mem.log ]; then
  cat ~/.opencode-mem/opencode-mem.log
else
  echo "Log not found — plugin may not have started yet"
fi
```

### Step 2: Classify Error

#### A. Failed to initialize embedding model (corrupted cache)

Error:
```
Failed to initialize embedding model: {"error":"Error: Unable to connect. Is the computer able to access the url? ..."}
```

Note: This error usually means the model cache files are corrupted. Delete the cache and re-download model.

**Fix — Delete corrupted cache:**

```bash
CACHE_DIR=~/.opencode-mem/data/.cache
MODEL_DIR="$CACHE_DIR/Xenova/nomic-embed-text-v1"

if [ -d "$MODEL_DIR" ]; then
  echo "Removing corrupted model cache..."
  rm -rf "$MODEL_DIR"
  echo "Cache cleaned"
fi
```

#### B. Socket connection closed / connect ETIMEDOUT

Error:
```
Failed to initialize embedding model: {"error":"Error: The socket connection was closed unexpectedly. ..."}
```

**Fix — Download model:**

When executing the download commands below, always set the terminal timeout to **1800000ms (30 minutes)** to allow the large model file to finish downloading.

```bash
export HF_ENDPOINT=https://hf-mirror.com
CACHE_DIR=~/.opencode-mem/data/.cache
MODEL_DIR="$CACHE_DIR/Xenova/nomic-embed-text-v1"
if [ -f "$MODEL_DIR/onnx/model.onnx" ] || [ -f "$MODEL_DIR/onnx/model_quantized.onnx" ]; then
  echo "Model already cached, skipping download"
  ls -lh "$MODEL_DIR/onnx/"
  exit 0
fi
mkdir -p "$MODEL_DIR/onnx"
for f in config.json tokenizer.json tokenizer_config.json special_tokens_map.json vocab.txt quantize_config.json README.md; do
  wget -q --timeout=0 --tries=5 "$HF_ENDPOINT/Xenova/nomic-embed-text-v1/resolve/main/$f" -O "$CACHE_DIR/Xenova/nomic-embed-text-v1/$f"
done
if ! wget --timeout=0 --tries=5 \
  "$HF_ENDPOINT/Xenova/nomic-embed-text-v1/resolve/main/onnx/model.onnx" \
  -O "$CACHE_DIR/Xenova/nomic-embed-text-v1/onnx/model.onnx"; then
  echo "model.onnx download failed, trying model_quantized.onnx (smaller) ..."
  wget --timeout=0 --tries=5 \
    "$HF_ENDPOINT/Xenova/nomic-embed-text-v1/resolve/main/onnx/model_quantized.onnx" \
    -O "$CACHE_DIR/Xenova/nomic-embed-text-v1/onnx/model_quantized.onnx"
fi
```

**Verify:**
```bash
ls -lh ~/.opencode-mem/data/.cache/Xenova/nomic-embed-text-v1/onnx/
# Expected: model.onnx ~522 MB, or model_quantized.onnx ~132 MB if fallback was used
```

#### C. Session create returned no session id

Error:
```
Auto-capture warning ... {"error":"opencode-mem: session.create returned no session id; ..."}
```

**Fix option 1 — Disable auto-capture:**

Edit `~/.config/opencode/opencode-mem.jsonc` and set:

```jsonc
"autoCaptureEnabled": false,
```

**Fix option 2 — Configure a real API provider:**

Edit `~/.config/opencode/opencode-mem.jsonc` and replace the provider section:

```jsonc
// Replace these (example with OpenAI):
"opencodeProvider": "openai",
"opencodeModel": "gpt-4o",
```
The provider must be one returned by `opencode providers list`. Ensure the provider is already authenticated in opencode.

### Step 3: Clean Log

After fixing the issue, clear resolved errors from the log to avoid confusion on next diagnosis.

```bash
if [ -f ~/.opencode-mem/opencode-mem.log ]; then
  > ~/.opencode-mem/opencode-mem.log
  echo "Log cleared"
fi
```

### Step 4: Report

After completing diagnosis, tell the user with this template:

```
Diagnosis complete:
- Issue found: <what was detected>
- Fix applied: <what was done>
- Recommendation: restart opencode for changes to take effect
```
