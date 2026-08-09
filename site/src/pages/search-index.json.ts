// The catalog, trimmed to what the header type-ahead needs, as one static file.
//
// Fetched lazily on first use rather than inlined into every page: the payload
// grows with the catalog and would otherwise be paid for on every navigation,
// while as its own URL it is fetched once and then served from the HTTP cache.
//
// Locale-independent on purpose — names, summaries and tags come from upstream
// metainfo and are not translated; only the category *label* differs per
// locale, and the client resolves that from the slug against a per-page table
// (see Base.astro).
import { loadApps } from '../lib/data.mjs';

export function GET() {
  const apps = loadApps().map((a) => ({
    id: a.id,
    name: a.name,
    summary: a.summary || '',
    section: a.section || a.category || 'utilities',
    tags: a.tags ?? [],
    icon: a.icon || '',
    approved: a.upstreamApproved ? 1 : 0,
  }));

  return new Response(JSON.stringify(apps), {
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}
