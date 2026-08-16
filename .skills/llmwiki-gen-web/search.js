/**
 * llmwiki search — 客户端全文搜索
 * 加载 search.json，实时检索标题/标签/摘要/正文
 */
(function() {
  'use strict';

  var INDEX_URL = 'search.json';
  var idx = [];
  var input = document.getElementById('search-input');
  var results = document.getElementById('search-results');
  if (!input || !results) return;

  // load search index
  var xhr = new XMLHttpRequest();
  xhr.open('GET', INDEX_URL, true);
  xhr.onload = function() {
    if (xhr.status === 200) {
      try { idx = JSON.parse(xhr.responseText); } catch(e) { console.warn('search index parse error'); }
    }
  };
  xhr.send();

  // regex escape for user input
  function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  // highlight matching text with <span>
  function highlight(text, query) {
    if (!query) return text;
    var re = new RegExp('(' + escapeRe(query) + ')', 'gi');
    return text.replace(re, '<span class="match">$1</span>');
  }

  // excerpt around first match
  function excerpt(text, query, radius) {
    radius = radius || 50;
    var q = query.toLowerCase();
    var ci = text.toLowerCase().indexOf(q);
    if (ci === -1) return text.slice(0, radius * 2);
    var start = Math.max(0, ci - radius);
    var end = Math.min(text.length, ci + query.length + radius);
    var out = '';
    if (start > 0) out += '…';
    out += text.slice(start, end);
    if (end < text.length) out += '…';
    return out;
  }

  function doSearch(query) {
    if (!query || query.length < 1 || idx.length === 0) {
      results.classList.remove('show');
      results.innerHTML = '';
      return;
    }
    var q = query.toLowerCase();
    var hits = [];
    for (var i = 0; i < idx.length; i++) {
      var p = idx[i];
      var score = 0;
      var matchField = '';

      if (p.title.toLowerCase().indexOf(q) !== -1) { score += 10; matchField = 'title'; }
      for (var t = 0; t < p.tags.length; t++) {
        if (p.tags[t].toLowerCase().indexOf(q) !== -1) { score += 5; if (!matchField) matchField = 'tag'; }
      }
      if (p.summary && p.summary.toLowerCase().indexOf(q) !== -1) { score += 3; if (!matchField) matchField = 'summary'; }
      if (p.text && p.text.toLowerCase().indexOf(q) !== -1) { score += 1; if (!matchField) matchField = 'text'; }

      if (score > 0) {
        var preview = '';
        if (matchField === 'title' || score >= 8) {
          preview = p.summary || (p.text ? p.text.slice(0, 120) : '');
        } else if (matchField === 'tag') {
          preview = p.summary || (p.text ? p.text.slice(0, 120) : '');
        } else if (matchField === 'summary') {
          preview = p.summary;
        } else {
          preview = excerpt(p.text, query, 60);
        }
        preview = highlight(preview, query);
        hits.push({ score: score, title: p.title, path: p.path, preview: preview });
      }
    }

    hits.sort(function(a, b) { return b.score - a.score; });
    hits = hits.slice(0, 20);

    if (hits.length === 0) {
      results.innerHTML = '<p style="color:#6b7280;font-size:.9rem">未找到匹配结果</p>';
    } else {
      var html = '<p style="color:#6b7280;font-size:.85rem;margin-bottom:.5rem">找到 ' + hits.length + ' 个结果</p>';
      for (var h = 0; h < hits.length; h++) {
        html += '<div class="result"><a href="' + hits[h].path + '">' + highlight(hits[h].title, query) + '</a><div class="preview">' + hits[h].preview + '</div></div>';
      }
      results.innerHTML = html;
    }
    results.classList.add('show');
  }

  var timer = null;
  input.addEventListener('input', function() {
    clearTimeout(timer);
    timer = setTimeout(function() { doSearch(input.value.trim()); }, 200);
  });
})();
