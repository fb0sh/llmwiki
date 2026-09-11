# LLM Wiki — 操作日志

## [2026-08-16] init | 模板重置

- 移除全部个人知识内容（raw 源文档、wiki 页面、索引与日志已由用户复制到别处）
- 重置 `raw/.ingest-state.json`、`index.md`、`wiki/_index_.md`、`log.md` 为模板初始状态
- 保留完整目录骨架（`.gitkeep`）与 `.skills/`、`scripts/`、`AGENTS.md` 工作流

## [2026-09-11] docs | 重写 README，收紧记忆边界

- `README.md` 重写：明确模板流程（Use this template → 私有仓库 → clone → `npm install` → 用任意编码 agent 打开），补上 `llmwiki-sync`、真实验证过的安装命令、版本控制取舍表、静态网站输出结构
- `AGENTS.md` 新增「记忆边界」：默认只读，只有人类明确要求或调用 skill 才写入；修正查询、归档、收尾流程中与之一致的自动写入表述
- `.skills/llmwiki-query/SKILL.md`：归档改为需人类确认
- `.gitignore`：放行 `raw/assets/.gitkeep`，让新克隆的模板带上附件目录
- `wiki/_index_.md`、`index.md`：去掉 pi 专属表述与"自动归档"说法
- 补回 mise 作为推荐的 Python 版本管理方式（修正原 README 的 `mise sync` —— 该命令只从其他版本管理器同步，不安装 `mise.toml` 里的版本；正确流程是 `mise trust && mise install`）

## [2026-09-11] sync | 上传 — 首次推送到 origin/main

- 方向：⬆ 上传（本地 → 远程），策略 ① 自动提交
- 变更：`README.md`、`AGENTS.md`、`.skills/llmwiki-query/SKILL.md`、`.gitignore`、`index.md`、`log.md`、`wiki/_index_.md`

## [2026-09-11] docs | 摄取改为 agent 主导

- 修正 `scripts/ingest.sh`：产物原本落在源文件所在目录，与脚本名/注释/README 说的"放入 raw/"不符，现在统一写入 `raw/`（含软链调用、从任意 cwd 调用、幂等跳过）；顺带修掉 `$MD_NAME」` 在 UTF-8 locale 下被 `set -u` 判为未绑定变量的报错
- `README.md` 使用一节改为 agent 主导：给路径/链接/文字即可，转换与落盘由 agent 完成；手动命令降为「自己动手（可选）」
- `AGENTS.md` 摄取工作流与 `.skills/llmwiki-ingest/SKILL.md` 明确：源可以在 `raw/` 之外（路径 / 链接 / 粘贴的文字），转换落盘是 agent 的职责，不应要求人类先转好或手动搬进来

## [2026-09-11] sync | 上传 — 摄取流程改为 agent 主导

- 方向：⬆ 上传（本地 → 远程），策略 ① 自动提交
- 变更：`README.md`、`AGENTS.md`、`.skills/llmwiki-ingest/SKILL.md`、`scripts/ingest.sh`、`log.md`
