import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'

const html = fs.readFileSync(new URL('../issued-invoices.html', import.meta.url), 'utf8')
function fn(name) {
  const start = html.search(new RegExp(`    function ${name}\\(`))
  assert.ok(start >= 0, name)
  const end = html.slice(start + 1).search(/\n    (?:async )?function /)
  return html.slice(start, start + 1 + end)
}

const products = [
  { id: 108, name: 'oVe FD COFFEE SOPHIA 500g', base_unit: 'kg' },
  { id: 200, name: 'Tyčinka', base_unit: 'ks' },
  { id: 300, name: 'Sirup', base_unit: 'l' }
]
const productPackages = [
  { product_id: 108, package_name: '0,5 kg', units_per_package: 500, active: true },
  { product_id: 108, package_name: 'Karton', units_per_package: 5000, active: true },
  { product_id: 200, package_name: 'Karton', units_per_package: 24, active: true },
  { product_id: 300, package_name: '500 ml', units_per_package: 500, active: true }
]
const context = vm.createContext({
  products,
  productPackages,
  normalizeText: (value) => String(value || '').trim().toLowerCase()
})
for (const name of ['productById', 'packagesForProduct', 'packageForProductUnit', 'packageUnitsInStockBase', 'salesLineStockQuantity']) {
  vm.runInContext(fn(name), context)
}

assert.equal(context.salesLineStockQuantity({ productId: 108, unit: '0,5 kg', quantity: 10 }), 5)
assert.equal(context.salesLineStockQuantity({ productId: 108, unit: 'Karton', quantity: 1 }), 5)
assert.equal(context.salesLineStockQuantity({ productId: 200, unit: 'Karton', quantity: 2 }), 48)
assert.equal(context.salesLineStockQuantity({ productId: 300, unit: '500 ml', quantity: 3 }), 1.5)
assert.equal(context.salesLineStockQuantity({ productId: 108, unit: 'kg', quantity: 2.5 }), 2.5)

console.log('PASS: invoice package quantities are converted to stock base units')
