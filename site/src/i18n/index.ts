// UI translation layer.
//
// English is the default locale and stays unprefixed (`/apps/foo/`), so every
// URL that existed before i18n still resolves; other locales live under a
// prefix (`/zh-Hans/apps/foo/`). This mirrors what Flathub does, and is the
// reason `localizePath` treats `defaultLang` as a special case rather than
// prefixing uniformly.
//
// Dictionaries are per-locale JSON — the format Weblate and friends expect —
// so community translation can be bolted on later without a migration.
import en from './locales/en.json';
import zhHans from './locales/zh-Hans.json';

export { defaultLang, languages, locales, prefixedLocales } from './config.mjs';
import { defaultLang, languages } from './config.mjs';

export type Lang = 'en' | 'zh-Hans';

const dictionaries: Record<Lang, Record<string, string>> = { en, 'zh-Hans': zhHans };

export const isLang = (value: string): value is Lang => value in languages;

/** Locale of a rendered page, read back off its own URL. */
export function getLangFromUrl(url: URL): Lang {
  const first = url.pathname.split('/')[1] ?? '';
  return isLang(first) && first !== defaultLang ? first : (defaultLang as Lang);
}

/**
 * Turn a default-locale path into the `lang` equivalent. Paths are written
 * throughout the site in their English form (`/setup/`), and every link goes
 * through here so a page never has to know which locale it is rendering as.
 */
export function localizePath(path: string, lang: Lang): string {
  const p = path.startsWith('/') ? path : `/${path}`;
  return lang === defaultLang ? p : `/${lang}${p}`;
}

/** Inverse of `localizePath` — used to build hreflang alternates. */
export function stripLang(pathname: string): string {
  const [, first, ...rest] = pathname.split('/');
  if (!first || !isLang(first) || first === defaultLang) return pathname;
  return `/${rest.join('/')}`;
}

/**
 * `t('key')`, with `{name}` placeholders filled from `vars`. A key missing from
 * a translation falls back to English rather than blanking the page, so a
 * partially translated locale still renders; a key missing everywhere renders
 * as itself, which is loud enough to catch in review.
 */
export function useTranslations(lang: Lang) {
  const dict = dictionaries[lang] ?? dictionaries[defaultLang as Lang];
  const base = dictionaries[defaultLang as Lang];
  return function t(key: string, vars?: Record<string, string | number>): string {
    let out = dict[key] ?? base[key] ?? key;
    if (vars) {
      for (const [name, value] of Object.entries(vars)) {
        out = out.split(`{${name}}`).join(String(value));
      }
    }
    return out;
  };
}
