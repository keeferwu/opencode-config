---
name: opencode-mem
description: Manage opencode-mem memory plugin — search/add/list memories, view/update user profile, troubleshoot errors (--doctor).
---

# opencode-mem

opencode-mem is the memory plugin for opencode. It uses vector embeddings to provide long-term memory and user profile learning.

Default behavior: show opencode-mem usage info (commands, config, data storage).

Only when user query contains `--doctor`: follow **Error Diagnosis** section below.

---

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `memory search <query>` | Semantic search of past memories |
| `memory add <content>` | Manually add a memory |
| `memory list` | List all memories |
| `memory profile` | View/update user profile |
| Web UI | `http://localhost:4747` Visual search & management |

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

---

## Error Diagnosis

Use this section when `--doctor` is specified or the user asks for error diagnosis/troubleshooting.

### Step 1: Check Log

```bash
cat ~/.opencode-mem/opencode-mem.log
```

### Step 2: Classify Error

#### A. Socket connection closed / connect ETIMEDOUT

Error:
```
Failed to initialize embedding model: {"error":"Error: The socket connection was closed unexpectedly. ..."}
```

**Fix — Download model with wget:**

```bash
export HF_ENDPOINT=https://hf-mirror.com
CACHE_DIR=~/.opencode-mem/data/.cache
for f in config.json tokenizer.json tokenizer_config.json special_tokens_map.json vocab.txt quantize_config.json README.md; do
  wget -q --timeout=30 --tries=3 "$HF_ENDPOINT/Xenova/nomic-embed-text-v1/resolve/main/$f" -O "$CACHE_DIR/Xenova/nomic-embed-text-v1/$f"
done
nohup wget --timeout=0 --tries=5 \
  "$HF_ENDPOINT/Xenova/nomic-embed-text-v1/resolve/main/onnx/model.onnx" \
  -O "$CACHE_DIR/Xenova/nomic-embed-text-v1/onnx/model.onnx" &
```

**Verify:**
```bash
ls -lh ~/.opencode-mem/data/.cache/Xenova/nomic-embed-text-v1/onnx/model.onnx
# Expected: ~522 MB (or ~132 MB for model_quantized.onnx)
```

#### B. Session create returned no session id

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
// Replace this:
"opencodeProvider": "opencode",
"opencodeModel": "big-pickle",
```
The provider must be one returned by `opencode providers list`.
Ensure the provider is already authenticated in opencode.
