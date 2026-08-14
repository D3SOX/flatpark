// Language negotiation for the one URL that has to guess: `/`.
//
// Every other path already says which locale it is (`/zh-Hans/...`) or is the
// English original, so only the bare root is ambiguous. `functions/index.js`
// runs this at the Cloudflare edge and 302s a reader whose browser asks for a
// language we ship in — the same thing Flathub does with a server-side 307,
// minus the flash of English that a client-side redirect would cause.
//
// Kept next to `config.mjs` and importing from it, because the locale table and
// the code that matches against it must never drift apart.
import { defaultLang, locales } from './config.mjs';

/** Cookie the language switcher writes; an explicit pick outranks the browser. */
export const LANG_COOKIE = 'lang';

// Chinese is the case where the browser's region stands in for a script: a
// `zh-TW` reader wants Traditional, `zh-CN` Simplified, and neither spells the
// script out. Everything else falls through to the language-only match below.
const ZH_SCRIPT_BY_REGION = { cn: 'hans', sg: 'hans', my: 'hans', tw: 'hant', hk: 'hant', mo: 'hant' };

/**
 * The locale we would serve one browser tag, or null if we ship nothing in that
 * language. A tag that names a script we do not have (`zh-TW` today) falls back
 * to the first locale in the same language rather than to English: Traditional
 * readers are better served by Simplified than by a language they may not read.
 * Adding `zh-Hant` to the table is all it takes for them to resolve exactly.
 */
function resolveTag(tag) {
  const [lang, ...rest] = String(tag).toLowerCase().split('-').filter(Boolean);
  if (!lang) return null;

  const candidates = locales.filter((l) => l.toLowerCase().split('-')[0] === lang);
  if (!candidates.length) return null;

  const script = rest.find((s) => s.length === 4) ?? (lang === 'zh' ? ZH_SCRIPT_BY_REGION[rest[0]] : undefined);
  if (script) {
    const exact = candidates.find((l) => l.toLowerCase().split('-')[1] === script);
    if (exact) return exact;
  }
  return candidates[0];
}

/**
 * Best locale for an `Accept-Language` header, defaulting to English. Tags are
 * tried in q-order; the first one we ship wins. `*` means "anything", which is
 * the default locale by definition, so it ends the search.
 */
export function preferredLocale(acceptLanguage) {
  const tags = String(acceptLanguage || '')
    .split(',')
    .map((part) => {
      const [tag, ...params] = part.trim().split(';');
      const q = params.map((p) => p.trim()).find((p) => p.startsWith('q='));
      const weight = q ? Number.parseFloat(q.slice(2)) : 1;
      return { tag: tag.trim(), q: Number.isFinite(weight) ? weight : 0 };
    })
    // Sort is stable, so equal weights keep the order the browser sent.
    .filter((entry) => entry.tag && entry.q > 0)
    .sort((a, b) => b.q - a.q);

  for (const { tag } of tags) {
    if (tag === '*') break;
    const hit = resolveTag(tag);
    if (hit) return hit;
  }
  return defaultLang;
}

/** The `lang` cookie's value, if it names a locale we actually ship. */
export function cookieLocale(cookieHeader) {
  for (const pair of String(cookieHeader || '').split(';')) {
    const [name, ...value] = pair.trim().split('=');
    if (name === LANG_COOKIE) {
      const wanted = decodeURIComponent(value.join('='));
      return locales.includes(wanted) ? wanted : null;
    }
  }
  return null;
}

/**
 * What to serve at `/`. An explicit pick from the language switcher wins over
 * the browser's list — without that, choosing English from a Chinese browser
 * would be undone on the next visit to the root.
 */
export function localeForRequest({ acceptLanguage, cookieHeader } = {}) {
  return cookieLocale(cookieHeader) ?? preferredLocale(acceptLanguage);
}
