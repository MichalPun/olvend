import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const correctionSql = fs.readFileSync(new URL('../database/route_visit_corrections_v50.sql', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'mobile.html' })
  else new vm.Script(match[1], { filename: 'mobile.html' })
}

function extractRange(first, next) {
  const start = html.indexOf(`    function ${first}(`)
  const end = html.indexOf(`    function ${next}(`, start)
  assert.ok(start >= 0 && end > start, `${first}..${next}`)
  return html.slice(start, end)
}

const products = [
  { id: 1, sku: 'A', name: 'Bageta A', product_category: 'food_ready', active: true },
  { id: 2, sku: 'B', name: 'Bageta B', product_category: 'food_ready', active: true },
  { id: 3, sku: 'C', name: 'Bageta C', product_category: 'food_ready', active: true },
  { id: 4, sku: 'D', name: 'Bageta D', product_category: 'food_ready', active: true }
]
const slots = [
  { id: 11, machine_id: 1, slot_code: '23', product_sku: 'A', capacity_units: 5, current_units: 2, target_units: 5, substitution_policy: 'approved_list', allowed_substitutes: 'SKU A, SKU B, SKU C, SKU D' },
  { id: 12, machine_id: 1, slot_code: '24', product_sku: 'B', capacity_units: 5, current_units: 2, target_units: 5, substitution_policy: 'approved_list', allowed_substitutes: 'SKU A, SKU B, SKU C, SKU D' },
  { id: 13, machine_id: 1, slot_code: '25', product_sku: 'C', capacity_units: 5, current_units: 0, target_units: 5, substitution_policy: 'approved_list', allowed_substitutes: 'SKU A, SKU B, SKU C, SKU D' }
]
const context = vm.createContext({
  console, Map, Math, Number, String, Date,
  state: { products },
  normalizeText: (value) => String(value || '').toLowerCase(),
  getFoodProductFamily: () => '',
  getFoodPlanogramChange: () => null,
  getFoodRequiredFillQuantity: () => 5,
  getFoodSlotDraft: () => ({ fillItems: [], pickedQuantity: 0, manualProductChoice: false }),
  getFoodAvailableVehicleQuantity: (detail, _stop, _slot, productId) => Number(detail.vehicleStock[productId] || 0),
  getFoodRouteAllocatedQuantity: (_detail, _stop, _slot, _product, desired) => desired,
  isFoodExpiryExpired: () => false,
  getFoodDemandTargetQuantity: () => 5,
  getFoodDailySales: () => 1,
  getFoodTransferReservedByBatch: () => new Map()
})
vm.runInContext(extractRange('isFoodReadyProduct', 'renderFreshRouteRecommendation'), context)
vm.runInContext(extractRange('getFoodSlotProductOptions', 'getFoodSlotComposition'), context)
vm.runInContext(extractRange('getFoodPickSuggestion', 'prefillFoodRecommendedPicks'), context)

const detail = { slots, draft: { slots: {} }, vehicleStock: { 1: 5, 2: 5, 3: 0, 4: 3 } }
let suggestion = context.getFoodPickSuggestion(detail, 'stop', slots[2])
assert.equal(suggestion.product.sku, 'D', 'A distinct available fourth flavour must win over a duplicate')
assert.equal(suggestion.duplicateConflict, null)

detail.vehicleStock[4] = 0
suggestion = context.getFoodPickSuggestion(detail, 'stop', slots[2])
assert.ok(['A', 'B'].includes(suggestion.product.sku), 'When no distinct flavour is in the vehicle a duplicate may be used')
assert.equal(suggestion.duplicateEmergency, true)
assert.equal(suggestion.duplicateSafeAlternatives.length, 0)

assert.match(html, /const plannedReplacementFill = Boolean\(planogramChange\?\.productChanged && replacementFill\)/)
assert.doesNotMatch(html, /const replacementProduct = replacementFill \? selectedProduct/)
assert.match(html, /Nouzová duplicitní náhrada; jiný schválený druh nebyl ve vozidle/)
assert.doesNotMatch(correctionSql, /if p\.id<>f\.product_id then\s+update machine_planogram_slots set product_sku/)

console.log('OK: bagette variety, emergency duplicate and immutable base planogram')
