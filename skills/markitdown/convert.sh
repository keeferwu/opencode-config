#!/bin/bash
# Helper script to convert files to Markdown using markitdown docker container
# Usage: ./convert.sh <input-file>
# Output: Writes converted markdown to stdout and prints file path to stderr
#
# Example: ./convert.sh ~/documents/report.pdf > /tmp/opencode/report.md

set -e

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <input-file>" >&2
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if which docker >/dev/null 2>&1; then
    # Build docker image on demand if missing
    if ! docker images markitdown:latest 2>/dev/null | grep -q markitdown; then
        echo "Docker image 'markitdown:latest' not found. Building from official repo..." >&2
        BUILD_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/microsoft/markitdown.git "$BUILD_DIR/markitdown" >&2
        docker build -t markitdown:latest "$BUILD_DIR/markitdown" >&2
        rm -rf "$BUILD_DIR"
    fi
    docker run --rm -i markitdown:latest < "$INPUT_FILE"
fi
