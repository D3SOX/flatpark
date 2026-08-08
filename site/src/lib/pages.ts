// Locale-aware access to the `pages` content collection.
//
// Layout: English lives at `src/content/pages/<slug>.md`, a translation at
// `src/content/pages/<lang>/<slug>.md`. An untranslated page is *not* hidden
// from the localised site — it renders its English body under the localised
// URL, which is what Flathub does and what keeps the footer, the hreflang set
// and the sitemap identical across locales while translation lands piecemeal.
import { getCollection, type CollectionEntry } from 'astro:content';
import { defaultLang, locales, type Lang } from '../i18n';

type Entry = CollectionEntry<'pages'>;

// Astro's glob loader slugifies ids, which lowercases them — the directory
// `zh-Hans/` arrives here as the id prefix `zh-hans`. Match case-insensitively
// and map back to the canonical code, or every translation silently reads as an
// English page whose slug happens to start with a language name.
const byLowerCase = new Map(locales.map((l) => [l.toLowerCase(), l]));

/** Split a collection id into its locale and slug (`zh-Hans/about` -> both). */
function splitId(id: string): { lang: Lang; slug: string } {
  const [first, ...rest] = id.split('/');
  const matched = first ? byLowerCase.get(first.toLowerCase()) : undefined;
  return matched && matched !== defaultLang
    ? { lang: matched, slug: rest.join('/') }
    : { lang: defaultLang as Lang, slug: id };
}

/**
 * Every content page as it should appear in `lang`: the translated entry when
 * one exists, the English entry otherwise. Slugs are always the English ones,
 * so a URL keeps its shape across locales.
 */
export async function getPagesFor(lang: Lang): Promise<{ slug: string; entry: Entry }[]> {
  const all = await getCollection('pages');
  const english = new Map<string, Entry>();
  const translated = new Map<string, Entry>();

  for (const entry of all) {
    const { lang: entryLang, slug } = splitId(entry.id);
    if (entryLang === defaultLang) english.set(slug, entry);
    else if (entryLang === lang) translated.set(slug, entry);
  }

  return [...english.entries()].map(([slug, entry]) => ({
    slug,
    entry: translated.get(slug) ?? entry,
  }));
}
