---
name: llmwiki-export
description: Use when the user says "备份", "导出", "export", "backup", "打包知识", "快照", wants a portable snapshot of the knowledge layer, is about to switch machines or reinstall, or wants the raw/ sources preserved since git ignores them. Produces a tar.gz of index.md + log.md + wiki/ + raw/ with a manifest and checksums. Do NOT use for syncing to the git remote (llmwiki-sync) or for framework upgrades (llmwiki-update — those need no backup).
---

# LLM Wiki — 知识备份（导出）

## 概述

把**知识层**打包成一个可搬运的归档：`index.md`、`log.md`、`wiki/`、`raw/`。**不含框架文件** —— 这样框架可以随时换成新模板，知识照搬回去，两边互不打架。

这是 `raw/` 唯一的备份途径：`.gitignore` 把 `raw/*` 排除在版本控制之外，只有这个归档能保住源材料。

## 工作流

```mermaid
flowchart TD
    A[用户说"备份"] --> B{确认是否包含 raw/}
    B -->|默认| C[包含 raw/]
    B -->|--no-raw| D[只备派生知识]
    C --> E[./scripts/export.sh]
    D --> E
    E --> F[收集 index.md / log.md / wiki/ / raw/]
    F --> G[写 manifest.json：时间 + 框架版本 + 计数]
    G --> H[写 SHA256SUMS 校验和]
    H --> I[打包到 backups/llmwiki-knowledge-时间戳.tar.gz]
    I --> J[报告路径 / 大小 / 内容统计]
    J --> K[提醒：把归档拷到仓库之外]
```

## 备份范围

| 层 | 内容 | 是否入归档 | 说明 |
|----|------|-----------|------|
| 知识 | `wiki/` | ✅ | 编译产物，核心资产 |
| 知识 | `index.md` | ✅ | 内容目录 |
| 知识 | `log.md` | ✅ | 操作日志 |
| 知识 | `raw/` | ✅（`--no-raw` 可排除） | 源材料 + `.ingest-state.json` |
| 框架 | `.skills/`、`AGENTS.md`、`README.md`、`scripts/`、`package.json`、`mise.toml` | ❌ | 恢复时留给新模板 |
| 生成物 | `html/`、`node_modules/`、`backups/` | ❌ | 可重新生成 |

**为什么默认带上 `raw/`：** 它承担四件事，都不是 `wiki/` 能替代的。

1. **核验** — 每个 wiki 声明都标 `(src: raw/xxx.md)`，没有 raw 这些引用全部悬空，无法验证摘要有没有写错
2. **重编译** — 摘要不满意、或 schema 改了（新增 frontmatter 字段等），要从原文重新推导
3. **矛盾检测** — `llmwiki-doctor` 对比不同源的说法时需要原文
4. **模型升级** — 换更强的模型重写摘要

若人类明确只想留派生知识，用 `--no-raw`；此时**不要**单独保留 `.ingest-state.json` —— 状态必须和 `raw/` 内容同步，否则会宣称处理过并不存在的文件。

## 操作步骤

### 1. 执行导出

```bash
./scripts/export.sh                 # 默认：含 raw/，输出到 backups/
./scripts/export.sh --no-raw        # 不含源材料
./scripts/export.sh --out ~/Desktop # 指定输出目录
```

输出：`backups/llmwiki-knowledge-YYYYMMDD-HHMM.tar.gz`

### 2. 核对结果

脚本会打印归档路径、大小、框架版本（git commit）、各项计数。检查：

- **框架版本** — 记下它，manifest 里也有；将来知道这份知识是从哪个模板版本导出的
- **源材料数 / ingest hash 数** — 应与 `raw/` 实际内容相符
- **大小** — 明显偏小通常意味着 `raw/` 是空的或没被包含

### 3. 报告给人类

必须说清两件事：

1. 归档在哪、多大
2. **归档要拷到仓库之外**（网盘 / 外置盘 / 另一台机器）—— `backups/` 在 `.gitignore` 里，不会被 git 推送，留在本机就等于没备份

## 归档结构

```
llmwiki-knowledge-20260911-1639/
├── manifest.json    # format / created / includesRaw / framework{commit,branch,dirtyFiles} / counts
├── SHA256SUMS       # 每个文件的校验和，llmwiki-restore 会校验
├── index.md
├── log.md
├── wiki/
└── raw/             # --no-raw 时不存在
```

## 常见错误

| 错误 | 正确做法 |
|------|----------|
| 备份完只留在 `backups/` | 明确提醒人类拷到仓库之外，本机不是备份 |
| 把 `.skills/`、`AGENTS.md` 也打进归档 | 框架不进归档，否则恢复时会用旧框架盖掉新模板 |
| 定期备份却不记录框架版本 | manifest 已自动记录 git commit，报告时一并说明 |
| 用 git 备份就以为 `raw/` 安全 | `raw/*` 被 `.gitignore` 排除，git 里没有源材料 |
| 排除 raw 却保留 ingest 状态 | 两者必须同进同出，状态与 raw 内容保持一致 |

## 交叉引用

- [llmwiki-restore](../llmwiki-restore/SKILL.md) — 把归档贴回新模板
- [llmwiki-sync](../llmwiki-sync/SKILL.md) — 日常与远程同步（与备份互补，不能互相替代）
- [AGENTS.md](../../AGENTS.md) — 完整的行为规范
