// getStaticPaths helpers for the `[...locale]/` route tree.
//
// The locale segment is a *rest* param so it can be `undefined`, which is what
// emits the unprefixed English routes (`/apps/foo/`) alongside the prefixed
// ones (`/zh-Hans/apps/foo/`). Every route under `[...locale]/` folds its own
// paths over `localeParams()` so the locale dimension is declared in one place.
import { defaultLang, locales } from './config.mjs';

/**
 * One entry per locale: `{ locale, lang }`, where `locale` is the route param
 * (undefined for the default locale) and `lang` is the resolved code, for
 * routes that need to look up translated data while building their paths.
 */
export const localeParams = () =>
  locales.map((lang) => ({ locale: lang === defaultLang ? undefined : lang, lang }));

/**
 * getStaticPaths for a route whose only dynamic dimension is the locale — i.e.
 * a page that was a plain static route before it moved under `[...locale]/`.
 */
export const localeOnlyPaths = () => localeParams().map(({ locale }) => ({ params: { locale } }));

/**
 * Fold a per-locale path builder over every locale. `build(lang)` returns the
 * route's own entries without a `locale` param — sync or async, since content
 * collection lookups are async — and this stamps one in per locale.
 */
export async function pathsForLocales(build) {
  const paths = [];
  for (const { locale, lang } of localeParams()) {
    for (const entry of await build(lang)) {
      paths.push({ ...entry, params: { ...entry.params, locale } });
    }
  }
  return paths;
}
