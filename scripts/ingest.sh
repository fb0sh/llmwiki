#!/bin/bash
# Ingest a source file into the LLM Wiki
# Usage: ./scripts/ingest.sh <file>
# Converts non-md files to markdown:
#   office/PDF/EPUB/CSV -> anydoc (https://firecrawl.github.io/anydoc/)
#   HTML -> pandoc (anydoc 不处理 HTML)
#   images/scanned PDF -> RapidOCR (see llmwiki-image-ocr skill)

set -euo pipefail

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

BASENAME=$(basename "$FILE")
DIRNAME=$(dirname "$FILE")
EXT="${BASENAME##*.}"

if [ "$EXT" != "md" ] && [ "$EXT" != "MD" ]; then
    MD_NAME="${BASENAME%.*}.md"
    MD_PATH="$DIRNAME/$MD_NAME"
    if [ -f "$MD_PATH" ]; then
        echo "Already converted: $MD_PATH"
        exit 0
    fi
    if [ "$EXT" = "html" ] || [ "$EXT" = "htm" ]; then
        # anydoc 不支持 HTML；用 pandoc 转 GFM
        # 若想剥离网页导航/页脚/广告噪音，可改用: trafilatura --input-dir <dir> -o <dir> --output-format markdown
        echo "Converting HTML $FILE to $MD_PATH (pandoc)..."
        pandoc -f html -t gfm "$FILE" -o "$MD_PATH"
    else
        echo "Converting $FILE to $MD_PATH (anydoc)..."
        anydoc "$FILE" -o "$MD_PATH"
    fi
    echo "Done: $MD_PATH"
else
    echo "Already markdown: $FILE"
fi
