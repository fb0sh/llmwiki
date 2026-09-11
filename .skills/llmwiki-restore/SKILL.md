---
name: llmwiki-restore
description: Use when the user says "恢复", "还原", "导入", "restore", "import", gives a backup archive path or URL, or wants an exported knowledge archive applied onto a wiki — typically to bring raw/ sources back on a new machine, or to roll knowledge back to a snapshot. Restores only the knowledge layer (index.md, log.md, wiki/, raw/) and leaves framework files untouched. NOT for framework upgrades — that is llmwiki-update. NOT for pulling from the git remote — that is llmwiki-sync.
---

# LLM Wiki — 知识恢复（导入）

## 概述

把一个 `llmwiki-export` 产出的归档贴回 wiki 仓库。**只写知识层**（`index.md`、`log.md`、`wiki/`、`raw/`），框架文件（`.skills/`、`AGENTS.md`、`README.md`、`scripts/`、`package.json`、`mise.toml`）一个都不动。

不要把本流程当成框架升级的手段 —— 框架升级用 `llmwiki-update`（`./scripts/update.sh`），它是**就地**更新你现有的仓库，不需要克隆新模板、也不需要搬知识。

恢复真正要解决的场景：

| 场景 | 为什么需要它 |
|------|--------------|
| 换机器 / 重装 | clone 只带来 `wiki/`，`raw/` 源材料被 `.gitignore` 排除，只有归档能还回来 |
| 回滚知识 | 恢复到某个时间点的快照 |
| 迁到全新仓库 | 新仓库历史是干净的，restore 把旧知识搬进去 |

## 工作流

```mermaid
flowchart TD
    A[人类给出归档路径或 URL] --> B[取得归档: 本地路径 / http(s) / file://]
    B --> C[解包到临时目录]
    C --> D{有 manifest.json 且 kind 正确?}
    D -->|否| E[拒绝: 不是 llmwiki 备份]
    D -->|是| F[SHA256SUMS 校验]
    F -->|不匹配| G[警告, 无 --force 则拒绝]
    F -->|通过| H{目标像 llmwiki 仓库?}
    H -->|否| I[拒绝: 提示先 clone 模板]
    H -->|是| J{目标已有知识?}
    J -->|是且无 --force| K[拒绝: 提示先 export 备份]
    J -->|否 或 --force| L[复制知识层]
    L --> M[追加 log.md 的 restore 记录]
    M --> N[报告; 框架文件未改动]
```

## 操作步骤

### 1. 拿到归档位置

人类可以给任意一种：

| 形式 | 例子 |
|------|------|
| 本地路径 | `./backups/llmwiki-knowledge-20260911-1639.tar.gz` |
| 远程 URL | `https://example.com/llmwiki-knowledge-20260911-1639.tar.gz` |
| file URL | `file:///Users/me/backups/....tar.gz` |

远程地址由脚本自己下载（curl / wget），不必先手动下载。

### 2. 决定恢复到哪

**默认恢复到当前目录。** 目标是另一个仓库（新机器上刚 clone 的、或新克隆的模板）时，用 `--target` 指过去：

```bash
# 典型：新机器 clone 后补回 raw/ 源材料
git clone git@github.com:你的用户名/my-wiki.git
cd my-wiki
./scripts/restore.sh ~/backups/llmwiki-knowledge-20260911-1639.tar.gz --target .
```

### 3. 先 dry-run

写之前先看清楚会动什么：

```bash
./scripts/restore.sh <归档> --target <目录> --dry-run
```

会打印归档的来源、创建时间、框架版本、内容计数，以及将要写入的条目，**不写任何文件**。

### 4. 正式恢复

```bash
./scripts/restore.sh <归档> --target <目录>
```

脚本会：校验 manifest 与 SHA256SUMS → 确认目标是 llmwiki 仓库 → 确认目标没有既有知识（有则要求 `--force`）→ 复制知识层 → 在 `log.md` 追加一条 restore 记录。

### 5. 收尾

```bash
cd <目标目录>
npm install        # 装 marked
git status         # 确认改动的只有知识层文件
```

然后让人类决定是否说「同步」推送到远程。

## 安全护栏

脚本刻意设了三道闸，**不要绕过**：

| 闸 | 触发条件 | 行为 |
|----|----------|------|
| 归档身份 | 没有 `manifest.json` 或 `kind` 不是 `llmwiki-knowledge` | 拒绝，防止把任意 tar.gz 解开倒进仓库 |
| 完整性 | `SHA256SUMS` 校验不通过 | 拒绝（除非显式 `--force`），提示归档可能损坏 |
| 覆盖保护 | 目标已有 wiki 页或 `raw/` 源 | 拒绝，提示先 `./scripts/export.sh` 备份；确认覆盖才加 `--force` |

`--force` 语义：先清空目标的 `wiki/` 和 `raw/` 再写入。这是破坏性操作，**执行前必须让人类确认**。

## 恢复后是什么状态

- 知识层：归档里的版本
- 框架层：目标仓库原本的版本（**本流程不碰框架**；要升级框架用 `llmwiki-update`）
- `raw/`：归档含 raw 则一并对齐；`--no-raw` 的归档不含 raw，目标 `raw/` 保持原样
- `log.md`：归档内容 + 一条本次 restore 记录

## 常见错误

| 错误 | 正确做法 |
|------|----------|
| 把它当框架升级用 | 框架升级是 `./scripts/update.sh`（就地更新，不动知识） |
| 以为 git 已经保住了 raw/ | `raw/*` 被 `.gitignore` 排除，clone 后源材料是空的 |
| 把归档解到任意目录 | 必须先确认目标是 llmwiki 仓库（有 `AGENTS.md` / `.skills/`） |
| 不 dry-run 直接覆盖 | 先 `--dry-run` 看清将写入什么 |
| 在已有知识的仓库上直接恢复 | 先 `./scripts/export.sh` 备份，或明确确认后用 `--force` |
| 恢复完忘记 `npm install` | 新仓库没有 `node_modules`，生成网站会失败 |
| 拿它与 sync 混用 | 恢复是"搬知识"，sync 是"和远程对齐"，用途不同 |

## 交叉引用

- [llmwiki-export](../llmwiki-export/SKILL.md) — 产出归档
- [llmwiki-sync](../llmwiki-sync/SKILL.md) — 与远程同步
- [AGENTS.md](../../AGENTS.md) — 完整的行为规范
