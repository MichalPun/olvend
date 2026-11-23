import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const moduleScript = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].at(-1)?.[1]
assert.ok(moduleScript, 'mobile.html must contain its module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /manualVehicleLoad\) \|\| isFoodReadyProduct\(product\)/, 'manual fresh loading must show only fresh products')
assert.match(html, /loadFreshWarehouseAvailability\(\)/, 'fresh catalog must load current warehouse availability')
assert.match(html, /evidenčně skladem .* · lze naložit podle skutečnosti/, 'warehouse stock must stay informational during loading')
assert.doesNotMatch(html, /stockQuantityBaseUnits \+ alreadySelected > available/, 'manual loading must not be capped by the recorded warehouse stock')
assert.match(html, /Přidat jiný druh bagety/, 'fresh-load action must use the bagette-specific label')
assert.match(html, /function isMorningBagetteProduct\(product\)/, 'morning bagette range must be classified explicitly')
assert.match(html, /allowNegative: true/, 'every physical vehicle load must permit a negative source balance')
assert.match(html, /Sklad po naložení:/, 'draft must show the resulting negative warehouse balance before confirmation')
assert.match(html, /quantity > 0 && expiry/, 'existing negative bagette balance must be included when calculating the resulting warehouse stock')

console.log('mobile fresh-load catalog regression checks passed')
