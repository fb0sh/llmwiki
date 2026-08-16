#!/usr/bin/env node
/**
 * llmwiki-gen-web — v3 并行优化版
 * 将 wiki/ markdown 编译为学术风 HTML 静态网站到 html/
 *
 * 优化:
 *  - import('marked') 替代逐文件 spawn npx (最大瓶颈)
 *  - Promise.all + 并发池并行处理页面
 *  - fs.promises 异步 I/O
 *  - 批量目录创建
 */
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const { execSync } = require('child_process');

const ROOT = process.cwd();
const WIKI = path.join(ROOT, 'wiki');
const SRC_INDEX = path.join(ROOT, 'index.md');
const OUT = path.join(ROOT, 'html');
const CONCURRENCY = Math.max(1, require('os').cpus().length - 1 || 2);

// ---------- helpers ----------

function parseFrontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) return { meta: {}, body: text };
  const yaml = m[1];
  const body = m[2].trimStart();
  const meta = {};
  for (const line of yaml.split('\n')) {
    const kv = line.match(/^(\w+):\s*(.+)$/);
    if (kv) {
      let val = kv[2].trim();
      if (val.startsWith('[') && val.endsWith(']')) {
        val = val.slice(1, -1).split(',').map(s => s.trim().replace(/^['"]|['"]$/g, ''));
      }
      const num = Number(val);
      if (!isNaN(num) && val !== '') val = num;
      meta[kv[1]] = val;
    }
  }
  return { meta, body };
}

function slug(name) {
  return name.replace(/\.md$/, '').replace(/[<>:"/\\|?*]/g, '_');
}

function stripHtml(html) {
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

function fixLinks(html) {
  // 1. Directory links from _index_.md: ../wiki/concepts/ → concepts/index.html
  html = html.replace(/href="\.\.\/wiki\/(concepts|entities|sources|qa)\//g, 'href="$1/index.html"');
  // 2. ../index.md → index.html (self-reference from _index_.md)
  html = html.replace(/href="\.\.\/index\.md"/g, 'href="index.html"');
  // 3. All other .md → .html (preserve raw/ links)
  html = html.replace(/href="([^"]+?)\.md"/g, (match, p1) => {
    if (p1.includes('/raw/')) return match;
    return `href="${p1}.html"`;
  });
  return html;
}

/** Concurrency-limited async pool: run async fns, at most concurrency at a time */
async function asyncPool(items, fn, concurrency) {
  const results = [];
  const executing = [];
  for (const item of items) {
    const p = Promise.resolve().then(() => fn(item));
    results.push(p);
    if (concurrency > 1 && items.length > concurrency) {
      const e = p.then(() => executing.splice(executing.indexOf(e), 1));
      executing.push(e);
      if (executing.length >= concurrency) {
        await Promise.race(executing);
      }
    }
  }
  return Promise.all(results);
}

// ---------- CSS + template ----------

const CSS = `*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,"Noto Serif SC",serif;font-size:16.5px;line-height:1.75;color:#1a1a1a;background:#fafaf8;padding:2rem 1rem}
.container{max-width:720px;margin:0 auto}
header{margin-bottom:2.5rem;padding-bottom:1rem;border-bottom:1px solid #e0ddd8}
header h1{font-family:system-ui,-apple-system,sans-serif;font-size:1.8rem;font-weight:600;letter-spacing:-0.02em}
header a{color:inherit;text-decoration:none}
.breadcrumb{font-family:system-ui,-apple-system,sans-serif;font-size:.85rem;color:#6b7280;margin-bottom:.5rem}
.breadcrumb a{color:#2563eb;text-decoration:none}
.breadcrumb a:hover{text-decoration:underline}
.meta{font-family:system-ui,-apple-system,sans-serif;font-size:.85rem;color:#6b7280;margin-bottom:2rem;display:flex;gap:.5rem;flex-wrap:wrap}
.meta .tag{display:inline-block;background:#e5e7eb;color:#374151;padding:.1rem .5rem;border-radius:3px;font-size:.8rem}
.content h2{font-family:system-ui,-apple-system,sans-serif;font-size:1.4rem;font-weight:600;margin:1.8rem 0 .8rem;letter-spacing:-0.01em;padding-bottom:.3rem;border-bottom:1px solid #e0ddd8}
.content h3{font-family:system-ui,-apple-system,sans-serif;font-size:1.15rem;font-weight:600;margin:1.5rem 0 .6rem}
.content h4{font-family:system-ui,-apple-system,sans-serif;font-size:1rem;font-weight:600;margin:1.2rem 0 .5rem}
.content p{margin-bottom:1em}
.content a{color:#2563eb;text-decoration:none}
.content a:hover{text-decoration:underline}
.content ul,.content ol{margin:.5rem 0 1rem 1.5rem}
.content li{margin-bottom:.3rem}
.content code{font-family:"SF Mono","Fira Code",monospace;font-size:.88em;background:#f0efec;padding:.15em .35em;border-radius:3px}
.content pre{background:#f0efec;padding:1rem;border-radius:6px;overflow-x:auto;font-size:.88em;margin:1rem 0}
.content pre code{background:none;padding:0}
.content blockquote{border-left:3px solid #d1d5db;padding-left:1rem;margin:1rem 0;color:#4b5563}
.content table{width:100%;border-collapse:collapse;margin:1rem 0;font-family:system-ui,sans-serif;font-size:.9rem}
.content th,.content td{border:1px solid #e0ddd8;padding:.5rem .75rem;text-align:left}
.content th{background:#f0efec;font-weight:600}
.content img{max-width:100%;height:auto;border-radius:4px;margin:1rem 0}
.content hr{border:none;border-top:1px solid #e0ddd8;margin:2rem 0}
footer{margin-top:3rem;padding-top:1rem;border-top:1px solid #e0ddd8;font-family:system-ui,sans-serif;font-size:.85rem;color:#6b7280}
footer a{color:#2563eb;text-decoration:none}
.page-list{list-style:none;margin:0}
.page-list li{padding:.6rem 0;border-bottom:1px solid #f0efec}
.page-list li:last-child{border-bottom:none}
.page-list a{font-size:1.05rem}
.page-list .desc{font-size:.85rem;color:#6b7280;margin-top:.15rem}
.hero{margin:2rem 0;padding:1.5rem;background:#f0efec;border-radius:8px;display:flex;gap:2rem;flex-wrap:wrap}
.hero .stat{font-family:system-ui,sans-serif;font-size:.9rem;color:#374151}
.hero .stat strong{font-size:1.8rem;display:block;font-weight:700;color:#1a1a1a}
.search-box{margin-bottom:2rem}
.search-box input{width:100%;padding:.75rem 1rem;font-size:1rem;font-family:system-ui,sans-serif;border:1px solid #d1d5db;border-radius:6px;background:#fff;outline:none;transition:border-color .15s}
.search-box input:focus{border-color:#2563eb;box-shadow:0 0 0 3px rgba(37,99,235,.1)}
.search-results{display:none;margin-bottom:2rem}
.search-results.show{display:block}
.search-results .result{padding:.75rem 0;border-bottom:1px solid #f0efec}
.search-results .result:last-child{border-bottom:none}
.search-results .result a{font-size:1.05rem}
.search-results .result .preview{font-size:.85rem;color:#6b7280;margin-top:.15rem}
.search-results .result .match{background:#fef3c7;padding:.05em .15em;border-radius:2px}
.search-hint{font-size:.8rem;color:#9ca3af;margin-top:.3rem}
@media(max-width:600px){body{padding:1rem;font-size:15px}header h1{font-size:1.4rem}}`;

function pageTemplate(title, breadcrumb, metaHtml, contentHtml) {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} — LLM Wiki</title>
  <style>${CSS}</style>
</head>
<body>
  <div class="container">
    <header>
      <div class="breadcrumb"><a href="index.html">LLM Wiki</a>${breadcrumb}</div>
      <h1><a href="index.html">LLM Wiki</a></h1>
    </header>
    <main>${metaHtml}<div class="content">${contentHtml}</div></main>
    <footer><a href="index.html">← 返回首页</a></footer>
  </div>
</body>
</html>`;
}

// ---------- main ----------

async function main() {
  const t0 = Date.now();

  // 0. Load marked programmatically (ESM dynamic import — avoids spawning npx per page)
  const { marked } = await import('marked');
  const renderMd = (md) => marked.parse(md, { async: false });

  // 1. Scan all wiki files
  const files = execSync('find wiki -name "*.md" | sort', { encoding: 'utf8', cwd: ROOT })
    .trim().split('\n').filter(Boolean);
  console.log(`Found ${files.length} wiki files`);

  // 2. Parse all files in parallel
  const pages = await asyncPool(files, async (fp) => {
    const text = await fsp.readFile(path.join(ROOT, fp), 'utf8');
    const { meta, body } = parseFrontmatter(text);
    const relPath = path.relative(WIKI, fp);
    return { file: fp, relPath, meta, body, title: meta.title || path.basename(fp, '.md') };
  }, CONCURRENCY);

  // 3. Parse index.md summaries
  const idxContent = await fsp.readFile(SRC_INDEX, 'utf8');
  const indexEntries = {};
  for (const line of idxContent.split('\n')) {
    const row = line.match(/^\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*([^|]+)/);
    if (row) {
      const p = row[2].replace(/^wiki\//, '').replace(/\.md$/, '');
      indexEntries[p] = row[3].trim();
    }
  }

  // 4. Categorize
  const categories = { concepts: [], entities: [], sources: [], qa: [], other: [] };
  for (const p of pages) {
    const cat = p.relPath.split('/')[0];
    if (cat === '_index_.md') { p.cat = 'root'; categories.root = p; }
    else if (categories[cat]) categories[cat].push(p);
    else categories.other.push(p);
  }

  // 5. Create output dirs (batch)
  const allDirs = ['', 'concepts', 'entities', 'sources', 'qa'].map(d => path.join(OUT, d));
  await Promise.all(allDirs.map(d => fsp.mkdir(d, { recursive: true })));

  // 6. Generate category listing pages (fast, sequential is fine)
  function genCategoryPage(catName, catLabel, items) {
    const cd = catName.toLowerCase();
    const listHtml = items.map(p => {
      const s = slug(path.basename(p.file));
      const summary = indexEntries[p.relPath.replace(/\.md$/, '')] || '';
      return `<li><a href="${s}.html">${p.title}</a><div class="desc">${summary}</div></li>`;
    }).join('\n');
    const html = pageTemplate(catLabel, ` › ${catLabel}`, '', `<h2>${catLabel} (${items.length})</h2><ul class="page-list">${listHtml}</ul>`);
    fsp.writeFile(path.join(OUT, cd, 'index.html'), html, 'utf8');
    console.log(`  ${path.join(OUT, cd, 'index.html')}`);
  }
  genCategoryPage('concepts', '概念', categories.concepts);
  genCategoryPage('entities', '实体', categories.entities);
  genCategoryPage('sources', '源摘要', categories.sources);
  genCategoryPage('qa', 'QA 归档', categories.qa);

  // 7. Generate individual pages (parallel with concurrency limit)
  const searchIndex = [];
  const pageTasks = pages.filter(p => p.cat !== 'root').map(p => async () => {
    const catDir = p.relPath.split('/')[0];
    const outName = slug(path.basename(p.file));
    const outPath = path.join(OUT, catDir, outName + '.html');
    const pageRelPath = `${catDir}/${outName}.html`;

    // Markdown → HTML (using programmatic marked, no subprocess)
    let bodyHtml = renderMd(p.body);
    bodyHtml = fixLinks(bodyHtml);

    let metaHtml = '';
    if (p.meta.tags && Array.isArray(p.meta.tags)) {
      metaHtml += '<div class="meta">' + p.meta.tags.map(t => `<span class="tag">${t}</span>`).join('') + '</div>';
    }
    if (p.meta.created) {
      metaHtml += `<div class="meta"><span>📅 ${p.meta.created}</span></div>`;
    }

    const html = pageTemplate(p.title, ` › <a href="${catDir}/index.html">${catDir}</a>`, metaHtml, bodyHtml);
    await fsp.writeFile(outPath, html, 'utf8');
    console.log(`  ${outPath}`);

    searchIndex.push({
      title: p.title,
      path: pageRelPath,
      summary: indexEntries[p.relPath.replace(/\.md$/, '')] || '',
      text: stripHtml(bodyHtml).slice(0, 1000),
      tags: Array.isArray(p.meta.tags) ? p.meta.tags : [],
    });
  });

  await asyncPool(pageTasks, fn => fn(), CONCURRENCY);

  // 8. Root index.html
  {
    const rootPage = categories.root;
    let bodyHtml = '';
    if (rootPage) {
      bodyHtml = fixLinks(renderMd(rootPage.body));
    }

    const statsMatch = idxContent.match(/总页面数:\s*(\d+).*?总源数:\s*(\d+)/s);
    const pageCount = statsMatch ? statsMatch[1] : '—';
    const sourceCount = statsMatch ? statsMatch[2] : '—';

    function parseTable(label) {
      const rows = [];
      let inSection = false;
      for (const line of idxContent.split('\n')) {
        if (line.includes('`wiki/' + label + '/`')) inSection = true;
        else if (line.startsWith('## ')) inSection = false;
        else if (inSection) {
          const row = line.match(/^\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*([^|]+)/);
          if (row) rows.push({ title: row[1], path: row[2], summary: row[3].trim() });
        }
      }
      return rows;
    }

    let listHtml = '';
    for (const sec of [{ label: '概念', items: parseTable('concepts') },
                        { label: '实体', items: parseTable('entities') },
                        { label: '源摘要', items: parseTable('sources') }]) {
      if (sec.items.length === 0) continue;
      listHtml += `<h2>${sec.label} (${sec.items.length})</h2><ul class="page-list">`;
      for (const item of sec.items) {
        listHtml += `<li><a href="${item.path.replace(/^wiki\//, '').replace(/\.md$/, '.html')}">${item.title}</a><div class="desc">${item.summary}</div></li>`;
      }
      listHtml += '</ul>';
    }

    const searchHtml = `<div class="search-box"><input type="text" id="search-input" placeholder="搜索全部页面…" autocomplete="off"><div class="search-hint">按关键词搜索所有概念、实体、源摘要</div></div><div class="search-results" id="search-results"></div><script src="search.js"></script>`;

    const html = pageTemplate('LLM Wiki', '', '',
      bodyHtml +
      searchHtml +
      `<div class="hero"><div class="stat"><strong>${sourceCount}</strong> 源文档</div><div class="stat"><strong>${pageCount}</strong> Wiki 页面</div></div>` +
      listHtml
    );
    await fsp.writeFile(path.join(OUT, 'index.html'), html, 'utf8');
    console.log(`  ${path.join(OUT, 'index.html')}`);
  }

  // 9. Write search.json + search.js
  await Promise.all([
    fsp.writeFile(path.join(OUT, 'search.json'), JSON.stringify(searchIndex), 'utf8'),
    fsp.copyFile(path.join(ROOT, 'scripts', 'search.js'), path.join(OUT, 'search.js')),
  ]);
  console.log(`  search.json (${searchIndex.length} entries)  search.js`);

  // 10. Summary
  const elapsed = ((Date.now() - t0) / 1000).toFixed(2);
  const totalFiles = execSync('find html -name "*.html" | wc -l', { encoding: 'utf8', cwd: ROOT }).trim();
  const totalSize = execSync('du -sh html/', { encoding: 'utf8', cwd: ROOT }).trim();
  console.log(`\n✅ Done in ${elapsed}s. Generated ${totalFiles} HTML files (${totalSize})`);
}

main().catch(e => { console.error(e); process.exit(1); });
