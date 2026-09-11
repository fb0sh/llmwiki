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

## [2026-09-11] feat | 新增 llmwiki-export / llmwiki-restore

- `llmwiki-export`（`scripts/export.sh`）：把知识层（`index.md` + `log.md` + `wiki/` + `raw/`）打包为 `backups/llmwiki-knowledge-<时间戳>.tar.gz`，附 `manifest.json`（时间 / 框架 commit / 各项计数）与 `SHA256SUMS`；`--no-raw` 可排除源材料。**框架文件不进归档**
- `llmwiki-restore`（`scripts/restore.sh`）：把归档贴回仓库，只写知识层，框架文件保持目标原样；支持本地路径 / http(s) / file:// 地址，远程归档自行下载；护栏 = 归档身份校验 + SHA256 校验 + 覆盖保护（`--force` 才覆盖），另有 `--dry-run`
- 意义：`raw/` 此前完全没有备份（`.gitignore` 排除），现在源材料第一次可被保住 —— 换机器 / 重装 / 回滚快照时，只有归档能还回 `raw/`
- `README.md`、`AGENTS.md`、`.gitignore`（忽略 `backups/`）同步更新
- 端到端实测：伪造知识 → export → 恢复到打了标记的新模板 → 框架文件未被改动；另测通 `--no-raw`、`--force`、`--dry-run`、URL 下载、篡改检测

## [2026-09-11] feat | 新增 llmwiki-update（框架更新）

- 起因：Use this template 只复制文件快照、不复制 git 历史，派生仓库与模板无共同祖先，`git merge upstream/main` 必然失败（`refusing to merge unrelated histories`），此前没有框架升级通道
- `llmwiki-update`（`scripts/update.sh`）：取上游文件树，只替换框架路径（`.skills/`、`.agents/`、`scripts/`、`AGENTS.md`、`README.md`、`package.json`、`package-lock.json`、`mise.toml`、`.gitignore`）；`index.md` / `log.md` / `wiki/` / `raw/` 永不触碰
- 选项：`--from`（换上游，可指自己的 fork）、`--target`（更新别的仓库，用于首次引导）、`--dry-run`、`--prune`（删除上游已移除的框架文件）、`--force`
- 取舍：本地自建 skill 默认保留只报告（避免被静默删除）；框架文件有未提交改动时拒绝，保证改动有 git 兜底；不自动提交
- 踩到两个坑并修掉：① 上游/本地为 shallow clone 时 ref 更新被拒（`shallow roots are not allowed to be updated`）→ 加 `--update-shallow`；② 历史无关导致 ref 更新非 fast-forward → 用 `+` 强制
- 实测：dry-run / 正式 / 护栏 / `--force` / `--prune` / 首次引导 / 真实 GitHub 上游取值，全部通过；每次均校验 `wiki/`、`raw/`、`index.md` 的 SHA256 未变

## [2026-09-11] docs | 修正 export/restore 的定位

- 问题：此前把「拉新模板 → restore 贴回知识」写成框架升级路径，但既有了 `update.sh`（就地更新、知识原地不动），这条路就是多余的
- 修正：`README.md`、`AGENTS.md`、三个 skill 的描述与交叉引用统一为 —— 框架升级只走 `update.sh`；export/restore 的用途是换机器补回 `raw/`、回滚知识快照、迁到新仓库
- 明确前提：若人类另有办法保住 `raw/`（网盘 / Time Machine / 整目录备份），export 的价值主要是「知识快照 + 可回滚」，非必需

## [2026-09-11] sync | 上传 — 备份/恢复/框架更新三条通道

- 方向：⬆ 上传（本地 → 远程），策略 ① 自动提交
- 变更：新增 `.skills/llmwiki-{export,restore,update}/` 与 `scripts/{export,restore,update}.sh`；修改 `README.md`、`AGENTS.md`、`.gitignore`、`log.md`

## [2026-09-11] docs | 补充代理用法

- `README.md` 首次更新一节加代理说明：网络不通 GitHub 时用 `ALL_PROXY=socks5h://...`，脚本内部 `git fetch` 同样受用；强调要 `socks5h`（代理解析域名）
- 背景：本机直连 GitHub HTTPS 超时、SSH 被沙箱阻挡，经 SOCKS5 代理（127.0.0.1:7890）打通
- 实测：逐字照抄 README 的引导命令跑通 —— 真实 GitHub 取模板 → 引导旧仓库 → `update.sh` 到位、知识层保留

## [2026-09-11] sync | 上传 — 补充代理说明（经代理推送）

- 方向：⬆ 上传（本地 → 远程），策略 ① 自动提交
- 说明：SSH 直连当前不可用（`~/.ssh` 控制套接字被沙箱阻挡），改用 HTTPS + SOCKS5 代理推送

## [2026-09-11] fix | 修正 update.sh 的输出措辞

- 问题：`update.sh` 会向 `log.md` 追加更新记录，但收尾同时打印「知识层未改动」，与实际行为自相矛盾
- 修正：改为「知识层内容未改动（仅在 log.md 追加了本条记录）」，日志条目内的措辞同步调整
- 发现途径：对真实 wiki（`~/Documents/wiki`）执行更新后，逐文件校验知识层哈希时才暴露

