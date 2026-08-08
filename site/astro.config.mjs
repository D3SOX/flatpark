// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';
import { defaultLang, languages, locales } from './src/i18n/config.mjs';

// `site` is the canonical origin used for the sitemap and absolute URLs; it is
// overridable so the publish pipeline can pass REPO_HOMEPAGE, and defaults to
// the production host. `outDir` is likewise overridable so the publish pipeline
// (and tests) can target any location; defaults to the repo's shared out/site.
export default defineConfig({
  site: process.env.SITE_URL || 'https://flatpark.org',
  outDir: process.env.SITE_OUT_DIR || '../out/site',
  output: 'static',
  // English keeps the bare paths it has always had; other locales are prefixed.
  // No `fallback` here on purpose: an untranslated page renders its English
  // body under the localised URL (what Flathub does) rather than redirecting,
  // so the locale's chrome and hreflang set stay intact.
  i18n: {
    defaultLocale: defaultLang,
    locales,
    routing: { prefixDefaultLocale: false },
  },
  // Feeding the locale table to the sitemap is what emits the
  // `xhtml:link rel="alternate"` entries that make the translations
  // discoverable — the SEO half of the reason for doing any of this.
  integrations: [
    sitemap({
      i18n: {
        defaultLocale: defaultLang,
        locales: Object.fromEntries(locales.map((l) => [l, languages[l].htmlLang])),
      },
    }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});
