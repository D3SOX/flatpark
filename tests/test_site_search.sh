#!/usr/bin/env bash
# Header type-ahead matcher: ranking rules, on a fixture catalog.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_site_search: SKIP (no node)"; exit 0; }

out="$(node --input-type=module -e "
import { buildIndex, runQuery } from '$ROOT/site/src/scripts/search.js';

const apps = [
  { id: 'com.anthropic.claude', name: 'Claude', summary: 'Anthropic desktop client', section: 'ai', tags: ['AI', 'Chat'] },
  { id: 'dev.ccswitch.CCSwitch', name: 'CC Switch', summary: 'Switch between Claude Code accounts', section: 'ai', tags: ['AI'] },
  { id: 'io.example.Ollama', name: 'Ollama', summary: 'Run local models', section: 'ai', tags: ['AI', 'LLM'] },
  { id: 'io.example.Ledger', name: 'Ledger', summary: 'Plain-text accounting', section: 'finance', tags: ['Money'] },
  { id: 'io.example.Vscodium', name: 'VSCodium', summary: 'Code editor', section: 'development', tags: ['Editor'] },
];
const sections = { ai: 'AI', finance: 'Finance', development: 'Development' };
const index = buildIndex(apps, sections);
const names = (q) => runQuery(index, q).apps.map((h) => h.app.name).join(',');
const cats = (q) => runQuery(index, q).categories.map((c) => c.slug + ':' + c.n).join(',');

const lines = [
  // A category name pulls up its whole section, plus the category itself.
  'ai.apps=' + names('ai'),
  'ai.cats=' + cats('ai'),
  // A second token narrows rather than widens (tokens are ANDed).
  'ai-claude=' + names('ai claude'),
  // Exact name wins over a summary mention of the same word.
  'claude=' + names('claude'),
  // Fuzzy: dropped letters still find the app.
  'vscd=' + names('vscd'),
  // The summary counts, not just the name…
  'accounting=' + names('accounting'),
  // …fuzzily too, but only within a word, never across the whole sentence.
  'modls=' + names('modls'),
  'rlm=' + names('rlm'),
  // Nothing matches -> nothing shown.
  'zzz=' + names('zzz') + '|' + cats('zzz'),
  // Category label in the reader's language matches too.
  'finance=' + names('finance'),
];
console.log(lines.join('\n'));
")"

get() { printf '%s\n' "$out" | grep "^$1=" | cut -d= -f2-; }

assert_eq "$(get ai.apps)" "CC Switch,Claude,Ollama"
assert_eq "$(get ai.cats)" "ai:3"
assert_eq "$(get ai-claude)" "Claude,CC Switch"
assert_eq "$(get claude)" "Claude,CC Switch"
assert_eq "$(get vscd)" "VSCodium"
assert_eq "$(get accounting)" "Ledger"
assert_eq "$(get modls)" "Ollama"
assert_eq "$(get rlm)" ""
assert_eq "$(get zzz)" "|"
assert_eq "$(get finance)" "Ledger"

echo "test_site_search: ok"
