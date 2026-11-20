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
assert.match(html, /function isMorningBagetteProduct\(product\)/, 'morning bagette range must be classified explicitly')
assert.match(html, /lze naložit i do mínusu/, 'bagettes must explain that warehouse stock may go negative')
assert.match(html, /allowNegative: request\.request_type === 'vehicle_load' && isMorningBagetteProduct\(product\)/, 'only an actual morning bagette load may create negative warehouse stock')
assert.match(html, /Sklad po naložení:/, 'draft must show the resulting negative warehouse balance before confirmation')
assert.match(html, /quantity > 0 && expiry/, 'existing negative bagette balance must be included when calculating the resulting warehouse stock')

console.log('mobile fresh-load catalog regression checks passed')
