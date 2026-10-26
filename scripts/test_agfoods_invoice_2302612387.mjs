import assert from 'node:assert/strict'
import { access, readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const sql = await readFile(path.join(projectRoot, 'database', 'receive_agfoods_invoice_2302612387_20261026.sql'), 'utf8')
const migration = await readFile(path.join(projectRoot, 'database', 'product_card_images_v60.sql'), 'utf8')
const serviceWorker = await readFile(path.join(projectRoot, 'sw.js'), 'utf8')

const expected = [
  { productId: 104, sku: '48', name: 'Creamer White AG PRO 1 kg', quantity: 200, price: 86, packageId: 109, packageCount: 20, image: '48.jpg' },
  { productId: 26, sku: '201', name: 'Caffé Presto 1 kg', quantity: 42, price: 225, packageId: 99, packageCount: 7, image: '201.jpg' },
  { productId: 108, sku: '44', name: 'Staccato 0,5 kg Enzo Bencini', quantity: 25, price: 420, packageId: 112, packageCount: 5, image: '44.jpg' }
]

assert.match(sql, /P01 2302612387/, 'receipt must use the invoice number')
assert.match(sql, /DOL2302651477/, 'receipt must use the delivery note number')
assert.match(sql, /37 150,00 Kč/, 'receipt must preserve the invoice net total')
assert.match(sql, /41 608,00 Kč/, 'receipt must preserve the invoice gross total')
assert.match(sql, /date '2026-11-12'/, 'receipt must preserve the due date')

for (const item of expected) {
  assert.ok(sql.includes(item.name), `${item.name} must be used on the product card`)
  assert.match(sql, new RegExp(`\\(${item.productId}, [^\\n]+ 'receipt', ${item.quantity}, ${item.packageId}, ${item.packageCount}, ${item.price}(?:\\.00)?`), `${item.name} receipt conversion must be exact`)
  if (item.productId !== 26) {
    assert.ok(sql.includes(`static:./assets/product-images/${item.image}`), `${item.name} must be assigned its product photo`)
    assert.ok(migration.includes(`when '${item.sku}' then 'static:./assets/product-images/${item.image}'`), `${item.name} photo must be seeded on fresh databases`)
  }
  assert.ok(serviceWorker.includes(`'./assets/product-images/${item.image}'`), `${item.name} photo must be available offline`)
  await access(path.join(projectRoot, 'assets', 'product-images', item.image))
}

assert.match(sql, /units_per_package = 0\.5/, 'Staccato retail pack must equal 0.5 kg')
assert.match(sql, /units_per_package = 5,/, 'Staccato carton must equal 5 kg')
assert.match(sql, /units_per_package = 10,/, 'Creamer carton must equal 10 kg')

console.log('OK: AG FOODS invoice 2302612387 conversions, prices, names and photos are consistent')
