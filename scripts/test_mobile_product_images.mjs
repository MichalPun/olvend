import assert from 'node:assert/strict'
import { access, readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const domain = await readFile(path.join(projectRoot, 'mobile-coffee-domain.js'), 'utf8')
const mobile = await readFile(path.join(projectRoot, 'mobile.html'), 'utf8')
const serviceWorker = await readFile(path.join(projectRoot, 'sw.js'), 'utf8')

for (const [sku, filename] of Object.entries({ 47: '47.jpg', 201: '201.jpg' })) {
  const assetPath = `./assets/product-images/${filename}`
  assert.ok(domain.includes(`'${sku}': '${assetPath}'`), `SKU ${sku} must have its product image mapping`)
  assert.ok(serviceWorker.includes(`'${assetPath}'`), `${filename} must be available in the offline app shell`)
  await access(path.join(projectRoot, 'assets', 'product-images', filename))
}

assert.match(mobile, /coffee-pick-thumb-image/, 'pick-list cards must render product images')
assert.match(mobile, /onerror="this\.hidden=true;this\.nextElementSibling\.hidden=false"/, 'broken images must fall back to the category visual')

console.log('OK: Caffé Presto and Enzo Bencini photos are wired into the offline pick list')
