---
name: markitdown
description: "Use when the user asks to analyze, summarize, or extract data from a local file with common document/binary formats (.pdf, .pptx, .docx, .xlsx, .jpg, .png, .html, .csv, .json, .xml, .zip, .epub, .mp3, .wav, .msg). Do NOT use for plain-text or source code files (.txt, .md, .py, .js, .ts) that can be read directly."
---

# MarkItDown File Conversion Skill

## Overview

Uses the `markitdown:latest` Docker image (based on microsoft/markitdown) to convert various office documents, images, audio, and other file formats to Markdown, enabling the LLM to parse their contents. The `convert.sh` script automatically builds the image from pip if it doesn't exist.

## Supported File Formats

| Category | Formats |
|----------|---------|
| PDF | `.pdf` |
| PowerPoint | `.pptx` |
| Word | `.docx` |
| Excel | `.xlsx`, `.xls` |
| Images (EXIF + OCR) | `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`, `.webp` |
| Audio (EXIF + speech transcription) | `.mp3`, `.wav` |
| HTML | `.html`, `.htm` |
| Structured text formats | `.csv`, `.json`, `.xml` |
| Archives (iterates contents) | `.zip` |
| E-books | `.epub` |
| Outlook messages | `.msg` |

## Conversion Command

```bash
docker run --rm -i markitdown:latest < /path/to/input.file > /tmp/opencode/output.md
```

Pipe syntax also works:
```bash
cat /path/to/input.file | docker run --rm -i markitdown:latest > /tmp/opencode/output.md
```

If the file path contains spaces or special characters, wrap it in quotes:
```bash
docker run --rm -i markitdown:latest < "/path/with spaces/file.pdf" > /tmp/opencode/output.md
```

## Workflow

When the user asks to analyze a supported file:

1. **Verify file exists**: `ls -la <path>` to check the file path
2. **Convert the file**: Use the docker command to convert to Markdown (image auto-builds if missing)
3. **Read the result**: Use the Read tool on the generated `.md` file
4. **Provide analysis**: Feed the Markdown content to the LLM for analysis

### Complete Example

User says: "Analyze this quote ~/documents/quote.pdf"

```
$ ls -la ~/documents/quote.pdf
$ docker run --rm -i markitdown:latest < ~/documents/quote.pdf > /tmp/opencode/quote.md
$ # Read /tmp/opencode/quote.md
$ # Then analyze and summarize based on the content
```

## Helper Script

`<skill-dir>/convert.sh` is a convenient wrapper that handles file existence checks, auto-builds the Docker image when missing, and performs file conversion:

```bash
bash <skill-dir>/convert.sh /path/to/file.pdf > /tmp/opencode/output.md
```

The script automatically builds the image from pip (`pip install markitdown[all]`) when the Docker image doesn't exist — no manual intervention needed.

## Common Mistakes

1. **File not found**: Always verify the file path with `ls -la` before converting
2. **Can't read binary files directly**: Don't use the Read tool on PDF/Excel/image etc. binary files — always convert via Docker first
3. **Large files**: For files over 50MB, conversion may take some time; set a reasonable timeout
4. **File permissions**: Ensure the current user has read access to the file
5. **First build is slow**: If the Docker image doesn't exist, the first use auto-builds (~1-2 min); subsequent uses are instant

## When Not to Use

- Plain text files (`.txt`, `.md`, `.py`, `.js`, `.rs`, `.go`, `.ts` and other source code files) — just use Read directly
- Remote URL files: markitdown doesn't support remote URL input; download the file locally first
- User only asks about file existence, size, or other metadata without needing content parsing
