import assert from 'node:assert/strict'
import {
  formatBaseQuantity,
  getAllowedSubstituteSkus,
  getApprovedSubstituteProducts,
  getItemBaseQuantity,
  getPreparedItemBaseQuantity,
  getPreparedProductId,
  getPickingCategory,
  getStoragePosition,
  isHandledItem,
  isSkippedItem,
  quantityFromBase,
  quantityToBase,
  sortPickingItems
} from '../warehouse-picking-core.mjs'

const products = [
  { id: 1, name: 'Alaska', product_category: 'snack_ready', base_unit: 'ks', note: '[olvend_storage_position:C-02]' },
  { id: 2, name: 'Voda', product_category: 'water_product', base_unit: 'ks', note: '[olvend_storage_position:B-06]' },
  { id: 3, name: 'Káva', product_category: 'ingredient', base_unit: 'ks', note: '[olvend_storage_position:A-03]' }
]
const packages = [{ id: 1, product_id: 3, package_name: 'Balení', units_per_package: 12, is_default: true, active: true }]

assert.equal(getStoragePosition(products[2]), 'A-03')
assert.equal(getPickingCategory(products[2]).label, 'Suroviny')
assert.equal(getPickingCategory(products[1]).label, 'Vody')
assert.equal(getPickingCategory(products[0]).label, 'Cukrovinky')

const productMap = new Map(products.map((product) => [String(product.id), product]))
const sorted = sortPickingItems([
  { product_id: 1, product_name: 'Alaska' },
  { product_id: 2, product_name: 'Voda' },
  { product_id: 3, product_name: 'Káva' }
], productMap)
assert.deepEqual(sorted.map((item) => item.product_id), [3, 2, 1])

assert.equal(quantityToBase(6, 'Balení', products[2], packages[0]), 72)
assert.equal(quantityFromBase(72, 'package', products[2], packages[0]), 6)
assert.equal(getItemBaseQuantity({ product_id: 3, unit: 'Balení', prepared_quantity: 6 }, products[2], packages), 72)
assert.equal(formatBaseQuantity(72, { base_unit: 'ks' }), '72 ks')
assert.equal(formatBaseQuantity(18, { base_unit: 'tyčí' }), '18 tyčí')
assert.equal(formatBaseQuantity(24, { base_unit: 'kelímků' }), '24 kelímků')

const substitutionProducts = [
  ...products,
  { id: 4, name: 'Nestea Lemon 0,5l', sku: '275', base_unit: 'ks', active: true },
  { id: 5, name: 'Nestea Peach 0,5l', sku: '67', base_unit: 'ks', active: true }
]
const substitutionRules = [{
  product_sku: '275',
  substitution_policy: 'approved_list',
  allowed_substitutes: 'Nestea Peach 0,5l (SKU 67); Nestea Lemon 0,5l (SKU 275)',
  active: true
}]
assert.deepEqual(getAllowedSubstituteSkus(substitutionRules[0].allowed_substitutes), ['67', '275'])
assert.deepEqual(getApprovedSubstituteProducts(substitutionProducts[3], substitutionProducts, substitutionRules).map((product) => product.id), [5])
const substitutedItem = { product_id: 4, unit: 'balení', requested_quantity: 1, prepared_product_id: 5, prepared_unit: 'ks', prepared_quantity: 12 }
assert.equal(getPreparedProductId(substitutedItem), 5)
assert.equal(getPreparedItemBaseQuantity(substitutedItem, new Map(substitutionProducts.map((product) => [String(product.id), product])), packages), 12)

const skipped = { requested_quantity: 6, prepared_quantity: 0, note: '[Nevychystáno: Není skladem]' }
assert.equal(isSkippedItem(skipped), true)
assert.equal(isHandledItem(skipped), true)
assert.equal(isHandledItem({ requested_quantity: 1, prepared_quantity: 1, warehouse_picked_at: '2026-11-02T09:00:00Z' }), true)

console.log('warehouse-picking-core: OK')
