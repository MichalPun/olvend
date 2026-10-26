import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../inventory.html', import.meta.url), 'utf8')
const extract = name => {
  const start = html.indexOf(`    function ${name}(`)
  assert.ok(start >= 0, name)
  const end = html.indexOf('\n    function ', start + 1)
  return html.slice(start, end)
}

const context = vm.createContext({
  normalizeText: value => String(value || '').trim().toLowerCase()
})

for (const name of ['getPackageQuantityUnit', 'convertRecipeQuantityToBase', 'convertPackageQuantityToBase']) {
  vm.runInContext(extract(name), context)
}

const kgProduct = { base_unit: 'kg' }
assert.equal(context.convertPackageQuantityToBase(kgProduct, 1, { units_per_package: 10 }), 10, '10 kg carton stays 10 kg')
assert.equal(context.convertPackageQuantityToBase(kgProduct, 1, { units_per_package: 5 }), 5, '10 × 0.5 kg carton stays 5 kg')
assert.equal(context.convertPackageQuantityToBase(kgProduct, 1, { units_per_package: 0.5 }), 0.5, 'single 0.5 kg bag stays 0.5 kg')
assert.equal(context.convertPackageQuantityToBase(kgProduct, 1, { units_per_package: 10000 }), 10, 'legacy 10000 g carton remains compatible')
assert.equal(context.convertPackageQuantityToBase({ base_unit: 'g' }, 1, { units_per_package: 1000 }), 1000, 'gram-based package remains unchanged')
assert.equal(context.convertPackageQuantityToBase({ base_unit: 'ks' }, 2, { units_per_package: 24 }), 48, 'piece carton remains unchanged')

console.log('OK: inventory package quantities use product base units')
