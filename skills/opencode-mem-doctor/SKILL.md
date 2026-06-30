---
name: opencode-mem-doctor
description: Check opencode-mem.log and diagnose embedding model issues.
---

# opencode-mem Error Diagnosis

## Step 1: Check Log

```bash
cat ~/.opencode-mem/opencode-mem.log
```

## Step 2: Classify Error

### A. Socket connection closed / connect ETIMEDOUT

```bash
Failed to initialize embedding model: {"error":"Error: The socket connection was closed unexpectedly. For more information, pass `verbose: true` in the second argument to fetch()"}
Plugin warmup failed: {"error":"Error: The socket connection was closed unexpectedly. For more information, pass `verbose: true` in the second argument to fetch()"}
```

**Fix - Download model with wget**

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

**Verify**
```bash
ls -lh ~/.opencode-mem/data/.cache/Xenova/nomic-embed-text-v1/onnx/model.onnx
# Expected: ~522 MB (or ~132 MB for model_quantized.onnx)
```

### B. Session create return no session id

```bash
Auto-capture warning (attempt 1/3): {"error":"opencode-mem: session.create returned no session id; cannot generate structured output"}
Auto-capture warning (attempt 2/3): {"error":"opencode-mem: session.create returned no session id; cannot generate structured output"}
Auto-capture final error after 3 attempts: {"error":"opencode-mem: session.create returned no session id; cannot generate structured output"}
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
