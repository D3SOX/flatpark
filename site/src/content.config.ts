import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Content pages (about, policies, trust, guides, conduct, legal). English sits
// at the top level and each file's name is its route slug; a translation lives
// under a locale directory (`zh-Hans/about.md`) and so carries a locale-
// prefixed id, which `src/lib/pages.ts` splits back apart. The Footer is built
// from this collection, so `group` + `order` are what place a page in it.
const pages = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/pages' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    group: z.enum(['Project', 'Docs', 'Community', 'Legal']),
    order: z.number().default(0),
    hideFromFooter: z.boolean().default(false),
  }),
});

export const collections = { pages };
