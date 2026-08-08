// The locale table, in plain JS so `astro.config.mjs` can import it too — the
// Astro i18n routing config and the runtime translation layer must never drift
// apart, so both read this one file.
//
// `htmlLang` feeds <html lang> and hreflang; `ogLocale` feeds og:locale, which
// wants the underscored POSIX-ish form rather than the BCP-47 tag.
export const defaultLang = 'en';

export const languages = {
  en: { label: 'English', htmlLang: 'en', ogLocale: 'en_US' },
  'zh-Hans': { label: '简体中文', htmlLang: 'zh-Hans', ogLocale: 'zh_CN' },
};

export const locales = Object.keys(languages);

/** Locales that carry a URL prefix, i.e. everything but the default. */
export const prefixedLocales = locales.filter((l) => l !== defaultLang);
