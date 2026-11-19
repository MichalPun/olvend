import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
await import(path.join(root, 'olvend-operator/operator-stock-core.js'))
const aggregateStockRows = globalThis.OlvendOperatorStockCore.aggregateStockRows
const rows = aggregateStockRows([
  { id: 1, product_id: 42, product_name: 'Cukr Vending 1 kg', base_unit: 'kg', quantity_on_hand: 7, reserved_quantity: 1, updated_at: '2026-11-18T08:00:00Z' },
  { id: 2, product_id: 42, product_name: 'Cukr Vending 1 kg', base_unit: 'kg', quantity_on_hand: 1, reserved_quantity: 0, updated_at: '2026-11-19T08:00:00Z' },
  { id: 3, product_id: 48, product_name: 'Creamer White', base_unit: 'kg', quantity_on_hand: 2, reserved_quantity: 0, updated_at: '2026-11-19T07:00:00Z' }
])

assert.equal(rows.length, 2)
assert.equal(rows[0].product_id, 42)
assert.equal(rows[0].quantity_on_hand, 8)
assert.equal(rows[0].reserved_quantity, 1)
assert.equal(rows[0].balance_row_count, 2)
assert.equal(rows[0].updated_at, '2026-11-19T08:00:00Z')
assert.equal(rows[1].product_id, 48)

const migration = fs.readFileSync(path.join(root, 'database/product_card_missing_images_v63.sql'), 'utf8')
const imagePaths = [...migration.matchAll(/static:\.\/assets\/product-images\/([^']+)/g)].map((match) => match[1])
assert.equal(imagePaths.length, 18)
imagePaths.forEach((imagePath) => {
  assert.ok(fs.existsSync(path.join(root, 'assets/product-images', imagePath)), `Chybí obrázek ${imagePath}`)
})

console.log('OK: zásoby stejného produktu se slučují a všech 18 fotografií existuje.')
