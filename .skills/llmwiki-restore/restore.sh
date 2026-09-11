#!/bin/bash
# llmwiki-restore — 把知识归档贴回一个 llmwiki 仓库
#
# Usage: ./scripts/restore.sh <归档路径或URL> [--target <目录>] [--force] [--dry-run]
#
# 只覆盖知识层（index.md / log.md / wiki/ / raw/），
# 框架文件（.skills/、AGENTS.md、README.md、scripts/、package.json 等）保持原样 ——
# 所以在刚拉下来的新模板上恢复，就得到"新框架 + 旧知识"。

set -euo pipefail

SRC=""
TARGET="$(pwd)"
FORCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
llmwiki-restore — 把知识归档贴回一个 llmwiki 仓库

Usage: ./scripts/restore.sh <归档路径或URL> [选项]

参数:
  <归档路径或URL>   本地 .tar.gz 路径，或 http(s)://、file:// 地址

选项:
  --target <目录>   恢复目标仓库，默认当前目录
  --force           目标已有知识时也覆盖（会先清空 wiki/ 和 raw/）
  --dry-run         只显示将要做的事，不写任何文件
  -h, --help        显示本帮助

只写知识层，不动框架文件。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      if [ $# -lt 2 ]; then echo "错误: --target 需要一个目录参数" >&2; exit 1; fi
      TARGET="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "错误: 未知参数 $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$SRC" ]; then echo "错误: 只能指定一个归档来源" >&2; exit 1; fi
      SRC="$1"; shift ;;
  esac
done

if [ -z "$SRC" ]; then
  echo "错误: 必须指定归档路径或 URL" >&2
  usage >&2
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "错误: 目标目录不存在: $TARGET" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------- 1. 取得归档 ----------

ARCHIVE=""
case "$SRC" in
  http://*|https://*)
    echo "下载归档: $SRC"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 -o "$TMP/archive.tar.gz" "$SRC"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "$TMP/archive.tar.gz" "$SRC"
    else
      echo "错误: 需要 curl 或 wget 下载远程归档" >&2
      exit 1
    fi
    ARCHIVE="$TMP/archive.tar.gz" ;;
  file://*)
    ARCHIVE="${SRC#file://}" ;;
  *)
    ARCHIVE="$SRC" ;;
esac

if [ ! -f "$ARCHIVE" ]; then
  echo "错误: 找不到归档文件: $ARCHIVE" >&2
  exit 1
fi

# ---------- 2. 解包 ----------

EXTRACT="$TMP/extract"
mkdir -p "$EXTRACT"
if ! tar -xzf "$ARCHIVE" -C "$EXTRACT" 2>/dev/null; then
  echo "错误: 不是有效的 .tar.gz 归档: $ARCHIVE" >&2
  exit 1
fi

MANIFEST="$(find "$EXTRACT" -maxdepth 2 -name manifest.json -type f 2>/dev/null | head -1)"
if [ -z "$MANIFEST" ]; then
  echo "错误: 归档里没有 manifest.json —— 这不是 llmwiki-export 产出的备份" >&2
  exit 1
fi
SRC_DIR="$(dirname "$MANIFEST")"

KIND="$(grep -o '"kind"[[:space:]]*:[[:space:]]*"[^"]*"' "$MANIFEST" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
if [ "$KIND" != "llmwiki-knowledge" ]; then
  echo "错误: manifest.json 的 kind 是 '$KIND'，期望 'llmwiki-knowledge'" >&2
  exit 1
fi

ARCHIVE_NAME="$(basename "$SRC_DIR")"

# ---------- 3. 校验和 ----------

if [ -f "$SRC_DIR/SHA256SUMS" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    if ( cd "$SRC_DIR" && sha256sum -c --status SHA256SUMS 2>/dev/null ); then
      echo "校验和  ✅ 全部通过"
    else
      echo "校验和  ⚠️ 有不匹配的文件（归档可能损坏）。继续前请确认。" >&2
      if [ "$FORCE" != 1 ]; then
        echo "         如确认要用，请加 --force" >&2
        exit 1
      fi
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if ( cd "$SRC_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1 ); then
      echo "校验和  ✅ 全部通过"
    else
      echo "校验和  ⚠️ 有不匹配的文件" >&2
      [ "$FORCE" != 1 ] && { echo "         如确认要用，请加 --force" >&2; exit 1; }
    fi
  fi
fi

# ---------- 4. 概览 ----------

# 取 JSON 里某个键的值（只做浅层提取，够用且不依赖 jq）
# 用 [^:]* 而非 .*：值里可能含冒号（时间戳 08:00:00Z），贪婪匹配会把值削掉
meta() { grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" "$MANIFEST" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' || true; }

echo "归档      $ARCHIVE_NAME"
echo "创建      $(meta created)"
echo "框架版本  $(meta commit) ($(meta branch))"
echo "含 raw    $(meta includesRaw)"
echo "内容      wiki 页 $(meta wikiPages) · 源 $(meta rawSources) · 日志 $(meta logEntries)"

# ---------- 5. 校验目标仓库 ----------

if [ ! -f "$TARGET/AGENTS.md" ] && [ ! -d "$TARGET/.skills" ]; then
  echo "错误: $TARGET 不像 llmwiki 仓库（缺 AGENTS.md / .skills/）" >&2
  echo "      请先 clone 模板: gh repo clone fb0sh/llmwiki <目录>" >&2
  exit 1
fi

EXISTING_PAGES=$(find "$TARGET/wiki" -type f -name '*.md' ! -name '_index_.md' 2>/dev/null | wc -l | tr -d ' ')
EXISTING_RAW=$(find "$TARGET/raw" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')

if [ "$EXISTING_PAGES" != "0" ] || [ "$EXISTING_RAW" != "0" ]; then
  if [ "$FORCE" != 1 ]; then
    echo >&2
    echo "错误: 目标仓库已有知识（wiki 页 ${EXISTING_PAGES} · 源 ${EXISTING_RAW}）" >&2
    echo "      $TARGET" >&2
    echo "      先备份它:  ./scripts/export.sh" >&2
    echo "      确认要覆盖: 加 --force（会清空目标的 wiki/ 和 raw/）" >&2
    exit 1
  fi
fi

# ---------- 6. 执行 ----------

RESTORED=""

restore_item() {
  local name="$1"
  if [ ! -e "$SRC_DIR/$name" ]; then
    return
  fi
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] 会写入 $name"
    RESTORED="$RESTORED $name"
    return
  fi
  if [ -d "$SRC_DIR/$name" ]; then
    if [ "$FORCE" = 1 ] && [ -d "$TARGET/$name" ]; then
      rm -rf "${TARGET:?}/$name"
    fi
    mkdir -p "$TARGET/$name"
    cp -R "$SRC_DIR/$name/." "$TARGET/$name/"
  else
    cp "$SRC_DIR/$name" "$TARGET/$name"
  fi
  RESTORED="$RESTORED $name"
}

echo
[ "$DRY_RUN" = 1 ] && echo "将恢复（dry-run，不写文件）:"
[ "$DRY_RUN" != 1 ] && echo "恢复:"

restore_item index.md
restore_item log.md
restore_item wiki
restore_item raw

if [ -z "$RESTORED" ]; then
  echo "  ⚠️ 归档里没有可恢复的知识层内容" >&2
  exit 1
fi

if [ "$DRY_RUN" != 1 ]; then
  # ---------- 7. 记录日志 ----------

  if [ -f "$TARGET/log.md" ]; then
    LOG_ENTRY="$(printf '\n## [%s] restore | 从 %s 恢复\n\n- 来源: %s\n- 覆盖: %s\n- 框架文件（.skills/、AGENTS.md、README.md 等）未改动\n' \
      "$(date +%Y-%m-%d)" "$ARCHIVE_NAME" "$SRC" "$(echo $RESTORED | sed 's/^ *//')")"
    printf '%s' "$LOG_ENTRY" >> "$TARGET/log.md"
  fi
fi

echo
echo "知识层:$(printf '%s' "$RESTORED" | sed 's/ /  /g')"
echo
if [ "$DRY_RUN" = 1 ]; then
  echo "（dry-run 结束，未写入任何文件）"
  exit 0
fi

echo "✅ 恢复完成。框架文件保持原样 —— 这就是「新框架 + 旧知识」的状态。"
echo
echo "下一步:"
echo "  1. npm install        # 装上 marked（生成静态网站用）"
echo "  2. 检查 git status     # 确认改动的都是知识层文件"
echo "  3. 让 agent 说'同步'   # 需要推到远程时"
