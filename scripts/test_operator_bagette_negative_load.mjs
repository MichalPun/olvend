import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const html = readFileSync(new URL('../olvend-operator/sklad.html', import.meta.url), 'utf8')
const script = readFileSync(new URL('../olvend-operator/operator-warehouse.js', import.meta.url), 'utf8')
const worker = readFileSync(new URL('../olvend-operator/sw-v44.js', import.meta.url), 'utf8')

assert.match(html, /operator-warehouse\.js\?v=20261120-picker-close-v1/)
assert.match(worker, /olvend-operator-v54-close-bagette-picker/)
assert.match(script, /evidenční stav skladu/)
assert.match(script, /lze naložit i do mínusu/)
assert.match(script, /sklad po naložení/)
assert.match(script, /max:999/)
assert.match(script, /allow_negative_source:true/)
assert.match(script, /amount<=0\|\|!expires/)
assert.doesNotMatch(script, /warehouseLocation\+'&quantity_on_hand=gt\.0&product_id=in/, 'bagette catalog must include zero and negative warehouse balances')
assert.match(script, /data-bagette-quantity/)
assert.match(script, /data-add-selected-bagettes/)
assert.match(script, /Přidat vybrané/)
assert.match(script, /if \(flow === 'bagettes'\) \{[\s\S]*ow-bagette-picker/)
assert.doesNotMatch(script, /bagetteWrap\.hidden=false/, 'bagette picker must close after adding selected products')

const freshPhotoFiles = [
  'bagette-debrecin.jpg',
  'bagette-hamka.jpg',
  'bagette-mlska.jpg',
  'bagette-nuget.jpg',
  'bagette-porizek.jpg',
  'bagette-strips.jpg',
  'bagette-svacinka.jpg'
]
for (const filename of freshPhotoFiles) {
  assert.ok(existsSync(new URL('../olvend-operator/assets/product-images/' + filename, import.meta.url)), `missing ${filename}`)
  assert.match(worker, new RegExp(filename.replace('.', '\\.')))
}
assert.match(script, /debrecin:'bagette-debrecin\.jpg'/)
assert.match(script, /mlska:'bagette-mlska\.jpg'/)
assert.match(script, /nuget:'bagette-nuget\.jpg'/)
assert.match(script, /strips:'bagette-strips\.jpg'/)

console.log('operator bagette negative-load checks passed')
