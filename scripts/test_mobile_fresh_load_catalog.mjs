import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const moduleScript = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].at(-1)?.[1]
assert.ok(moduleScript, 'mobile.html must contain its module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /manualVehicleLoad\) \|\| isFoodReadyProduct\(product\)/, 'manual fresh loading must show only fresh products')
assert.match(html, /loadFreshWarehouseAvailability\(\)/, 'fresh catalog must load current warehouse availability')
assert.match(html, /není skladem/, 'zero-stock fresh products must stay visible with a clear label')
assert.match(html, /freshWarehouseAvailabilityLoaded/, 'fresh load quantity must be checked against known warehouse stock')
assert.match(html, /Přidat jiný druh bagety/, 'fresh-load action must use the bagette-specific label')

console.log('mobile fresh-load catalog regression checks passed')
