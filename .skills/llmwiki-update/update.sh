#!/bin/bash
# llmwiki-update — 从上游模板更新框架文件，知识层一个都不动
#
# Usage: ./scripts/update.sh [--from <url|路径>] [--branch <分支>] [--dry-run] [--prune] [--force]
#
# 背景：GitHub 的 "Use this template" 只复制文件快照，不复制 git 历史，
# 所以派生仓库和模板没有共同祖先，git merge / pull 会直接失败
# （fatal: refusing to merge unrelated histories）。
# 本脚本不靠合并，而是直接取上游的文件树，只替换框架路径。
#
# 更新（框架）：.skills/ .agents/ scripts/ AGENTS.md README.md
#               package.json package-lock.json mise.toml .gitignore
# 永不触碰（知识）：index.md log.md wiki/ raw/ 以及 backups/ html/ node_modules/

set -euo pipefail

DEFAULT_FROM="https://github.com/fb0sh/llmwiki.git"
DEFAULT_BRANCH="main"
UPSTREAM_REF_BASE="refs/llmwiki-upstream"

FRAMEWORK_PATHS=(
  .skills
  .agents
  scripts
  AGENTS.md
  README.md
  package.json
  package-lock.json
  mise.toml
  .gitignore
)

FROM="$DEFAULT_FROM"
BRANCH="$DEFAULT_BRANCH"
TARGET=""
DRY_RUN=0
PRUNE=0
FORCE=0

usage() {
  cat <<'EOF'
llmwiki-update — 从上游模板更新框架文件，知识层不动

Usage: ./scripts/update.sh [选项]

选项:
  --from <url|路径>   上游模板地址，默认 https://github.com/fb0sh/llmwiki.git
  --branch <分支>     上游分支，默认 main
  --target <目录>     要更新的仓库，默认脚本所在的仓库
                      （首次更新时你自己的仓库还没有本脚本，可用上游的副本指向它）
  --dry-run           只显示会改什么，不写任何文件（建议先跑一次）
  --prune             同时删除上游已不存在的框架文件（默认保留本地独有文件）
  --force             本地框架文件有未提交改动时也照常更新
  -h, --help          显示本帮助
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from)
      if [ $# -lt 2 ]; then echo "错误: --from 需要一个地址" >&2; exit 1; fi
      FROM="$2"; shift 2 ;;
    --branch)
      if [ $# -lt 2 ]; then echo "错误: --branch 需要一个分支名" >&2; exit 1; fi
      BRANCH="$2"; shift 2 ;;
    --target)
      if [ $# -lt 2 ]; then echo "错误: --target 需要一个目录" >&2; exit 1; fi
      TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --prune) PRUNE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "错误: 未知参数 $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ---------- 定位仓库根目录 ----------

resolve_script_dir() {
  local src="${BASH_SOURCE[0]}" dir
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  cd -P "$(dirname "$src")" && pwd
}

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

SCRIPT_DIR="$(resolve_script_dir)"

if [ -n "$TARGET" ]; then
  if [ ! -d "$TARGET" ]; then
    echo "错误: --target 目录不存在: $TARGET" >&2
    exit 1
  fi
  ROOT="$(cd "$TARGET" && pwd)"
  if [ ! -f "$ROOT/AGENTS.md" ] || [ ! -d "$ROOT/wiki" ]; then
    echo "错误: $ROOT 不像 llmwiki 仓库（缺 AGENTS.md 或 wiki/）" >&2
    exit 1
  fi
else
  if ! ROOT="$(find_root "$SCRIPT_DIR")"; then
    if ! ROOT="$(find_root "$(pwd)")"; then
      echo "错误: 找不到 llmwiki 仓库根目录（需要含 AGENTS.md 与 wiki/ 的目录）" >&2
      exit 1
    fi
  fi
fi
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "错误: $ROOT 不是 git 仓库 —— 更新依赖 git 取上游文件" >&2
  exit 1
fi

# ---------- 护栏：本地框架文件有未提交改动 ----------

if [ "$FORCE" != 1 ]; then
  DIRTY="$(git status --porcelain -- "${FRAMEWORK_PATHS[@]}" 2>/dev/null || true)"
  if [ -n "$DIRTY" ]; then
    echo "错误: 以下框架文件有未提交改动，更新会覆盖它们：" >&2
    printf '%s\n' "$DIRTY" | sed 's/^/  /' >&2
    echo >&2
    echo "  先提交:  git add -A && git commit -m 'chore: 保存本地框架改动'" >&2
    echo "  或强制:  加 --force" >&2
    exit 1
  fi
fi

# ---------- 取上游文件树 ----------

echo "上游      $FROM ($BRANCH)"
# --update-shallow: 上游或本地是浅克隆（shallow）时，否则更新已存在的 ref 会被拒绝，
#                   报 "shallow roots are not allowed to be updated"
# + 前缀: 派生仓库与模板历史无关，ref 更新不是 fast-forward
git fetch --no-tags --quiet --update-shallow "$FROM" "+$BRANCH:$UPSTREAM_REF_BASE/$BRANCH"
REF="$UPSTREAM_REF_BASE/$BRANCH"

UP_SHA="$(git rev-parse --short "$REF")"
UP_DATE="$(git log -1 --format=%cs "$REF" 2>/dev/null || echo unknown)"
echo "版本      $UP_SHA ($UP_DATE)"

UP="$(mktemp -d)"
trap 'rm -rf "$UP"' EXIT
git archive "$REF" | tar -x -C "$UP"

# ---------- 比较 ----------
# 只列框架路径，不去扫 node_modules / html / raw（既慢又没必要）

list_framework_rel() {
  local root="$1" p out=""
  for p in "${FRAMEWORK_PATHS[@]}"; do
    if [ -e "$root/$p" ] || [ -L "$root/$p" ]; then
      out="$out$(cd "$root" && find "$p" \( -type f -o -type l \) -print 2>/dev/null)
"
    fi
  done
  printf '%s' "$out" | LC_ALL=C sort | sed '/^$/d'
}

same_file() {
  if [ -L "$1" ] || [ -L "$2" ]; then
    if [ -L "$1" ] && [ -L "$2" ] && [ "$(readlink "$1")" = "$(readlink "$2")" ]; then
      return 0
    fi
    return 1
  fi
  if [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; then
    return 0
  fi
  return 1
}

# 路径是否存在（含断链软链）
exists() { [ -e "$1" ] || [ -L "$1" ]; }

UP_FILES="$(list_framework_rel "$UP")"
LOCAL_FILES="$(list_framework_rel "$ROOT")"

UPDATED=0
LOCAL_ONLY=0
CHANGED_LIST=""
LOCAL_ONLY_LIST=""

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! exists "$ROOT/$f"; then
    UPDATED=$((UPDATED + 1))
    CHANGED_LIST="${CHANGED_LIST}  新增  $f
"
  elif ! same_file "$UP/$f" "$ROOT/$f"; then
    UPDATED=$((UPDATED + 1))
    CHANGED_LIST="${CHANGED_LIST}  更新  $f
"
  fi
done <<< "$UP_FILES"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! exists "$UP/$f"; then
    LOCAL_ONLY=$((LOCAL_ONLY + 1))
    LOCAL_ONLY_LIST="${LOCAL_ONLY_LIST}  本地  $f
"
  fi
done <<< "$LOCAL_FILES"

# ---------- 报告 ----------

echo
if [ "$UPDATED" = 0 ]; then
  echo "✅ 框架已是最新，无需更新"
else
  echo "上游带来的改动（${UPDATED} 处）:"
  printf '%s' "$CHANGED_LIST" | head -40 || true
  if [ "$UPDATED" -gt 40 ]; then echo "  … 其余 $((UPDATED - 40)) 处省略"; fi
fi

if [ "$LOCAL_ONLY" != 0 ]; then
  echo
  echo "本地独有、上游没有的框架文件（${LOCAL_ONLY} 处）:"
  printf '%s' "$LOCAL_ONLY_LIST" | head -20 || true
  if [ "$PRUNE" = 1 ]; then
    echo "  → --prune 已启用：这些将被删除"
  else
    echo "  → 默认保留；确认要删可加 --prune"
  fi
fi

NOTHING_TO_DO=0
if [ "$UPDATED" = 0 ]; then
  if [ "$LOCAL_ONLY" = 0 ] || [ "$PRUNE" = 0 ]; then
    NOTHING_TO_DO=1
  fi
fi

if [ "$NOTHING_TO_DO" = 1 ]; then
  if [ "$DRY_RUN" = 1 ]; then echo; echo "（dry-run 结束，未写入任何文件）"; fi
  exit 0
fi

if [ "$DRY_RUN" = 1 ]; then
  echo
  echo "（dry-run 结束，未写入任何文件）"
  echo "确认无误后去掉 --dry-run 正式执行。"
  exit 0
fi

# ---------- 应用 ----------

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if ! exists "$ROOT/$f"; then
    mkdir -p "$(dirname "$ROOT/$f")"
    cp -Pp "$UP/$f" "$ROOT/$f"
  elif ! same_file "$UP/$f" "$ROOT/$f"; then
    rm -f "$ROOT/$f"
    cp -Pp "$UP/$f" "$ROOT/$f"
  fi
done <<< "$UP_FILES"

if [ "$PRUNE" = 1 ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! exists "$UP/$f"; then
      rm -f "$ROOT/$f"
    fi
  done <<< "$LOCAL_FILES"
  # 清掉 --prune 后留下的空目录（仅限框架目录内）
  for p in "${FRAMEWORK_PATHS[@]}"; do
    if [ -d "$ROOT/$p" ]; then
      find "$ROOT/$p" -type d -empty -delete 2>/dev/null || true
    fi
  done
fi

# ---------- 记录日志 ----------

if [ -f "$ROOT/log.md" ]; then
  PRUNE_NOTE=""
  if [ "$PRUNE" = 1 ] && [ "$LOCAL_ONLY" != 0 ]; then
    PRUNE_NOTE="，并清理 ${LOCAL_ONLY} 处本地独有文件"
  fi
  {
    printf '\n## [%s] update | 框架更新到 %s\n\n' "$(date +%Y-%m-%d)" "$UP_SHA"
    printf -- '- 上游: %s (%s)\n' "$FROM" "$BRANCH"
    printf -- '- 覆盖: %s 处框架文件%s\n' "$UPDATED" "$PRUNE_NOTE"
    printf -- '- 知识层（index.md / log.md / wiki/ / raw/）未改动\n'
  } >> "$ROOT/log.md"
fi

echo
echo "✅ 框架已更新到 $UP_SHA"
echo
echo "知识层未改动。建议接着做:"
echo "  1. git diff              # 复核框架改动"
echo "  2. npm install           # package.json 有变时重装依赖"
echo "  3. 让 agent 说「同步」   # 需要推送时"
echo
echo "想撤销: git checkout -- ${FRAMEWORK_PATHS[*]}"
