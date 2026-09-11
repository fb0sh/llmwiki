#!/bin/bash
# llmwiki-export — 把知识层打包成可搬运的归档
#
# Usage: ./scripts/export.sh [--no-raw] [--out <目录>]
#
# 归档内容（框架文件不含在内）：
#   <名称>/manifest.json   元信息：时间、框架版本、各项计数
#   <名称>/SHA256SUMS      每个文件的校验和，恢复时可验证
#   <名称>/index.md        内容目录
#   <名称>/log.md          操作日志
#   <名称>/wiki/           编译知识
#   <名称>/raw/            源材料（--no-raw 排除）
#
# 不含 .skills/、AGENTS.md、README.md、scripts/ 等框架文件 ——
# 恢复时把这些留给新模板，这正是"框架升级、知识照搬"的路径。

set -euo pipefail

# 定位仓库根目录。
# 不能用 dirname/.. 硬推：本脚本实际在 .skills/llmwiki-export/（往上两层才是根），
# 而 scripts/export.sh 是指向它的软链（往上只要一层）。改为沿目录向上找到仓库标志。
resolve_script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  cd -P "$(dirname "$src")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"

find_root() {
  local d="$1"
  while [ "$d" != "/" ]; do
    if [ -f "$d/AGENTS.md" ] && [ -d "$d/wiki" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

if ! ROOT="$(find_root "$SCRIPT_DIR")"; then
  if ROOT="$(find_root "$(pwd)")"; then
    :
  else
    echo "错误: 找不到 llmwiki 仓库根目录（需要含 AGENTS.md 与 wiki/ 的目录）" >&2
    exit 1
  fi
fi
cd "$ROOT"

WITH_RAW=1
OUT_DIR="backups"

usage() {
  cat <<'EOF'
llmwiki-export — 把知识层打包成可搬运的归档

Usage: ./scripts/export.sh [选项]

选项:
  --no-raw        不包含 raw/ 源材料（归档更小，但源材料将没有备份）
  --out <目录>    输出目录，默认 backups/
  -h, --help      显示本帮助

产出: <输出目录>/llmwiki-knowledge-YYYYMMDD-HHMM.tar.gz
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-raw) WITH_RAW=0; shift ;;
    --out)
      if [ $# -lt 2 ]; then echo "错误: --out 需要一个目录参数" >&2; exit 1; fi
      OUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "错误: 未知参数 $1" >&2; usage >&2; exit 1 ;;
  esac
done

STAMP="$(date +%Y%m%d-%H%M)"
NAME="llmwiki-knowledge-${STAMP}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
ARCHIVE="$OUT_DIR/${NAME}.tar.gz"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
DEST="$STAGE/$NAME"
mkdir -p "$DEST"

# ---------- 收集知识层 ----------

INCLUDED=""
if [ -f index.md ]; then cp index.md "$DEST/"; INCLUDED="$INCLUDED index.md"; fi
if [ -f log.md ]; then cp log.md "$DEST/"; INCLUDED="$INCLUDED log.md"; fi
if [ -d wiki ]; then
  mkdir -p "$DEST/wiki"
  cp -R wiki/. "$DEST/wiki/"
  INCLUDED="$INCLUDED wiki/"
fi
if [ "$WITH_RAW" = 1 ]; then
  if [ -d raw ]; then
    mkdir -p "$DEST/raw"
    cp -R raw/. "$DEST/raw/"
    INCLUDED="$INCLUDED raw/"
  fi
fi

if [ -z "$INCLUDED" ]; then
  echo "错误: 没找到任何知识层内容（index.md / log.md / wiki/ / raw/）" >&2
  exit 1
fi

# ---------- 统计 ----------

WIKI_PAGES=$(find "$DEST/wiki" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
LOG_ENTRIES=0
if [ -f "$DEST/log.md" ]; then
  LOG_ENTRIES=$(grep -c '^## \[' "$DEST/log.md" 2>/dev/null || true)
  LOG_ENTRIES=${LOG_ENTRIES:-0}
fi
RAW_SOURCES=0
INGEST_HASHES=0
if [ "$WITH_RAW" = 1 ] && [ -d "$DEST/raw" ]; then
  RAW_SOURCES=$(find "$DEST/raw" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  if [ -f "$DEST/raw/.ingest-state.json" ]; then
    # 注意 || true：空的 ingest 状态（[]）会让 grep 无匹配而返回 1，
    # 在 set -e -o pipefail 下会直接终止脚本
    INGEST_HASHES=$(grep -o '[0-9a-f]\{64\}' "$DEST/raw/.ingest-state.json" 2>/dev/null | wc -l | tr -d ' ' || true)
    INGEST_HASHES=${INGEST_HASHES:-0}
  fi
fi

# ---------- 元信息 ----------

FRAMEWORK_COMMIT="unknown"
FRAMEWORK_BRANCH="unknown"
FRAMEWORK_DIRTY=0
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  FRAMEWORK_COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  FRAMEWORK_BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  FRAMEWORK_DIRTY="$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  FRAMEWORK_DIRTY=${FRAMEWORK_DIRTY:-0}
fi

if [ "$WITH_RAW" = 1 ]; then INCLUDES_RAW=true; else INCLUDES_RAW=false; fi

cat > "$DEST/manifest.json" <<EOF
{
  "format": 1,
  "kind": "llmwiki-knowledge",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "includesRaw": $INCLUDES_RAW,
  "framework": {
    "commit": "$FRAMEWORK_COMMIT",
    "branch": "$FRAMEWORK_BRANCH",
    "dirtyFiles": $FRAMEWORK_DIRTY
  },
  "counts": {
    "wikiPages": $WIKI_PAGES,
    "rawSources": $RAW_SOURCES,
    "ingestHashes": $INGEST_HASHES,
    "logEntries": $LOG_ENTRIES
  },
  "included": "$(echo $INCLUDED | sed 's/^ *//')"
}
EOF

# ---------- 校验和 ----------

HASHER=""
if command -v sha256sum >/dev/null 2>&1; then
  HASHER="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASHER="shasum -a 256"
fi

if [ -n "$HASHER" ]; then
  ( cd "$DEST" && find . -type f ! -name SHA256SUMS | LC_ALL=C sort | while IFS= read -r f; do
      $HASHER "$f"
    done > SHA256SUMS )
fi

# ---------- 打包 ----------

tar -czf "$ARCHIVE" -C "$STAGE" "$NAME"

SIZE="$(du -h "$ARCHIVE" | cut -f1)"

echo "✅ 已导出知识备份"
echo
echo "  归档      $ARCHIVE"
echo "  大小      $SIZE"
echo "  框架版本  $FRAMEWORK_COMMIT ($FRAMEWORK_BRANCH)"
echo "  内容      wiki 页 $WIKI_PAGES · 日志条目 $LOG_ENTRIES"
if [ "$WITH_RAW" = 1 ]; then
  echo "            源材料 $RAW_SOURCES · ingest hash $INGEST_HASHES"
else
  echo "            源材料未包含（--no-raw）"
fi
echo
echo "下一步：把归档拷到仓库之外（网盘 / 另一块盘）。backups/ 已在 .gitignore，不会进版本控制。"
