import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const moduleScript = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].at(-1)?.[1]

assert.ok(moduleScript, 'mobile.html must contain its module script')
new vm.SourceTextModule(moduleScript, { identifier: 'mobile.html' })

assert.match(html, /state\.selectedStockType === 'vehicle_writeoff' && state\.routeWasteFilter === 'damaged'/, 'damaged returns must have their own workflow')
assert.match(html, /if \(searchesVehicleStock && !normalized && !state\.stockProductCategoryFilter\) return \[\]/, 'vehicle stock must stay hidden until search or category selection')
assert.match(html, /unloadProductIds\.has\(String\(product\.id\)\)/, 'search results must be limited to products actually recorded in the vehicle')
assert.match(html, /id="scanStockBarcodeButton"/, 'damaged-item selection must support the PDA hardware scanner')
assert.match(html, /id="stockProductCategoryFilters"/, 'damaged-item selection must provide product category filters')
assert.match(html, /getMobileProductImageUrl\(product\)/, 'selected products must use the product-card photo')
assert.match(html, /stockQuantityBaseUnits \+ alreadySelectedBaseUnits > Number\(unloadBalance\.quantity_on_hand/, 'a return or write-off must not exceed the real vehicle balance')
assert.match(html, /matchingUnloadBalances\.reduce\(\(sum, row\) => sum \+ Number\(row\.quantity_on_hand \|\| 0\), 0\)/, 'vehicle quantity must include every batch of the selected product')
assert.match(html, /storesVehicleBaseQuantity = \['vehicle_unload', 'vehicle_writeoff'\]/, 'vehicle movements must be saved in product base units')
assert.match(html, /if \(isDamagedWriteoff && state\.routeWasteItems\.length\) await confirmPendingRouteWasteUnload\(\)/, 'one confirmation must include verified route damage and newly selected vehicle damage')
assert.doesNotMatch(html, /loadWholeVehicleButton\.style\.display = state\.selectedStockType === 'vehicle_unload' \? '' : 'none'/, 'the entire vehicle list must never be exposed in the return workflow')

console.log('mobile damaged-stock selection regression checks passed')
