import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const extract = name => {
  const start = html.indexOf(`    function ${name}(`)
  assert.ok(start >= 0, name)
  const end = html.indexOf('\n    function ', start + 1)
  return html.slice(start, end)
}

const context = vm.createContext({
  state: {
    products: [{ id: 105, base_unit: 'kg' }, { id: 101, base_unit: 'ks' }],
    productPackages: [
      { id: 30, product_id: 105, package_name: '1 kg', units_per_package: 1, is_default: true, active: true },
      { id: 111, product_id: 105, package_name: 'Karton', units_per_package: 10000, is_default: false, active: true },
      { id: 164, product_id: 101, package_name: 'Výchozí balení', units_per_package: 1, is_default: true, active: true }
    ]
  },
  normalizeText: value => String(value || '').trim().toLowerCase(),
  convertRecipeQuantity: (value, from, to) => {
    if (from === to) return value
    if (from === 'g' && to === 'kg') return value / 1000
    if (from === 'ml' && to === 'l') return value / 1000
    return value
  }
})

for (const name of ['getMobileProductPackages', 'getPackageQuantityUnit', 'convertMobilePackageQuantityToBase', 'getDefaultStockEntryUnitMode']) {
  vm.runInContext(extract(name), context)
}

const product = { id: 105, base_unit: 'kg' }
const packages = context.getMobileProductPackages(product.id)
assert.deepEqual(Array.from(packages, item => item.id), [30, 111], 'default 1 kg package must remain selectable')
assert.equal(context.getDefaultStockEntryUnitMode(product), 'package:30', 'mobile loading defaults to the 1 kg package')
assert.equal(context.convertMobilePackageQuantityToBase(product, 1, packages[0]), 1, '1 × 1 kg is 1 kg')
assert.equal(context.convertMobilePackageQuantityToBase(product, 2, packages[0]), 2, '2 × 1 kg is 2 kg')
assert.equal(context.convertMobilePackageQuantityToBase(product, 1, packages[1]), 10, 'legacy 10000 g carton remains 10 kg')
assert.deepEqual(Array.from(context.getMobileProductPackages(101)), [], 'single-piece food packages stay outside package mode')

console.log('OK: mobile ingredient packages keep 1 kg default and legacy carton conversion')
