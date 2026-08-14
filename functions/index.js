// Cloudflare Pages Function for `/`, and only `/`.
//
// English lives on the bare paths, so every other URL is already unambiguous
// and must stay a plain static asset — both to keep the canonical English pages
// out of a redirect and to keep Function invocations off the rest of the site.
// `site/public/_routes.json` pins that scoping; widening it there is what would
// put this in front of anything else.
//
// The reader's own choice, once made, is final: the switcher writes a `lang`
// cookie (see Base.astro) and `localeForRequest` prefers it over the browser's
// header. Crawlers send no `Accept-Language`, so they get English here and find
// the rest through the hreflang alternates, which is the point of not touching
// the deep paths.
import { defaultLang } from '../site/src/i18n/config.mjs';
import { localeForRequest } from '../site/src/i18n/negotiate.mjs';

export async function onRequest(context) {
  const { request, next } = context;
  if (request.method !== 'GET' && request.method !== 'HEAD') return next();

  const lang = localeForRequest({
    acceptLanguage: request.headers.get('accept-language'),
    cookieHeader: request.headers.get('cookie'),
  });

  if (lang !== defaultLang) {
    const target = new URL(request.url);
    target.pathname = `/${lang}/`;
    return new Response(null, {
      status: 302, // never 301: the answer differs per reader, so nothing may pin it
      headers: {
        Location: target.toString(),
        'Cache-Control': 'no-store',
        Vary: 'Accept-Language, Cookie',
      },
    });
  }

  // English: serve the static homepage untouched, but mark it as negotiated so
  // no shared cache hands this copy to a reader who would have been redirected.
  const response = await next();
  const out = new Response(response.body, response);
  out.headers.append('Vary', 'Accept-Language, Cookie');
  return out;
}
