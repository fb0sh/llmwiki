#!/bin/bash
# Ingest a source file into the LLM Wiki
# Usage: ./scripts/ingest.sh <file>
# 把源文件转成 Markdown 放进 raw/（raw/ 是只读源材料层；原文件留在原处不动）
# Converts non-md files to markdown:
#   office/PDF/EPUB/CSV -> anydoc (https://github.com/firecrawl/anydoc)
#   HTML -> pandoc (anydoc 不处理 HTML)
#   images/scanned PDF -> RapidOCR (see llmwiki-image-ocr skill)

set -euo pipefail

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# 定位仓库根目录（脚本可被软链或从任意目录调用）
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT/raw"
mkdir -p "$RAW"

BASENAME=$(basename "$FILE")
EXT="${BASENAME##*.}"
MD_NAME="${BASENAME%.*}.md"
MD_PATH="$RAW/$MD_NAME"

if [ "$EXT" = "md" ] || [ "$EXT" = "MD" ]; then
    if [ "$(cd "$(dirname "$FILE")" && pwd)/$BASENAME" = "$MD_PATH" ]; then
        echo "Already in place: $MD_PATH"
        exit 0
    fi
    echo "Copying $FILE to $MD_PATH..."
    cp "$FILE" "$MD_PATH"
    echo "Done: $MD_PATH"
    exit 0
fi

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
echo "下一步：让 agent 处理它 —— 说「处理这个新源 raw/${MD_NAME}」"
