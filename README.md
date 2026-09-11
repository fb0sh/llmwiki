# LLM Wiki

一个由 LLM 持久维护的个人知识库。知识被编译一次、持续更新，不会从零推导。

> **LLM 写，人类读** — LLM 负责书摘、交叉引用、文件管理。人类负责策展源材料、提问、指导方向。

## 工作流

```
放入源 → LLM 读 → 写摘要 → 更新概念/实体 → 维护索引 → 下次查询直接回答
```

## 快速开始

本仓库是模板：[github.com/fb0sh/llmwiki](https://github.com/fb0sh/llmwiki)。四步得到你自己的 wiki。

### 1. 从模板创建仓库

打开 [github.com/fb0sh/llmwiki](https://github.com/fb0sh/llmwiki) → 右上角绿色按钮 **Use this template** → **Create a new repository**。

- 仓库名随意，例如 `my-wiki`
- 可见性选 **Private** —— 里面是你的个人知识

### 2. 克隆到本地

```bash
gh repo clone 你的用户名/my-wiki    # 或: git clone git@github.com:你的用户名/my-wiki.git
cd my-wiki
```

模板已自带完整目录结构、`AGENTS.md` 行为规范和 `.skills/` 工作流，克隆后无需清理，直接开始用。

### 3. 初始化

```bash
npm install                          # 安装 marked（生成静态网站用）
npm install -g @firecrawl/anydoc     # 文档转换；免安装可用 npx @firecrawl/anydoc
```

需要图片 OCR 的话，再用 mise 装 Python（推荐 —— 版本写在 `mise.toml` 里，换机器不用重新对齐）：

```bash
mise trust && mise install           # 首次必须先 trust，否则 mise 拒绝读本仓库的 mise.toml
pip install rapidocr
```

> 没装 mise 也可以用系统 Python，只是版本不受 `mise.toml` 约束。mise 安装见 [mise.jdx.dev](https://mise.jdx.dev)。

### 4. 开始使用

用你惯用的编码 agent（Claude Code、Codex、DSH、pi 等）打开这个目录。它会读 `AGENTS.md` 了解规范，并通过 `.agents/skills/`（软链到 `.skills/`）发现工作流。

```bash
cp ~/Clippings/某篇文章.md raw/     # 放入源文档
```

然后对 agent 说：

```
处理这个新源 raw/某篇文章.md
```

## 前置条件

| 工具 | 用途 | 安装 |
|------|------|------|
| Node.js + npm | 生成静态网站（依赖 `marked`） | `npm install` |
| anydoc | Word/PPT/Excel/PDF/EPUB/CSV → GFM Markdown（格式从字节识别） | `npm install -g @firecrawl/anydoc` |
| pandoc | HTML → Markdown（anydoc 不处理 HTML） | `brew install pandoc` |
| mise + Python + rapidocr | 图片、扫描 PDF 的 OCR（可选）。推荐用 mise 管 Python 版本 | `mise trust && mise install` + `pip install rapidocr` |

## 使用

日常只需要一句话：**把源交出去，剩下的 agent 做**。

```
把 ~/Downloads/某篇文章.pdf 处理进 wiki
这个链接存进 wiki：https://example.com/article
（或者直接把一段文字粘进对话）把这段存进 wiki
```

源可以是任意路径的文件、网页链接，或直接粘贴的文字；文件格式支持 Word、PPT、Excel、PDF、EPUB、CSV（HTML 走 pandoc，图片和扫描件走 RapidOCR）。

**转换、命名、搬进 `raw/` 都是 agent 的活。** 不需要自己先转成 Markdown，不用手动复制进 `raw/`；粘贴的文字也一样，agent 会把它写成 `raw/` 下的文件。

收到后它依次完成：

- 转成 Markdown 放进 `raw/`（源材料层，只读不改）
- 在 `wiki/sources/` 写摘要页
- 创建/更新 `wiki/concepts/` 和 `wiki/entities/` 页面
- 更新 `index.md` 和 `log.md`
- 把 SHA256 记入 `raw/.ingest-state.json`，下次自动跳过

### 自己动手（可选）

想自己控制转换过程时：

```bash
./scripts/ingest.sh ~/Downloads/某篇文章.pdf    # 转成 .md 并放进 raw/
anydoc 某文件.pdf -o raw/某文件.md              # 或直接调 anydoc
cp ~/Clippings/某篇文章.md raw/                 # markdown 直接复制进去
```

放好之后对 agent 说「处理这个新源 raw/某文件.md」，它接着写摘要和维护交叉引用。

### 批次处理

一口气丢了一堆文件？直接说：

```
处理 raw/ 里所有新文件
```

LLM 会扫描 `raw/`，对比 `raw/.ingest-state.json`，自动跳过已处理的，只处理新增和变更的。

### 查询

直接提问，例如「xxx 的核心论点是什么？」。LLM 先查 `index.md` 定位页面，读相关内容后综合回答。按下面的记忆边界，只有你明确要求归档时才写入 `wiki/qa/`。

### 健康检查

```
健康检查
```

或 `lint`。扫描矛盾、过时声明、孤立页面、缺失交叉引用。

### 同步

```
同步
```

LLM 会先问方向（⬆ 上传 / ⬇ 下载）再问策略，不擅自决定。

### 备份与恢复

`raw/` 源材料被 `.gitignore` 排除，git 里没有它 —— 要保住源材料只能靠备份。

```
备份
```

产出 `backups/llmwiki-knowledge-<时间戳>.tar.gz`，含 `index.md`、`log.md`、`wiki/`、`raw/`，附带 manifest 与 SHA256 校验和。

**它保的是 git 保不住的那一层。** `raw/` 源材料被 `.gitignore` 排除，所以：

| 层 | git 里有吗 | 需要 export 吗 |
|----|-----------|----------------|
| `wiki/`、`index.md`、`log.md` | ✅ 有 | 顺带打包（git 已覆盖） |
| `raw/` 源材料 | ❌ 没有 | **只能靠它** |
| `.ingest-state.json` | ✅ 有（但内容会与 raw 脱节） | 与源一起打包才自洽 |

换机器 clone 只会得到 `wiki/`，`raw/` 里空无一物，而 `wiki` 页面里到处是 `(src: raw/xxx.md)` 引用 —— 源材料只有归档能还回来。

什么时候要 restore：

| 场景 | 说明 |
|------|------|
| 换机器 / 重装 | clone 拿到 `wiki/`，再 restore 补回 `raw/` |
| 回滚知识 | 恢复到某个时间点的快照 |
| 迁到全新仓库 | 新仓库 restore 旧知识（历史全新） |

> 框架升级**不需要**它的参与 —— 那是 `update.sh` 的事，见下节；`update.sh` 是就地更新，不必克隆新模板再贴知识。

| 命令 | 作用 |
|------|------|
| `./scripts/export.sh` | 导出知识备份到 `backups/` |
| `./scripts/export.sh --no-raw` | 不含源材料（体积小，但源材料将无备份） |
| `./scripts/restore.sh <归档> --target <目录>` | 把归档恢复到指定仓库 |
| `./scripts/restore.sh <归档> --target <目录> --dry-run` | 只看会写什么，不动文件 |

> ⚠️ **备份要拷到仓库之外**（网盘 / 外置盘）。`backups/` 不进版本控制，留在本机不算备份。
>
> 恢复有三道护栏：归档身份校验、SHA256 校验、覆盖前保护（目标已有知识会拒绝，需 `--force`）。
>
> 如果你另有办法保住 `raw/`（网盘、Time Machine、外部备份），export/restore 的价值主要是「知识快照 + 可回滚」。

### 更新框架

**Use this template 只复制文件快照，不复制 git 历史** —— 派生仓库和模板没有共同祖先，`git pull upstream main` 会直接失败（`fatal: refusing to merge unrelated histories`）。所以框架更新走独立通道：只换框架文件，知识层一个字符都不动。

```
更新框架
```

```bash
./scripts/update.sh --dry-run    # 先看会改什么
./scripts/update.sh              # 正式更新
```

| 更新（覆盖） | 永不触碰 |
|--------------|----------|
| `.skills/`、`.agents/`、`scripts/`、`AGENTS.md`、`README.md`、`package.json`、`package-lock.json`、`mise.toml`、`.gitignore` | `index.md`、`log.md`、`wiki/`、`raw/` |

- 你自己加的 skill / 脚本**默认保留**（只报告），确认不要才加 `--prune`
- 本地框架文件有未提交改动时**会拒绝**，先提交或加 `--force`
- 换上游（比如你自己的模板 fork）：`--from <地址>`

**首次更新**（你的仓库里还没有这个脚本）：

```bash
cd 你的wiki
git clone --depth 1 https://github.com/fb0sh/llmwiki /tmp/llmwiki-template
/tmp/llmwiki-template/scripts/update.sh --target "$PWD"
rm -rf /tmp/llmwiki-template
```

之后直接 `./scripts/update.sh` 即可。

> 网络不通 GitHub 时（国内常见），给 git 加代理即可，脚本内部调用的 `git fetch` 同样受用：
>
> ```bash
> ALL_PROXY=socks5h://127.0.0.1:7890 git clone --depth 1 https://github.com/fb0sh/llmwiki /tmp/llmwiki-template
> ALL_PROXY=socks5h://127.0.0.1:7890 /tmp/llmwiki-template/scripts/update.sh --target "$PWD"
> ```
>
> 端口换成你自己代理的（Clash 常见 7890、V2Ray 常见 1080）。注意要 `socks5h`（h = 让代理解析域名），`socks5` 在部分环境下会连不上。

### 常用操作速查

| 你说 | LLM 做 |
|------|--------|
| "把 <路径/链接> 处理进 wiki" | 转换 → 放进 `raw/` → 摘要 → 更新关联页面 → 维护索引 |
| "处理这个新源"（源已在 `raw/`） | 摄取 → 摘要 → 更新关联页面 → 维护索引 |
| "处理 raw/ 里所有新文件" | 扫描 raw/ → SHA256 比对 → 只处理新增/变更 |
| 直接提问 | 查 wiki → 综合回答 |
| "记住" / "把这个记入 wiki" | 归档到 `wiki/qa/` 或更新对应页面 |
| "健康检查" 或 "lint" | 扫描矛盾、孤立页、过时声明、缺失交叉引用 |
| "同步" / "上传" / "下载" | commit + push 或 pull（方向与策略必问） |
| "备份" / "导出" | 把知识层打包成 `backups/*.tar.gz`（含 `raw/` 源材料） |
| "恢复" / "导入" + 归档地址 | 校验后把知识层贴回目标仓库，框架文件不动 |
| "更新框架" / "升级模板" | 从上游模板覆盖框架文件，知识层不动 |
| "生成网站" 或 "build site" | 把 `wiki/` 编译为 `html/` 学术风静态网站 |
| "OCR" 或 "识别图片文字" | RapidOCR 提取图片文字 → Markdown → 可继续 ingest |

## 记忆边界

默认只读。只有两种情况才写 wiki：

1. 你明确说「记住 / 记入 wiki / 归档 / 更新某页」
2. 你触发了 skill（ingest、query、doctor、sync、gen-web、image-ocr）—— skill 内部定义的写入属于授权范围

其余情况（闲聊、临时分析、一时联想到的可能性）只在对话中回答，不落盘：不改 `wiki/` 页面，不动 `index.md`、`log.md`，不记入 `raw/.ingest-state.json`。

## Skill 一览

| Skill | 用途 | 触发词 |
|-------|------|--------|
| `llmwiki-ingest` | 摄取新源 — 读源文档 → 写摘要 → 更新概念/实体页 → 维护索引 | "处理这个新源" / "ingest" |
| `llmwiki-query` | 查询 wiki 内容 — 读 index.md 定位页面 → 综合回答 | 直接提问 |
| `llmwiki-doctor` | 健康检查 — 扫描矛盾页面、孤立页、过时声明、缺失交叉引用 | "健康检查" / "lint" |
| `llmwiki-sync` | 仓库同步 — 上传（commit + push）或下载（pull），方向与策略必问 | "同步" / "上传" / "下载" |
| `llmwiki-export` | 知识备份 — 打包 `index.md` + `log.md` + `wiki/` + `raw/` 为 tar.gz（含 manifest 与校验和） | "备份" / "导出" / "export" |
| `llmwiki-restore` | 知识恢复 — 把归档贴回仓库（可给本地路径或 URL），只写知识层，框架文件不动 | "恢复" / "导入" / "restore" |
| `llmwiki-update` | 框架更新 — 从上游模板覆盖框架文件，绕过无关历史，知识层不动 | "更新框架" / "升级模板" / "update" |
| `llmwiki-gen-web` | 静态网站生成 — 把 `wiki/` markdown 编译为学术风 HTML 到 `html/` | "生成网站" / "build site" |
| `llmwiki-image-ocr` | 图片 OCR — anydoc 提不出文字时用 RapidOCR 识别并输出 Markdown | "OCR" / "识别图片文字" |

所有 skill 源码在 `.skills/` 下版本控制，`.agents/skills/` 是指向它的软链，作为编码 agent 的项目级发现入口。

## 目录结构

```
llmwiki/
├── README.md             ← 本文件
├── AGENTS.md             ← 行为规范（agent 读这个就知道怎么工作）
├── index.md              ← 内容目录（agent 查这个定位页面）
├── log.md                ← 操作日志
├── mise.toml             ← Python 版本（mise，OCR 用）
├── package.json          ← marked 依赖（静态网站用）
├── .gitignore
├── .skills/              ← llmwiki 专用 skill（版本控制）
│   ├── llmwiki-ingest/   ← 摄取工作流
│   ├── llmwiki-query/    ← 查询工作流
│   ├── llmwiki-doctor/   ← 健康检查工作流
│   ├── llmwiki-sync/     ← 仓库同步工作流
│   ├── llmwiki-export/   ← 知识备份（export.sh）
│   ├── llmwiki-restore/  ← 知识恢复（restore.sh）
│   ├── llmwiki-update/   ← 框架更新（update.sh）
│   ├── llmwiki-gen-web/  ← 静态网站生成（gen-web.js + search.js）
│   └── llmwiki-image-ocr/← 图片 OCR 提取
├── .agents/skills        ← 软链 → ../.skills/
├── backups/              ← 知识备份归档（不进版本控制）
├── raw/                  ← 原始文档（不可变）
│   ├── .gitkeep
│   ├── .ingest-state.json← SHA256 哈希集合（增量检测）
│   ├── assets/           ← 图片、附件
│   └── *.md / *.pdf      ← 源文档（任意格式）
├── wiki/                 ← 编译知识（LLM 写）
│   ├── _index_.md        ← 欢迎页
│   ├── concepts/         ← 概念页
│   ├── entities/         ← 实体页
│   ├── sources/          ← 源摘要
│   └── qa/               ← 归档查询
└── scripts/
    ├── ingest.sh         ← 用 anydoc/pandoc 一键转换并放入 raw
    ├── export.sh         ← 软链 → ../.skills/llmwiki-export/export.sh
    ├── restore.sh        ← 软链 → ../.skills/llmwiki-restore/restore.sh
    ├── update.sh         ← 软链 → ../.skills/llmwiki-update/update.sh
    ├── gen-web.js        ← 软链 → ../.skills/llmwiki-gen-web/gen-web.js
    └── search.js         ← 软链 → ../.skills/llmwiki-gen-web/search.js
```

## 版本控制

`.gitignore` 的取舍：

| 路径 | 入库 | 说明 |
|------|------|------|
| `wiki/`、`index.md`、`log.md` | ✅ | 编译产物 —— 你的知识资产 |
| `.skills/`、`scripts/`、`AGENTS.md`、`README.md` | ✅ | 工作流与规范 |
| `raw/.gitkeep`、`raw/assets/.gitkeep`、`raw/.ingest-state.json` | ✅ | 目录占位与增量检测状态（`raw/*` 规则的例外放行） |
| `raw/*`（源文档、`raw/assets/` 里的附件） | ❌ | 只留本地，仓库里只有编译结果 |
| `html/`、`backups/`、`node_modules/` | ❌ | 生成物、备份归档与依赖 |

因为源文档不入库，换机器 clone 后需要重新放入 `raw/`；已编译的 `wiki/` 页面不受影响。想连源材料一起搬，用「备份与恢复」里的 export / restore。

推到远程：对 agent 说「同步」，或自己 `git add` + `commit` + `push`。仓库远程地址就是模板克隆来的那个（`git remote set-url origin <你的仓库>` 可改）。

## 静态网站生成

```bash
npm install                          # 首次：安装 marked
node scripts/gen-web.js              # 等价于 node .skills/llmwiki-gen-web/gen-web.js
```

输出到 `html/` 目录：

```
html/
├── index.html              ← 首页（统计 + 分类列表 + 全文搜索框）
├── search.json             ← 全文搜索索引
├── search.js               ← 客户端搜索（从 scripts/search.js 复制）
├── concepts/               ← 概念页
│   ├── index.html          ← 概念索引
│   └── *.html
├── entities/               ← 实体页 + index.html
├── sources/                ← 源摘要页 + index.html
└── qa/                     ← 归档查询 + index.html
```

- **学术风排版**: Georgia 衬线正文，720px 阅读宽度，暖白背景
- **全文搜索**: 覆盖标题 / 标签 / 摘要 / 正文
- **分类导航**: 面包屑 + 分类索引页 + 返回首页
- **内部链接**: wiki markdown 相对链接自动转为 `.html`
- **零外部依赖**: CSS 内联，只需要 `marked`
- **增量安全**: `html/` 已在 `.gitignore`，生成物不进版本控制

脚本内部用 `find`/`du` 统计文件，Windows 下建议在 WSL 或 Git Bash 中执行。

在 agent 中可直接说「生成网站」触发此流程。

## 增量检测

`raw/.ingest-state.json` 只维护一个 SHA256 哈希集合：

```json
["fa64a306e7...","bb68367e42..."]
```

- 计算文件 SHA256 → 查是否在集合中 → 不在则摄取并加入集合
- 不存文件名、时间、任何元数据 —— 纯哈希集合
- **内容没变** → 同样的 hash → 跳过
- **内容更新** → 新 hash → 重新摄取
- **新文件** → 新 hash → 摄取

单行数组，存储最小化。支持单个源和批次两种模式。

## 相关工具

- **[anydoc](https://github.com/firecrawl/anydoc)** — Firecrawl 出品，纯 Rust，Word/PPT/Excel/PDF/EPUB/CSV → GFM Markdown
- **[pandoc](https://pandoc.org)** — 通用文档转换器，HTML → GFM Markdown（anydoc 不处理 HTML 时的补充）
- **[RapidOCR](https://github.com/RapidAI/RapidOCR)** — 开源 OCR 引擎，基于 PaddleOCR，支持中英文图片文字识别
- **[Obsidian Web Clipper](https://obsidian.com/clipper)** — 浏览器裁剪文章为 Markdown
- **[mise](https://mise.jdx.dev)** — 运行时版本管理，推荐用它锁定 Python 版本（版本写在 `mise.toml`，克隆后 `mise trust && mise install` 即可复现）
- **编码 agent** — Claude Code、Codex、DSH、[pi](https://github.com/earendil-works/pi-coding-agent) 等，任选其一作为 LLM Wiki 的执行引擎

## 核心理念

传统 RAG 每次从裸文档重新检索和合成，没有积累。LLM Wiki 不同——LLM 作为知识库的"程序员"，你作为"产品经理"。LLM 处理繁琐的书摘工作（你会忘记更新交叉引用的），你只管放入好源、问好问题。

详细行为规范见 `AGENTS.md`，内容索引见 `index.md`。
