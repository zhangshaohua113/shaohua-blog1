/* 韶华实验室 · 前端脚本：主题切换、知识库状态、阅读进度 */
(function () {
  'use strict';

  /* ============ 白天 / 夜晚主题切换 ============ */
  (function themeInit() {
    var btn = document.getElementById('themeBtn');
    var icon = btn ? btn.querySelector('.theme-icon') : null;
    var KEY = 'shaohua-theme';

    function current() {
      return document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
    }
    function apply(t) {
      document.documentElement.setAttribute('data-theme', t);
      if (icon) icon.textContent = t === 'dark' ? '🌙' : '☀️';
    }
    apply(current());
    if (btn) {
      btn.addEventListener('click', function () {
        var next = current() === 'dark' ? 'light' : 'dark';
        apply(next);
        try { localStorage.setItem(KEY, next); } catch (e) { /* 忽略 */ }
      });
    }
  })();

  /* ============ 页脚年份 ============ */
  var yearEl = document.getElementById('year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ============ 首页文章计数 ============ */
  var countEl = document.getElementById('postCount');
  if (countEl) {
    fetch('/api/posts.json', { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(); })
      .then(function (list) { countEl.textContent = '共 ' + list.length + ' 篇文章 · 1 个知识库'; })
      .catch(function () { /* 静默 */ });
  }

  /* ============ 阅读进度条（文章页） ============ */
  var bar = document.createElement('div');
  bar.className = 'scroll-progress';
  document.body.appendChild(bar);
  var style = document.createElement('style');
  style.textContent =
    '.scroll-progress{position:fixed;top:0;left:0;height:2px;width:0;' +
    'background:linear-gradient(90deg,var(--acc-1),var(--acc-2));z-index:99;' +
    'transition:width .1s linear;box-shadow:0 0 8px rgba(108,140,255,.6)}';
  document.head.appendChild(style);

  var ticking = false;
  function update() {
    var h = document.documentElement;
    var max = h.scrollHeight - h.clientHeight;
    bar.style.width = (max > 0 ? (h.scrollTop / max) * 100 : 0) + '%';
    ticking = false;
  }
  window.addEventListener('scroll', function () {
    if (!ticking) { ticking = true; requestAnimationFrame(update); }
  }, { passive: true });
  update();

  /* ============ 知识库索引：模块列表展开/收起（照抄独立版交互） ============ */
  (function kbCollapse() {
    var moreBtns = document.querySelectorAll('.card .more');
    if (!moreBtns.length) return;
    for (var i = 0; i < moreBtns.length; i++) {
      (function (btn) {
        btn.addEventListener('click', function () {
          var card = btn.closest('.card');
          if (!card) return;
          var modules = card.querySelector('.modules');
          if (!modules) return;
          var hiddenEls = modules.querySelectorAll('.kb-hide');
          var count = parseInt(btn.getAttribute('data-count') || '0', 10);
          var limit = parseInt(modules.getAttribute('data-limit') || '3', 10);
          if (hiddenEls.length === 0 || count === 0) {
            /* 已展开 -> 收起：重新隐藏超出的 */
            var all = modules.querySelectorAll('.mod');
            for (var k = 0; k < all.length; k++) {
              if (k >= limit) all[k].classList.add('kb-hide');
            }
            btn.textContent = '还有 ' + Math.max(0, all.length - limit) + ' 个 ▾';
            btn.setAttribute('data-count', String(Math.max(0, all.length - limit)));
          } else {
            for (var j = 0; j < hiddenEls.length; j++) hiddenEls[j].classList.remove('kb-hide');
            btn.textContent = '收起 ▴';
            btn.setAttribute('data-count', '0');
          }
        });
      })(moreBtns[i]);
    }
  })();

  /* ============ 知识库档案页：目录滚动高亮（scroll spy） ============ */
  (function kbScrollSpy() {
    var toc = document.querySelector('.kb-article .toc');
    var prose = document.querySelector('.kb-article .prose');
    if (!toc || !prose) return;

    var headings = prose.querySelectorAll('h2[id], h3[id]');
    if (!headings.length) return;

    var links = [];
    var linkEls = toc.querySelectorAll('a[href^="#"]');
    for (var i = 0; i < linkEls.length; i++) {
      var href = linkEls[i].getAttribute('href');
      if (href && href.length > 1) links.push({ el: linkEls[i], id: href.slice(1) });
    }

    var currentId = null;
    var OFFSET = 90;

    function setActive(id) {
      if (id === currentId) return;
      currentId = id;
      for (var i = 0; i < links.length; i++) {
        links[i].el.classList.toggle('active', links[i].id === id);
      }
      var active = toc.querySelector('a.active');
      if (active) {
        var t = toc.getBoundingClientRect();
        var a = active.getBoundingClientRect();
        if (a.top < t.top || a.bottom > t.bottom) {
          toc.scrollTop += a.top - t.top - 4;
        }
      }
    }

    var ticking = false;
    function update() {
      var current = null;
      for (var i = 0; i < headings.length; i++) {
        if (headings[i].getBoundingClientRect().top <= OFFSET) current = headings[i].id;
      }
      if (current === null && headings.length) current = headings[0].id;
      setActive(current);
      ticking = false;
    }

    window.addEventListener('scroll', function () {
      if (!ticking) { ticking = true; requestAnimationFrame(update); }
    }, { passive: true });
    window.addEventListener('resize', function () {
      if (!ticking) { ticking = true; requestAnimationFrame(update); }
    }, { passive: true });
    update();
  })();
})();