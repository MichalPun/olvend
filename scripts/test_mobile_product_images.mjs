import assert from 'node:assert/strict'
import { access, readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const domain = await readFile(path.join(projectRoot, 'mobile-coffee-domain.js'), 'utf8')
const mobile = await readFile(path.join(projectRoot, 'mobile.html'), 'utf8')
const inventory = await readFile(path.join(projectRoot, 'inventory.html'), 'utf8')
const serviceWorker = await readFile(path.join(projectRoot, 'sw.js'), 'utf8')
const migration = await readFile(path.join(projectRoot, 'database', 'product_card_images_v60.sql'), 'utf8')

for (const [sku, filename] of Object.entries({ 47: '47.jpg', 201: '201.jpg' })) {
  const assetPath = `./assets/product-images/${filename}`
  assert.ok(migration.includes(`when '${sku}' then 'static:${assetPath}'`), `SKU ${sku} must be migrated to its product card image`)
  assert.ok(serviceWorker.includes(`'${assetPath}'`), `${filename} must be available in the offline app shell`)
  await access(path.join(projectRoot, 'assets', 'product-images', filename))
}

assert.match(migration, /'product-images'/, 'migration must create the product image bucket')
assert.match(migration, /false,\s*8388608/, 'product image bucket must stay private')
assert.match(migration, /has_manager_access/, 'only managers may change stored product images')
assert.match(inventory, /id="productImageInput"/, 'product card must provide an image picker')
assert.match(inventory, /uploadProductImage/, 'product card must upload selected images')
assert.match(inventory, /image_path, image_updated_at/, 'inventory product query must load image metadata')
assert.match(mobile, /image_path, image_updated_at/, 'mobile product query must load image metadata')
assert.match(domain, /product\?\.image_url/, 'pick list must use the product-card image')
assert.match(mobile, /coffee-pick-thumb-image/, 'pick-list cards must render product images')
assert.match(mobile, /onerror="this\.hidden=true;this\.nextElementSibling\.hidden=false"/, 'broken images must fall back to the category visual')
assert.match(serviceWorker, /storage\/v1\/object\/sign\/product-images/, 'signed product images must be cached for offline work')

console.log('OK: product-card photos are editable and wired into the offline pick list')
