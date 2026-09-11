---
name: llmwiki-update
description: Use when the user says "更新框架", "update", "升级模板", "拉上游", "同步模板改动", asks how to get template improvements into their own wiki, or wants framework files refreshed from fb0sh/llmwiki without touching knowledge. Works despite the template having no shared git history. Do NOT use for syncing the user's own GitHub remote — that is llmwiki-sync.
---

# LLM Wiki — 框架更新

## 概述

从上游模板（`fb0sh/llmwiki`）取最新**框架文件**更新本地仓库，**知识层一个字符都不动**。

## 为什么不能用 git merge

GitHub 的 **Use this template 只复制文件快照，不复制 git 历史**。派生仓库与模板没有共同祖先，所以：

```
$ git remote add upstream https://github.com/fb0sh/llmwiki.git
$ git fetch upstream && git merge upstream/main
fatal: refusing to merge unrelated histories
```

就算强行加 `--allow-unrelated-histories`，模板里的 `index.md`、`log.md`、`wiki/`、`raw/` 也会跟你自己的知识打架。

**本流程不靠合并**：直接取上游的文件树，按路径逐文件替换框架部分。历史无关性完全不影响。

## 框架 vs 知识

| | 路径 | 更新行为 |
|---|------|----------|
| 框架 | `.skills/`、`.agents/`、`scripts/`、`AGENTS.md`、`README.md`、`package.json`、`package-lock.json`、`mise.toml`、`.gitignore` | ✅ 用上游版本覆盖 |
| 知识 | `index.md`、`log.md`、`wiki/`、`raw/` | ❌ 永不触碰 |
| 忽略 | `backups/`、`html/`、`node_modules/` | ❌ 永不触碰 |

## 工作流

```mermaid
flowchart TD
    A[用户说"更新框架"] --> B[定位仓库根目录]
    B --> C{框架文件有未提交改动?}
    C -->|有且无 --force| D[拒绝: 先提交或加 --force]
    C -->|否| E[git fetch 上游]
    E --> F[git archive 解出上游文件树]
    F --> G[逐文件比较框架路径]
    G --> H[报告: 新增/更新/本地独有]
    H --> I{--dry-run?}
    I -->|是| J[只报告, 不写文件]
    I -->|否| K[覆盖框架文件]
    K --> L[--prune 时删除本地独有]
    L --> M[追加 log.md 记录]
    M --> N[提示 git diff / npm install]
```

## 操作步骤

### 1. 先 dry-run

**永远先看会改什么**：

```bash
./scripts/update.sh --dry-run
```

输出三类：上游带来的**新增/更新**、本地独有（上游没有）、以及最终提示。

### 2. 正式更新

```bash
./scripts/update.sh
```

常用变体：

```bash
./scripts/update.sh --from <你自己的模板 fork>   # 换上游地址
./scripts/update.sh --branch main                # 换分支
./scripts/update.sh --prune                      # 同时删除上游已移除的框架文件
./scripts/update.sh --force                      # 框架文件有未提交改动时也继续
./scripts/update.sh --target <目录>              # 更新另一个仓库
```

### 3. 收尾

```bash
git diff          # 复核框架改动
npm install       # package.json 有变时
```

然后由人类决定是否说「同步」推送。

## 首次更新（引导）

老旧仓库里还没有 `scripts/update.sh`，鸡生蛋问题。用上游的副本指向它即可：

```bash
cd 你的wiki
git clone --depth 1 https://github.com/fb0sh/llmwiki /tmp/llmwiki-template
/tmp/llmwiki-template/scripts/update.sh --target "$PWD"
rm -rf /tmp/llmwiki-template
```

跑完 `scripts/update.sh` 就位了，**以后直接 `./scripts/update.sh`**。人类也可以只对 agent 说「更新框架」，由 agent 执行这段引导。

## 设计取舍

**默认保留本地独有文件，不删。** 你可能自己加了 skill（`.skills/llmwiki-xxx/`）或脚本；整目录覆盖会静默删掉它们。所以默认只覆盖上游存在的文件，本地多出来的只**报告**、不删除，要删得显式 `--prune`。

**未提交的框架改动会被拒绝。** 更新是覆盖式的，如果本地框架文件有未提交改动，无从判断是你有意改的还是无意的，直接拒绝并要求先提交（或 `--force`）。这样你的改动永远有 git 兜底。

**不自动提交。** 脚本改完就停，让你先 `git diff` 复核；撤销用 `git checkout -- <框架路径>`。

## 与其它 skill 的分工

| 场景 | 用哪个 |
|------|--------|
| 框架升级、知识不动 | **本 skill**（`update.sh`） |
| 换机器 / 从备份搬知识 | `llmwiki-restore` |
| 备份知识（含 `raw/`） | `llmwiki-export` |
| 和**你自己的** GitHub 远程同步 | `llmwiki-sync` |

框架升级**只需要本 skill**：`update.sh` 是就地更新你现有的仓库，知识层原地不动，不需要 export、不需要克隆新模板、也不需要 restore。

export / restore 解决的是另一类问题：git 保不住 `raw/`（被 `.gitignore` 排除），换机器或回滚时才用得上。

## 常见错误

| 错误 | 正确做法 |
|------|----------|
| 用 `git merge upstream/main` | 历史无关，必然失败；用 `update.sh` |
| 加 `--allow-unrelated-histories` 硬合 | 会把模板的 `index.md`/`wiki/` 扯进来冲突 |
| 不 dry-run 直接更新 | 先 `--dry-run` 看清改动范围 |
| 无脑 `--prune` | 会删掉你自建的 skill；确认本地独有文件确实不要了再用 |
| 更新后忘记 `npm install` | `package.json` 变了就要重装依赖 |
| 把它当备份用 | 更新只动框架，不是备份；备份用 `llmwiki-export` |

## 交叉引用

- [llmwiki-export](../llmwiki-export/SKILL.md) — 备份知识层
- [llmwiki-restore](../llmwiki-restore/SKILL.md) — 把知识贴回新模板
- [llmwiki-sync](../llmwiki-sync/SKILL.md) — 与自己的远程同步
- [AGENTS.md](../../AGENTS.md) — 完整的行为规范
