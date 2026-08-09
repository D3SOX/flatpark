// Header type-ahead: results drop out of the search box itself, on every page.
//
// The catalog is small (tens of apps), so the whole index ships as one JSON
// file and every keystroke is a linear scan in the browser — no search service,
// which is what a static site can afford. The index is fetched on first use and
// then lives in a module-level promise, so it is paid for once per session.
//
// Matching is token-AND over whitespace: every token must hit *something* on an
// app — name, id, tags, summary, or the app's category — so a second word
// narrows the set instead of widening it. Because a category name is part of
// the haystack and scores near the top, typing "ai" lists the whole AI section
// (plus the category itself as a jump target), and adding "claude" cuts that
// down to the handful of apps that match both.
//
// The summary counts as much as anything else, deliberately: what an app *does*
// ("torrent", "markdown", "screenshot") is often nowhere in its name, and
// people search for the thing, not the brand. A token that matches nothing
// literally falls back to a subsequence match — which forgives "vscd" for
// "VSCode" and "editr" for "editor" — but only against single words, never
// across a whole sentence, since any four letters appear in order somewhere in
// a long enough string and that would match everything.

const APP_LIMIT = 8; // rows before the panel starts saying "+N more"
const CATEGORY_LIMIT = 3;

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

const fill = (tpl, vars) =>
  Object.entries(vars).reduce((out, [k, v]) => out.split(`{${k}}`).join(String(v)), tpl);

/**
 * fzf-ish subsequence score: every needle character must appear in order.
 * Consecutive hits and word starts are worth more, so "vsc" ranks "VSCode"
 * above a name where the same letters are scattered. -1 means no match.
 */
function subsequence(hay, needle) {
  let n = 0;
  let score = 0;
  let streak = 0;
  for (let h = 0; h < hay.length && n < needle.length; h++) {
    if (hay[h] !== needle[n]) {
      streak = 0;
      continue;
    }
    streak++;
    score += 1 + streak;
    if (h === 0 || /[\s\-_.]/.test(hay[h - 1])) score += 2;
    n++;
  }
  return n === needle.length ? score : -1;
}

/** True when `tok` starts a word inside `hay` ("code" in "Visual Studio Code"). */
const wordStart = (hay, tok) => new RegExp(`(^|[\\s\\-_.])${escapeRe(tok)}`).test(hay);
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Words of a lowercased string, for per-word fuzzy matching. */
const wordsOf = (text) => text.split(/[^a-z0-9]+/).filter(Boolean);

/**
 * Best subsequence score of `tok` against any single word, so a typo is
 * forgiven inside a word without the match smearing across a sentence. The
 * token has to cover at least half the word: without that, "ledg" matches
 * "know(l)e(dg)ebase" and every other long word that happens to contain those
 * letters in order.
 */
function fuzzyWords(words, tok) {
  let best = -1;
  for (const word of words) {
    if (word.length < 3 || tok.length * 2 < word.length) continue;
    const score = subsequence(word, tok);
    if (score > best) best = score;
  }
  return best;
}

/**
 * How well one token matches one app. 0 means "not at all", which drops the app
 * from the results entirely (tokens are ANDed). The tiers are what decides
 * ordering, so they are deliberately far apart: an exact name beats a category,
 * a category beats a summary mention, and a fuzzy hit sits below all of them.
 */
function scoreToken(app, tok) {
  let best = 0;
  const bump = (n) => {
    if (n > best) best = n;
  };

  if (app.nameL === tok) bump(1000);
  else if (app.nameL.startsWith(tok)) bump(400);
  else if (wordStart(app.nameL, tok)) bump(300);
  else if (app.nameL.includes(tok)) bump(200);

  // A category hit ranks just under a name hit: it is how "ai" pulls up the
  // whole section rather than only the apps with "ai" in their name.
  if (app.sectionL === tok || app.categoryL === tok) bump(260);
  else if (app.categoryL.startsWith(tok) || app.sectionL.startsWith(tok)) bump(180);

  for (const tag of app.tagsL) {
    if (tag === tok) bump(240);
    else if (tag.startsWith(tok)) bump(160);
    else if (tag.includes(tok)) bump(110);
  }

  // The id only counts on a word start: it is dotted reverse-DNS, and its
  // middle is vendor boilerplate nobody searches for.
  if (wordStart(app.idL, tok)) bump(120);

  // What the app says it does. A word start ("a *markdown* editor") is worth
  // more than a token buried mid-word, which is how a two-letter token like
  // "ai" reaches "pl(ai)n-text accounting" — real, but weak.
  if (wordStart(app.summaryL, tok)) bump(95);
  else if (tok.length >= 3 && app.summaryL.includes(tok)) bump(60);

  if (best) return best;

  // Fuzzy is the last resort and needs something to go on: two-letter tokens
  // are a subsequence of almost anything, so they stay literal.
  if (tok.length >= 3) {
    const byName = subsequence(app.nameL, tok);
    if (byName >= 0) bump(40 + byName);
    const byTag = fuzzyWords(app.tagsL, tok);
    if (byTag >= 0) bump(30 + byTag);
    const bySummary = fuzzyWords(app.summaryWords, tok);
    if (bySummary >= 0) bump(20 + bySummary);
    const byId = fuzzyWords(app.idWords, tok);
    if (byId >= 0) bump(15 + byId);
  }
  return best;
}

/**
 * Precompute the lowercase fields every keystroke would otherwise recompute,
 * and derive the category list (with counts) from the apps themselves, so the
 * dropdown only ever offers sections that actually have something in them.
 * `sections` maps a section slug to its label in the reader's language.
 */
export function buildIndex(apps, sections = {}) {
  const label = (slug) => sections[slug] || slug;
  const list = apps.map((a) => ({
    ...a,
    label: label(a.section),
    nameL: a.name.toLowerCase(),
    idL: a.id.toLowerCase(),
    summaryL: (a.summary || '').toLowerCase(),
    sectionL: a.section.toLowerCase(),
    categoryL: label(a.section).toLowerCase(),
    tagsL: (a.tags || []).map((tag) => tag.toLowerCase()),
    summaryWords: wordsOf((a.summary || '').toLowerCase()),
    idWords: wordsOf(a.id.toLowerCase()),
  }));

  const counts = new Map();
  for (const app of list) counts.set(app.section, (counts.get(app.section) || 0) + 1);
  const categories = [...counts].map(([slug, n]) => ({
    slug,
    n,
    label: label(slug),
    labelL: label(slug).toLowerCase(),
  }));

  return { apps: list, categories };
}

/** Everything one query turns into: its tokens, matching categories, ranked apps. */
export function runQuery(index, raw) {
  const tokens = raw.trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (!tokens.length) return { tokens, categories: [], apps: [] };

  const hits = [];
  for (const app of index.apps) {
    let total = 0;
    for (const tok of tokens) {
      const score = scoreToken(app, tok);
      if (!score) {
        total = 0;
        break;
      }
      total += score;
    }
    if (total) hits.push({ app, score: total });
  }
  hits.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));

  return { tokens, categories: matchCategories(index.categories, tokens), apps: hits };
}

/** Categories a token names outright — the "type `ai`, get the AI section" path. */
function matchCategories(categories, tokens) {
  const hits = [];
  for (const cat of categories) {
    let score = 0;
    for (const tok of tokens) {
      if (cat.labelL === tok || cat.slug === tok) score = Math.max(score, 300);
      else if (cat.labelL.startsWith(tok) || cat.slug.startsWith(tok)) score = Math.max(score, 200);
      else if (cat.labelL.includes(tok)) score = Math.max(score, 120);
    }
    if (score) hits.push({ ...cat, score });
  }
  return hits.sort((a, b) => b.score - a.score || b.n - a.n).slice(0, CATEGORY_LIMIT);
}

/** Wrap every occurrence of any token in `text` so matches read at a glance. */
function highlight(text, tokens) {
  const lower = text.toLowerCase();
  const spans = [];
  for (const tok of tokens) {
    let from = 0;
    for (;;) {
      const at = lower.indexOf(tok, from);
      if (at === -1) break;
      spans.push([at, at + tok.length]);
      from = at + tok.length;
    }
  }
  if (!spans.length) return escapeHtml(text);

  spans.sort((a, b) => a[0] - b[0]);
  const merged = [];
  for (const span of spans) {
    const last = merged[merged.length - 1];
    if (last && span[0] <= last[1]) last[1] = Math.max(last[1], span[1]);
    else merged.push([...span]);
  }

  let out = '';
  let at = 0;
  for (const [start, end] of merged) {
    out += `${escapeHtml(text.slice(at, start))}<b class="text-brand">${escapeHtml(
      text.slice(start, end),
    )}</b>`;
    at = end;
  }
  return out + escapeHtml(text.slice(at));
}

export function initSearch(strings) {
  const root = document.querySelector('[data-search-root]');
  const input = document.querySelector('[data-search]');
  const panel = document.querySelector('[data-search-panel]');
  if (!root || !input || !panel) return;

  // Locale-dependent bits the index itself cannot carry: the category labels in
  // the reader's language, and the path prefix their pages live under.
  let meta = { base: '/', sections: {} };
  try {
    meta = { ...meta, ...JSON.parse(document.querySelector('[data-search-meta]')?.textContent || '{}') };
  } catch {}
  const appPath = (id) => `${meta.base}apps/${id}/`;
  const categoryPath = (slug) => `${meta.base}apps/?section=${encodeURIComponent(slug)}`;

  let index = null;
  let loading = null;
  let rows = [];
  let active = -1;

  // One fetch per session; a failure clears the promise so the next keystroke
  // retries rather than wedging the box permanently.
  function load() {
    if (index) return Promise.resolve(index);
    if (!loading) {
      loading = fetch('/search-index.json')
        .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
        .then((apps) => {
          index = buildIndex(apps, meta.sections);
          return index;
        })
        .catch(() => {
          loading = null;
          return null;
        });
    }
    return loading;
  }

  function close() {
    panel.hidden = true;
    input.setAttribute('aria-expanded', 'false');
    input.removeAttribute('aria-activedescendant');
    rows = [];
    active = -1;
  }

  function setActive(i) {
    if (!rows.length) return;
    active = (i + rows.length) % rows.length;
    rows.forEach((row, n) => {
      const on = n === active;
      row.classList.toggle('bg-canvas', on);
      row.setAttribute('aria-selected', String(on));
    });
    input.setAttribute('aria-activedescendant', rows[active].id);
    rows[active].scrollIntoView?.({ block: 'nearest' });
  }

  function group(label) {
    return `<p class="px-3 pt-2 pb-1 text-[11px] font-extrabold tracking-widest text-muted uppercase">${escapeHtml(
      label,
    )}</p>`;
  }

  function render(query) {
    const { tokens, categories: catHits, apps: appHits } = runQuery(index, query);
    const shown = appHits.slice(0, APP_LIMIT);

    if (!catHits.length && !appHits.length) {
      panel.innerHTML = `<p class="px-4 py-6 text-center text-sm text-muted">${escapeHtml(
        fill(strings.searchEmpty, { q: query }),
      )}</p>`;
      panel.hidden = false;
      input.setAttribute('aria-expanded', 'true');
      rows = [];
      active = -1;
      return;
    }

    let n = 0;
    let html = '';

    if (catHits.length) {
      html += group(strings.searchCategories);
      for (const cat of catHits) {
        html += `<a id="sr-${n++}" role="option" aria-selected="false" data-hit href="${escapeHtml(
          categoryPath(cat.slug),
        )}" class="flex items-center justify-between gap-3 px-3 py-2 text-sm hover:bg-canvas">
          <span class="flex items-center gap-2 truncate">
            <span class="chip chip-mode">${highlight(cat.label, tokens)}</span>
          </span>
          <span class="shrink-0 text-xs text-muted">${escapeHtml(
            fill(strings.searchCount, { n: cat.n }),
          )}</span>
        </a>`;
      }
    }

    if (shown.length) {
      html += group(strings.searchApps);
      for (const { app } of shown) {
        const icon = app.icon
          ? `<img src="${escapeHtml(app.icon)}" alt="" width="32" height="32"
               class="h-8 w-8 shrink-0 rounded-lg border border-line bg-canvas object-contain p-0.5" />`
          : `<span class="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-brand text-xs font-black text-white"
               aria-hidden="true">${escapeHtml(app.name.slice(0, 1).toUpperCase())}</span>`;
        html += `<a id="sr-${n++}" role="option" aria-selected="false" data-hit href="${escapeHtml(
          appPath(app.id),
        )}" class="flex items-center gap-3 px-3 py-2 hover:bg-canvas">
          ${icon}
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-bold">${highlight(app.name, tokens)}</span>
            <span class="block truncate text-xs text-muted">${highlight(app.summary, tokens)}</span>
          </span>
          <span class="chip chip-mode shrink-0">${escapeHtml(app.label)}</span>
        </a>`;
      }
    }

    if (appHits.length > shown.length) {
      html += `<p class="px-3 py-2 text-xs text-muted">${escapeHtml(
        fill(strings.searchMore, { n: appHits.length - shown.length }),
      )}</p>`;
    }

    panel.innerHTML = html;
    panel.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    rows = Array.from(panel.querySelectorAll('[data-hit]'));
    rows.forEach((row, i) => row.addEventListener('mousemove', () => setActive(i)));
    // The top hit starts selected so Enter is always "open the obvious one".
    setActive(0);
  }

  function update() {
    const query = input.value.trim();
    if (!query) return close();
    if (!index) {
      load().then((ok) => {
        if (ok && input.value.trim() === query) render(query);
      });
      return;
    }
    render(query);
  }

  input.addEventListener('input', update);
  input.addEventListener('focus', () => {
    load();
    if (input.value.trim()) update();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (panel.hidden) {
        update();
        return;
      }
      e.preventDefault();
      setActive(active + (e.key === 'ArrowDown' ? 1 : -1));
    } else if (e.key === 'Enter') {
      if (!panel.hidden && rows[active]) {
        e.preventDefault();
        window.location.href = rows[active].href;
      }
    } else if (e.key === 'Escape') {
      if (panel.hidden) input.value = '';
      else close();
    }
  });

  // The panel is anchored to the box, so anything outside dismisses it. Clicks
  // *inside* land on a row, which navigates on its own.
  document.addEventListener('click', (e) => {
    if (!root.contains(e.target)) close();
  });

  // The form only exists so the box reads as a search landmark; there is
  // nowhere to submit to, since results are the dropdown.
  input.closest('form')?.addEventListener('submit', (e) => e.preventDefault());

  // "/" focuses the box, the way every catalog people already use behaves.
  document.addEventListener('keydown', (e) => {
    if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
    const el = document.activeElement;
    if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable)) return;
    e.preventDefault();
    input.focus();
    input.select();
  });
}
