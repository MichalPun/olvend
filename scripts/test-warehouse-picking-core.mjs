import assert from 'node:assert/strict'
import {
  getItemBaseQuantity,
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

const skipped = { requested_quantity: 6, prepared_quantity: 0, note: '[Nevychystáno: Není skladem]' }
assert.equal(isSkippedItem(skipped), true)
assert.equal(isHandledItem(skipped), true)
assert.equal(isHandledItem({ requested_quantity: 1, prepared_quantity: 1, warehouse_picked_at: '2026-11-02T09:00:00Z' }), true)

console.log('warehouse-picking-core: OK')
