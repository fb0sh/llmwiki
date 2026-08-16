# LLM Wiki

一个由 LLM 持久维护的个人知识库。知识被编译一次、持续更新，不会从零推导。

> **LLM 写，人类读** — LLM 负责书摘、交叉引用、文件管理。人类负责策展源材料、提问、指导方向。

## 工作流

```
放入源 → LLM 读 → 写摘要 → 更新概念/实体 → 维护索引 → 下次查询直接回答
```

## 前置条件

```bash
# 1. 确保 Python 可用（mise 管理）
mise sync
mise install python@3.12  # 如果还没有

# 2. 安装 anydoc（Firecrawl 出品，将任意文档转为 GFM Markdown）
npm install -g @firecrawl/anydoc

# 3. 安装 rapidocr（图片 OCR，anydoc 处理不了时的备选）
pip install rapidocr

# 4. 确认 pandoc 可用（HTML → Markdown 用，anydoc 不处理 HTML）
which pandoc   # macOS: brew install pandoc

# 5. 确认 pi 可用
pi --version
```

## 快速开始

### 从模板创建（Use this template）

最省事的启动方式：直接用本仓库做模板，创建你自己的 wiki。

```bash
# 1. 打开模板仓库，点击右上角绿色按钮
#    https://github.com/<你的用户名>/llmwiki  →  Use this template
#
# 2. 仓库名填 username/wiki 格式，例如：
#    <你的用户名>/llmwiki   →  你的用户名/你的wiki名
#
# 3. 克隆到本地
cd ~/Temp
gh repo clone 你的用户名/wiki   # 或: git clone git@github.com:你的用户名/wiki.git
cd wiki

# 4. 清掉模板自带的知识内容，从零开始（可选）
rm -rf raw/* wiki/* index.md
mkdir -p raw/assets wiki/concepts wiki/entities wiki/sources wiki/qa
```

> 模板自带完整的 `AGENTS.md` 行为规范、`.skills/` 工作流脚本和目录结构。克隆后只需把仓库地址换成自己的（`git remote set-url origin git@github.com:你的用户名/wiki.git`），然后开始放入源文档即可。

### 初始化环境

```bash
cd ~/Temp/wiki

# 确保 anydoc 就绪
which anydoc
```

### 放入新源

支持 Word、PPT、Excel、PDF、EPUB、CSV 等格式（HTML 自动用 pandoc 转换，图片用 RapidOCR）。

```bash
# 方式 A：用 ingest 脚本（自动转换 + 放入 raw/）
./scripts/ingest.sh ~/Downloads/某篇文章.pdf

# 方式 B：直接用 anydoc 转
anydoc 某文件.pdf -o raw/某文件.md

# 方式 C：手动放 markdown 进去
cp ~/Clippings/某篇文章.md raw/
```

然后启动 pi，让它处理：

```bash
pi
```

在 pi 交互中：

```
处理这个新源 raw/某文章.md
```

LLM 就会：
- 读原始文档
- 在 `wiki/sources/` 写摘要页
- 创建/更新 `wiki/concepts/` 和 `wiki/entities/` 页面
- 更新 `index.md` 和 `log.md`
- **SHA256 记录到 `raw/.ingest-state.json`，下次自动跳过**

### 批次处理

一口气丢了一堆文件？直接说：

```
处理 raw/ 里所有新文件
```

LLM 会扫描 `raw/`，对比 `raw/.ingest-state.json`，自动跳过已处理的，只处理新增和变更的。

### 查询

```bash
pi
```

直接问：

```
{你的问题，比如 "xxx 的核心论点是什么？"}
```

LLM 会先查 `index.md` 定位页面，读相关内容，综合回答。有价值的回答会自动归档到 `wiki/qa/`。

### 健康检查

在 pi 中：

```
健康检查
```

### 常用操作速查

| 你说 | LLM 做 |
|------|--------|
| "处理这个新源" | 摄取 → 摘要 → 更新关联页面 → 维护索引 |
| "处理 raw/ 里所有新文件" | 扫描 raw/ → SHA256 比对 → 只处理新增/变更 |
| 直接提问 | 查 wiki → 综合回答 → 归档新洞见 |
| "健康检查" 或 "lint" | 扫描矛盾、孤立页、过时声明、缺失交叉引用 |
| "生成网站" 或 "build site" | 将 wiki/ 编译为 html/ 学术风静态网站 |
| "OCR" 或 "识别图片文字" | 用 RapidOCR 提取图片文字 → 输出 Markdown → 可继续 ingest |
| "把这个记入 wiki" | 把刚发现的连接或洞见写到 wiki 中 |

## Skill 一览

| Skill | 用途 | 触发词 |
|-------|------|--------|
| `llmwiki-ingest` | 摄取新源 — 读源文档 → 写摘要 → 更新概念/实体页 → 维护索引 | "处理这个新源" / "ingest" |
| `llmwiki-query` | 查询 wiki 内容 — 读 index.md 定位页面 → 综合回答 → 归档新洞见 | 直接提问 |
| `llmwiki-doctor` | 健康检查 — 扫描矛盾页面、孤立页、过时声明、缺失交叉引用 | "健康检查" / "lint" |
| `llmwiki-gen-web` | 静态网站生成 — 将 wiki/ markdown 编译为学术风 HTML 到 html/ | "生成网站" / "build site" |
| `llmwiki-image-ocr` | 图片 OCR — anydoc 无法提取图片文字时，用 RapidOCR 识别并输出 Markdown | "OCR" / "识别图片文字" |

所有 skill 源码在 `.skills/` 目录下版本控制，`~/.agents/skills/` 下的同名目录是 pi 自动发现入口。

## 目录结构

```
llmwiki/
├── README.md             ← 本文件
├── AGENTS.md             ← 行为规范（LLM 读这个就知道怎么工作）
├── index.md              ← 内容目录（LLM 查这个定位页面）
├── log.md                ← 操作日志
├── .gitignore
├── mise.toml             ← Python 版本管理
├── .skills/              ← llmwiki 专用 skill（版本控制）
│   ├── llmwiki-ingest/   ← 摄取工作流
│   ├── llmwiki-query/    ← 查询工作流
│   ├── llmwiki-doctor/   ← 健康检查工作流
│   ├── llmwiki-gen-web/  ← 静态网站生成
│   └── llmwiki-image-ocr/← 图片 OCR 提取
├── .agents/               ← pi 项目级发现入口（软链 → .skills/）
├── raw/                  ← 原始文档（不可变）
│   ├── .gitkeep          ← 保持目录被 git 跟踪
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
    └── ingest.sh         ← 用 anydoc 一键转换并放入 raw
```

## 上传到 GitHub

```bash
# 1. 在 GitHub 新建仓库（不要勾选 README / .gitignore）
# 2. 在本地推
cd ~/Temp/wiki
git init
git add .
git commit -m "init: llmwiki personal knowledge base"
git remote add origin git@github.com:你的用户名/你的仓库名.git
git branch -M main
git push -u origin main
```

> 项目内置了 `.gitignore`，已排除系统文件和缓存。`raw/` 和 `wiki/` 的内容都会被追踪——它们是你的知识资产。

## 静态网站生成

将 `wiki/` 下的 markdown 编译为学术风简洁的 HTML 静态网站：

```bash
node .skills/llmwiki-gen-web/gen-web.js
```

输出到 `html/` 目录：

```
html/
├── index.html              ← 首页（统计 + 全部分类列表）
├── concepts/               ← 概念页
│   ├── index.html          ← 概念索引
│   ├── 示例概念1.html
│   ├── 示例概念2.html
│   └── ...
├── entities/               ← 实体页
│   ├── index.html
│   └── ...
└── sources/                ← 源摘要页
    ├── index.html
    └── ...
```

- **学术风排版**: Georgia 衬线正文，720px 阅读宽度，暖白背景
- **分类导航**: 面包屑 + 分类索引页 + 返回首页
- **内部链接**: wiki markdown 相对链接自动转为 `.html`
- **零外部依赖**: CSS 内联，`marked` 运行时安装
- **增量安全**: `html/` 已在 `.gitignore`，生成物不进版本控制

在 pi 中可直接说"生成网站"触发此流程。

`raw/.ingest-state.json` 仅维护一个 SHA256 哈希集合：

```json
["fa64a306e7...","bb68367e42..."]
```

- 计算文件 SHA256 → 查是否在集合中 → 不在则摄取并加入集合
- 不存文件名、时间、任何元数据 — 纯粹哈希集合
- **内容没变** → 同样的 hash → 跳过
- **内容更新** → 新 hash → 重新摄取
- **新文件** → 新 hash → 摄取

单行数组，存储最小化。支持单个源和批次两种模式。

## 相关工具

- **[anydoc](https://firecrawl.github.io/anydoc/)** — Firecrawl 出品，纯 Rust，Word/PPT/Excel/PDF/EPUB/CSV → GFM Markdown（格式从字节识别，中位数转换 < 5ms）
- **[pandoc](https://pandoc.org)** — 通用文档转换器，HTML → GFM Markdown（anydoc 不处理 HTML 时的补充）
- **[RapidOCR](https://github.com/RapidAI/RapidOCR)** — 开源 OCR 引擎，基于 PaddleOCR，支持中英文图片文字识别
- **[Obsidian Web Clipper](https://obsidian.com/clipper)** — 浏览器裁剪文章为 Markdown
- **[mise](https://mise.jdx.dev)** — 运行时版本管理（Python、Node 等）
- **[pi](https://github.com/earendil-works/pi-coding-agent)** — 编码助手，LLM wiki 的执行引擎

## 核心理念

传统 RAG 每次从裸文档重新检索和合成，没有积累。LLM Wiki 不同——LLM 作为知识库的"程序员"，你作为"产品经理"。LLM 处理繁琐的书摘工作（你会忘记更新交叉引用的），你只管放入好源、问好问题。

详细行为规范见 `AGENTS.md`，内容索引见 `index.md`。
