#!/usr/bin/env bash
# Root-path language negotiation: which locale `/` serves for a given browser.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_i18n_negotiate: SKIP (no node)"; exit 0; }

out="$(node --input-type=module -e "
import { cookieLocale, localeForRequest, preferredLocale } from '$ROOT/site/src/i18n/negotiate.mjs';

const lines = [
  // Nothing to go on -> English, which is what crawlers get (they send no header).
  'empty=' + preferredLocale(''),
  'missing=' + preferredLocale(undefined),
  'wildcard=' + preferredLocale('*'),
  // The plain cases.
  'en=' + preferredLocale('en-US,en;q=0.9'),
  'zh-cn=' + preferredLocale('zh-CN,zh;q=0.9,en;q=0.8'),
  'zh-bare=' + preferredLocale('zh'),
  // Traditional regions have no locale of their own yet, so they land on the
  // only Chinese we ship rather than on English.
  'zh-tw=' + preferredLocale('zh-TW,zh;q=0.9'),
  'zh-hant=' + preferredLocale('zh-Hant'),
  // A language we do not ship at all stays English.
  'ja=' + preferredLocale('ja-JP,ja;q=0.9'),
  // q-order decides, not the order the tags appear in.
  'q-order=' + preferredLocale('en;q=0.3,zh-CN;q=0.9'),
  'q-zero=' + preferredLocale('zh-CN;q=0,ja;q=0.5'),
  // Case and stray whitespace are the browser's business, not ours.
  'sloppy=' + preferredLocale('  ZH-hans-cn ; q=0.8 , en ; q=0.2 '),
  // An explicit pick from the switcher outranks the browser, both ways.
  'cookie-en=' + localeForRequest({ acceptLanguage: 'zh-CN', cookieHeader: 'theme=dark; lang=en' }),
  'cookie-zh=' + localeForRequest({ acceptLanguage: 'en-US', cookieHeader: 'lang=zh-Hans' }),
  // A cookie naming something we do not ship is ignored, not trusted.
  'cookie-junk=' + localeForRequest({ acceptLanguage: 'zh-CN', cookieHeader: 'lang=../etc' }),
  'cookie-none=' + cookieLocale('theme=dark'),
];
console.log(lines.join('\n'));
")"

get() { printf '%s\n' "$out" | grep "^$1=" | cut -d= -f2-; }

assert_eq "$(get empty)" "en"
assert_eq "$(get missing)" "en"
assert_eq "$(get wildcard)" "en"
assert_eq "$(get en)" "en"
assert_eq "$(get zh-cn)" "zh-Hans"
assert_eq "$(get zh-bare)" "zh-Hans"
assert_eq "$(get zh-tw)" "zh-Hans"
assert_eq "$(get zh-hant)" "zh-Hans"
assert_eq "$(get ja)" "en"
assert_eq "$(get q-order)" "zh-Hans"
assert_eq "$(get q-zero)" "en"
assert_eq "$(get sloppy)" "zh-Hans"
assert_eq "$(get cookie-en)" "en"
assert_eq "$(get cookie-zh)" "zh-Hans"
assert_eq "$(get cookie-junk)" "zh-Hans"
assert_eq "$(get cookie-none)" "null"

echo "test_i18n_negotiate: ok"
