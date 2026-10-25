import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'

const html = fs.readFileSync(new URL('../routes-create.html', import.meta.url), 'utf8')

assert.match(html, /<table class="route-order-table">/)
assert.match(html, /<tbody class="route-list" id="routeList"><\/tbody>/)
assert.match(html, /\.sheet-table-wrap\.short\.modern-route-scroll \{ max-height:none;/)
assert.match(html, /data-route-drag-handle/)
assert.match(html, /touch-action:none/)
assert.match(html, /addEventListener\('pointerdown'/)
assert.match(html, /addEventListener\('pointermove'/)
assert.match(html, /event\.key === 'ArrowUp'/)
assert.match(html, /event\.key === 'ArrowDown'/)
assert.doesNotMatch(html, /<article class="modern-route-card" draggable="true"/)

for (const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) {
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'routes-create.html' })
  else new vm.Script(match[1], { filename: 'routes-create.html' })
}

console.log('OK: pořadí trasy je tabulka bez vnitřního scrollu a podporuje myš, dotyk i klávesnici')
